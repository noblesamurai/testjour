module Testjour
  TestJour_config = Hash.new


  class Configuration
    attr_reader :unknown_args, :options, :path, :full_uri, :runtime

    def initialize(args)
      @options = {}
      @args = args
      @unknown_args = []
      Cucumber.logger.level = Logger::INFO
    end

    def setup
      require 'cucumber/cli/main'
      Cucumber.class_eval do
        def language_incomplete?
          false
        end
      end
      @runtime ||= Cucumber::Runtime.new(cucumber_configuration)
    end

    def max_local_slaves
      @options[:max_local_slaves] || 2
    end

    def max_remote_slaves
      @options[:max_remote_slaves] || 1
    end

    def in
      @options[:in]
    end

    def rsync_uri
      external_rsync_uri || "#{full_uri.user}#{'@' if full_uri.user}#{full_uri.host}:#{full_uri.path}"
    end

    def external_rsync_uri
      @options[:rsync_uri]
    end

    def queue_host
      @queue_host || @options[:queue_host] || Testjour.socket_hostname
    end
    
    def external_queue_host?
      queue_host != Testjour.socket_hostname
    end

    def queue_prefix
      @options[:queue_prefix] || 'default'
    end
    
    def queue_timeout
      @options[:queue_timeout].to_i || 270
    end

    def remote_slaves
      @options[:slaves] || []
    end
    
    def master_host
      @options[:master_host]
    end

    def env
      @options[:env]
    end

    def ssh_key
      @options[:ssh_key]
    end

	def slave_src
		@options[:slave_src] || 'http://192.168.200.12:9999/'
	end

	def slave_path
		@options[:slave_path]
	end

    def setup_mysql
      return unless mysql_mode?

      mysql = MysqlDatabaseSetup.new(@options[:runner_database_name], TestJour_config)

      mysql.create_database
      at_exit do
        Testjour.logger.info caller.join("\n") if caller
        mysql.drop_database
      end

      ENV["TESTJOUR_DB"] = mysql.runner_database_name
      mysql.load_schema
    end

    def mysql_mode?
      @options[:create_mysql_db]
    end

    def local_slave_count
      [feature_files.size, max_local_slaves].min
    end

    def parser
      @parser ||= Cucumber::Parser::FeatureParser.new
    end

    def feature_files
      return @feature_files if @feature_files
      
      loader = Cucumber::Runtime::FeaturesLoader.new(
        cucumber_configuration.feature_files,
        cucumber_configuration.filters,
        cucumber_configuration.tag_expression
      )
      features = loader.features

      finder = Testjour::FeatureFileFinder.new
      walker = Cucumber::Ast::TreeWalker.new(runtime, [finder], cucumber_configuration)
      walker.visit_features(features)
      @feature_files = finder.feature_files
    end

    def cucumber_configuration
      return @cucumber_configuration if @cucumber_configuration
      @cucumber_configuration = Cucumber::Cli::Configuration.new(StringIO.new, StringIO.new)
      Testjour.logger.info "Arguments for Cucumber: #{args_for_cucumber.inspect}"
      @cucumber_configuration.parse!(args_for_cucumber)
      @cucumber_configuration
    end

    def unshift_args(pushed_args)
      pushed_args.each do |pushed_arg|
        @args.unshift(pushed_arg)
      end
    end

    def load_additional_args_from_external_file
      args_from_file = begin
        if File.exist?(args_file)
          File.read(args_file).strip.split
        else
          []
        end
      end
      unshift_args(args_from_file)
    end

    def args_file
      # We need to know about this CLI option prior to OptParse's parse
      args_file_option = @args.detect{|arg| arg =~ /^--testjour-config=/}
      if args_file_option
        args_file_option =~ /^--testjour-config=(.*)/
        $1
      else
        'testjour.yml'
      end
    end

    def parse!
      begin
        option_parser.parse!(@args)
        Dir.chdir(self.in ? self.in : ".") do
          if File.exists?("config/testjour.yml")
            TestJour_config.merge! YAML.load_file("config/testjour.yml") if YAML.load_file("config/testjour.yml")
          end
        end
      rescue OptionParser::InvalidOption => e
        e.recover @args
        saved_arg = @args.shift
        @unknown_args << saved_arg

        if @args.any? && !saved_arg.include?("=") && @args.first[0..0] != "-"
          @unknown_args << @args.shift
        end

        retry
      end
    end

    def parse_uri!
      full_uri = URI.parse(@args.shift)
      @path = full_uri.path
      @full_uri = full_uri.dup
      @queue_host = full_uri.host unless options[:queue_host]
    end

    def run_slave_args
      [testjour_args + @unknown_args]
    end

    def testjour_args
      args_from_options = []
      if @options[:create_mysql_db]
        args_from_options << "--create-mysql-db"
      end
      if @options[:runner_database_name]
        args_from_options << "--mysql-db-name=#{@options[:runner_database_name]}"
      end
      if @options[:queue_host] || external_queue_host?
        args_from_options << "--queue-host=#{queue_host}"
      end
      if @options[:queue_prefix]
        args_from_options << "--queue-prefix=#{@options[:queue_prefix]}"
      end
      return args_from_options
    end

    def args_for_cucumber
      @unknown_args + @args
    end

  protected

    def option_parser
      OptionParser.new do |opts|
        opts.on("--testjour-config=ARGS_FILE", "Load additional testjour args from the specified file (defaults to testjour.yml)") do |args_file|
          @options[:args_file] = args_file
        end

        opts.on("--on=SLAVE", "Specify a slave URI (testjour://user@host:/path/to/working/dir?workers=3)") do |slave|
          @options[:slaves] ||= []
          @options[:slaves] << slave
        end

        opts.on("--in=DIR", "Working directory to use (for run:remote only)") do |directory|
          @options[:in] = directory
        end

        opts.on("--max-remote-slaves=MAX", "Number of workers to run (for run:remote only)") do |max|
          @options[:max_remote_slaves] = max.to_i
        end

        opts.on("--strict", "Fail if there are any undefined steps") do
          @options[:strict] = true
        end

        opts.on("--create-mysql-db", "Create MySQL for each slave") do
          @options[:create_mysql_db] = true
        end

        opts.on("--mysql-db-name=DATABASE", "Use DATABASE as name for MySQL DB") do |name|
          @options[:runner_database_name] = name
        end
        
        opts.on("--simple-progress", "Use a simpler progress bar that may display better in logs") do
          @options[:simple_progress] = true
        end

        opts.on("--queue-host=QUEUE_HOST", "Use another server to host the main redis queue") do |queue_host|
          @options[:queue_host] = queue_host
        end

        opts.on("--queue-prefix=QUEUE_PREFIX", "Provide a prefix to uniquely identify this testjour run (Default is 'default')") do |queue_prefix|
          @options[:queue_prefix] = queue_prefix
        end

        opts.on("--queue-timeout=QUEUE_TIMEOUT", "How long to wait for results to appear in the queue before giving up") do |queue_timeout|
          @options[:queue_timeout] = queue_timeout
        end

        opts.on("--rsync-uri=RSYNC_URI", "Use another location to host the codebase for slave rsync (master will rsync to this URI first)") do |rsync_uri|
          @options[:rsync_uri] = rsync_uri
        end

        opts.on("--max-local-slaves=MAX", "Maximum number of local slaves") do |max|
          @options[:max_local_slaves] = max.to_i
        end
        
        opts.on("--master-host=MASTER_HOST", "Override the master host, useful if hostname doesn't resolve") do |master_host|
          @options[:master_host] = master_host
        end

		opts.on("--master-host-as-ip", "Override the master host by determining the external IP and using that instead") do
		  require 'socket'
		  @options[:master_host] = UDPSocket.open {|s| s.connect("8.8.8.8", 1); s.addr.last }
		end

        opts.on("--env=ENV", "Pass environment variables to the slave") do |env|
          @options[:env] = env
        end

        opts.on("--ssh-key=SSH_KEY", "Specify an SSH key file to use for connecting to slaves") do |ssh_key|
          @options[:ssh_key] = ssh_key
        end

        opts.on("--slave-src=SLAVE_SRC", "Source to retrieve a list of slaves from") do |slave_src|
          @options[:slave_src] = slave_src
        end

        opts.on("--slave-path=SLAVE_PATH", "Path to use for retrieved slave sources") do |slave_path|
          @options[:slave_path] = slave_path
        end
      end
    end
  end

end
