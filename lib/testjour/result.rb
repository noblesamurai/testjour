require "English"
require "socket"

module Testjour

  class Result
    attr_reader :time
    attr_reader :status
    attr_reader :message
    attr_reader :backtrace
    attr_reader :backtrace_line
    attr_reader :source
    attr_reader :step_match

    CHARS = {
      :undefined => 'U',
      :passed    => '.',
      :failed    => 'F',
      :pending   => 'P',
      :skipped   => 'S'
    }

    def initialize(time, status, step_match = nil, exception = nil, source = nil)
      @time   = time
      @status = status
      @source = source
	  @step_match = step_match

      if step_match
        @backtrace_line = step_match.backtrace_line
      end

      if exception
        @message    = exception.message.to_s
        @backtrace  = exception.backtrace.join("\n")
      end

      @pid        = Testjour.effective_pid
      @hostname   = Testjour.socket_hostname
    end

    def server_id
      "#{@hostname} [#{@pid}]"
    end

    def char
      CHARS[@status]
    end

    def failed?
      status == :failed
    end

    def undefined?
      status == :undefined
    end

  end

end
