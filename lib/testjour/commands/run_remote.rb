require "testjour/commands/command"
require "cucumber"
require "uri"
require "daemons/daemonize"
require "testjour/cucumber_extensions/http_formatter"
require "testjour/cucumber_extensions/html_formatter"
require "testjour/mysql"
require "testjour/rsync"
require "stringio"

module Testjour
  module Commands
    
    class RunRemote < Command
        
      def dir
        configuration.in
      end
    
      def execute
        configuration.parse!
        configuration.parse_uri!

        Dir.chdir(dir) do
          Testjour.setup_logger(dir)
          Testjour.logger.info "Starting #{self.class.name}"
          rsync
          bundler
          start_additional_slaves
        end
      end
      
      def start_additional_slaves
        1.upto(configuration.max_remote_slaves) do |i|
          start_slave
        end
      end
      
      def start_slave
        Testjour.logger.info "Starting slave: #{local_run_command}"
        detached_exec(local_run_command)
      end
      
      def local_run_command
        "testjour run:slave #{configuration.run_slave_args.join(' ')} #{testjour_uri}".squeeze(" ")
      end

      def testjour_uri
        Testjour.logger.info "Configuration Host is: #{configuration.master_host}"
        user = Etc.getpwuid.name
        host = configuration.master_host || Testjour.socket_hostname
        "rsync://#{user}@#{host}" + File.expand_path(".")
      end      
      
      def rsync
        Rsync.copy_to_current_directory_from(configuration.rsync_uri)
      end
      
      def bundler
        return unless File.exists?('.bundle')
        Testjour.logger.info "Running bundle install"
        `bundle install`
      end
    end
  
  end
end