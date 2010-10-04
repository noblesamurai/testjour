require "testjour/commands/command"
require "cucumber"
require "uri"
require "daemons/daemonize"
require "testjour/cucumber_extensions/http_formatter"
require "testjour/cucumber_extensions/html_formatter"
require "testjour/mysql"
require "stringio"

module Testjour
module Commands

  class RunSlave < Command

    # Boolean indicating whether this worker can or can not fork.
    # Automatically set if a fork(2) fails.
    attr_accessor :cant_fork, :html_out_file

    def execute
      configuration.parse!
      configuration.parse_uri!

      Dir.chdir(dir) do
        Testjour.setup_logger(dir)
        Testjour.logger.info "Starting #{self.class.name}"
        
        before_require
        
        begin
          
          configuration.setup
          configuration.setup_mysql
          
          require_cucumber_files
          preload_app
          
          work
        rescue SystemExit => ex
          Testjour.logger.info "Killing child..."
        rescue Object => ex
          Testjour.logger.error "#{self.class.name} error: #{ex.message}"
          Testjour.logger.error ex.backtrace.join("\n")
        end
      end
    end
    
    def dir
      configuration.path
    end
    
    def before_require
      enable_gc_optimizations
    end

    def work
      queue = RedisQueue.new(configuration.queue_host,
                             configuration.queue_prefix,
                             configuration.queue_timeout)
      feature_file = true
      
      @html_out_file = File.open('~/features.html','w')

      while feature_file
        if (feature_file = queue.pop(:feature_files))
          Testjour.logger.info "Loading: #{feature_file}"
          features = load_feature_files(feature_file)
          parent_pid = $PID
          Testjour.override_logger_pid(parent_pid)
          Testjour.logger.info "Executing: #{feature_file}"
          Testjour.logger.info "Features Output: features.html" unless @html_out_file.closed?
          failure = execute_features(features)
          Testjour.logger.info "Done: #{feature_file}"
        else
          Testjour.logger.info "No feature file found. Finished"
        end
      end
    end

    def execute_features(features)
      http_formatter = Testjour::HttpFormatter.new(configuration)
      html_formatter = Testjour::HtmlFormatter.new(runtime, @html_out_file, nil)
      tree_walker = Cucumber::Ast::TreeWalker.new(runtime, [html_formatter,http_formatter], configuration.cucumber_configuration)
      Testjour.logger.info "Visiting..."
      runtime.visitor = tree_walker
      tree_walker.visit_features(features)
      failure = runtime.scenarios(:failed).any?
    end

    def require_cucumber_files
      support_code = Cucumber::Runtime::SupportCode.new(runtime, configuration.cucumber_configuration.guess?)
      files = configuration.cucumber_configuration.support_to_load + configuration.cucumber_configuration.step_defs_to_load
      support_code.load_files!(files)
      support_code.fire_hook(:after_configuration, configuration.cucumber_configuration)
      runtime.instance_variable_set('@support_code',support_code)
    end
    
    def preload_app
      if File.exist?('./testjour_preload.rb')
        Testjour.logger.info 'Requiring ./testjour_preload.rb'
        require './testjour_preload.rb'
      end
    end
    
    # Not every platform supports fork. Here we do our magic to
    # determine if yours does.
    def fork
        @cant_fork = true
        return nil
      # we cant fork because solr is too slow
      # =====================================
      # begin
      #   Kernel.fork
      # rescue NotImplementedError
      #   @cant_fork = true
      #   nil
      # end
    end
    
    # Enables GC Optimizations if you're running REE.
    # http://www.rubyenterpriseedition.com/faq.html#adapt_apps_for_cow
    def enable_gc_optimizations
      if GC.respond_to?(:copy_on_write_friendly=)
        GC.copy_on_write_friendly = true
      end
    end

  end

end
end