require "optparse"
require "socket"
require "etc"

require "testjour/commands/command"
require "testjour/redis_queue"
require "testjour/configuration"
require "testjour/cucumber_extensions/step_counter"
require "testjour/cucumber_extensions/feature_file_finder"
require "testjour/results_formatter"
require "testjour/result"

module Testjour
module Commands

  class Run < Command

    def execute
      configuration.load_additional_args_from_external_file
      configuration.parse!
      configuration.setup

      if configuration.feature_files.any?
        redis_queue = RedisQueue.new(configuration.queue_host,
                       configuration.queue_prefix,
                       configuration.queue_timeout)
        redis_queue.reset_all
        queue_features
        
        at_exit do
          Testjour.logger.info caller.join("\n") if caller
          redis_queue.reset_all
        end

        @started_slaves = 0
        start_slaves

        puts "Requested build from #{@started_slaves} slaves... (Waiting for #{step_counter.count} results)"
        puts

        print_results
      else
        Testjour.logger.info("No feature files. Quitting.")
      end
    end

    def queue_features
      Testjour.logger.info("Queuing features...")
      queue = RedisQueue.new(configuration.queue_host,
                             configuration.queue_prefix,
                             configuration.queue_timeout)

      configuration.feature_files.each do |feature_file|
        queue.push(:feature_files, feature_file)
        Testjour.logger.info "Queued: #{feature_file}"
      end
    end

    def start_slaves
      start_local_slaves
      start_remote_slaves
      start_remote_slave_discovery
    end

    def start_local_slaves
      configuration.local_slave_count.times do
        @started_slaves += 1
        start_slave
      end
    end

    def start_remote_slave_discovery
	  src_uri = URI.parse(configuration.slave_src)
      return if src_uri.host.nil?

	  Thread.new do
	    socket = TCPSocket.new(src_uri.host, src_uri.port || 9999)
		begin
          while (uri = URI.parse(socket.gets)) do
		    if uri.host then
              uri.path = configuration.slave_path
              @started_slaves += 1
              start_remote_slave(uri.to_s)
			end
          end
		rescue
		end
	  end
	end

    def start_remote_slaves
      if configuration.remote_slaves.any?
        if configuration.external_rsync_uri
          Rsync.copy_from_current_directory_to(configuration.external_rsync_uri)
        end
        configuration.remote_slaves.each do |remote_slave|
          @started_slaves += 1
          start_remote_slave(remote_slave)
        end
      end
    end

    def start_remote_slave(remote_slave)
      num_workers = 1
      if remote_slave.match(/\?workers=(\d+)/)
        num_workers = $1.to_i
        remote_slave.gsub(/\?workers=(\d+)/, '')
      end
      uri = URI.parse(remote_slave)
      cmd = remote_slave_run_command(uri.user, uri.host, uri.path, num_workers)
      Testjour.logger.info "Starting remote slave: #{cmd}"
      detached_exec(cmd)
    end

    def remote_slave_run_command(user, host, path, max_remote_slaves)
      "ssh #{"-i #{configuration.ssh_key} " if configuration.ssh_key} -o StrictHostKeyChecking=no #{user}#{'@' if user}#{host} 'source /etc/profile && #{"#{configuration.env} &&" if configuration.env} testjour run:remote --in=#{path} --max-remote-slaves=#{max_remote_slaves} #{configuration.run_slave_args.join(' ')} #{testjour_uri}'".squeeze(" ")
    end

    def start_slave
      Testjour.logger.info "Starting slave: #{local_run_command}"
      detached_exec(local_run_command)
    end

    def print_results
      results_formatter = ResultsFormatter.new(step_counter, configuration.options)
      queue = RedisQueue.new(configuration.queue_host,
                             configuration.queue_prefix,
                             configuration.queue_timeout)

      step_counter.count.times do
        results_formatter.result(queue.blocking_pop(:results))
      end

      results_formatter.finish
      return results_formatter.failed? ? 1 : 0
    end

    def step_counter
      return @step_counter if @step_counter
      
      loader = Cucumber::Runtime::FeaturesLoader.new(
        configuration.cucumber_configuration.feature_files,
        configuration.cucumber_configuration.filters,
        configuration.cucumber_configuration.tag_expression
      )
      features = loader.features
      
      @step_counter = Testjour::StepCounter.new
      tree_walker = Cucumber::Ast::TreeWalker.new(runtime, [@step_counter], configuration.cucumber_configuration)
      tree_walker.visit_features(features)
      return @step_counter
    end

    def local_run_command
      "testjour run:slave #{configuration.run_slave_args.join(' ')} #{File.expand_path(".")}".squeeze(" ")
    end

    def testjour_uri
      if configuration.external_rsync_uri
        "rsync://#{configuration.external_rsync_uri}"
      else
        user = Etc.getpwuid.name
        host = configuration.master_host || Testjour.socket_hostname
        "rsync://#{user}@#{host}" + File.expand_path(".")
      end
    end

    def testjour_path
      File.expand_path(File.dirname(__FILE__) + "/../../../bin/testjour")
    end

  end

end
end
