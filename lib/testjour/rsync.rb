require "uri"
require "systemu"
require "testjour/core_extensions/retryable"

module Testjour
  
  class RsyncFailed < StandardError
  end
  
  class Rsync
    
    def self.copy_to_current_directory_from(source_uri)
      new(source_uri, File.expand_path(".")).copy_with_retry
    end
    
    def self.copy_from_current_directory_to(destination_uri)
      new(File.expand_path("."), destination_uri).copy_with_retry
    end
    
    def initialize(source_uri, destination_uri)
      @source_uri = source_uri
      @destination_uri = destination_uri
    end

    def copy_with_retry
      retryable :tries => 2, :on => RsyncFailed do
        Testjour.logger.info "Rsyncing Config: #{config_command}"
        copy_config
        
        Testjour.logger.info "Rsyncing: #{command}"
        copy
        
        if successful?
          Testjour.logger.debug("Rsync finished in %.2fs" % elapsed_time)
        else
          Testjour.logger.debug("Rsync failed in %.2fs" % elapsed_time)
          Testjour.logger.debug("Rsync stdout: #{@stdout}")
          Testjour.logger.debug("Rsync stderr: #{@stderr}")
          raise RsyncFailed.new 
        end
      end
    end
    
    def copy
      @start_time = Time.now
      
      status, @stdout, @stderr = systemu(command)
      @exit_code = status.exitstatus
    end
    
    def copy_config
      @start_time = Time.now
      
      status, @stdout, @stderr = systemu(config_command)
      @exit_code = status.exitstatus
    end
    
    def elapsed_time
      Time.now - @start_time
    end
    
    def successful?
      @exit_code.zero?
    end
    
    def command
      excludes = ""
      if File.exists?(file = "config/testjour.yml")
	config = YAML.load_file(file)
        excludes = config["exclude"].split(",").map { |exclude|
          " --exclude=#{exclude}"
        }.join(" ") unless config["exclude"] !~ /\S/
      end
      "rsync -az -e \"ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no\" --delete#{excludes} --exclude=public/images/products --exclude=.git --exclude=*.log --exclude=*.pid #{@source_uri}/ #{@destination_uri}"

    end
    
    def config_command
      "scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no #{@source_uri} #{@destination_uri}/config/"
    end
  end
end
