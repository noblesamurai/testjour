$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__))) unless $LOAD_PATH.include?(File.expand_path(File.dirname(__FILE__)))

require "testjour/cli"
require "logger"
require "English"

def silence_stream(stream)
  old_stream = stream.dup
  stream.reopen(RUBY_PLATFORM =~ /mswin/ ? 'NUL:' : '/dev/null')
  stream.sync = true
  yield
ensure
  stream.reopen(old_stream)
end

def detached_exec(command)
  pid = fork do
    silence_stream(STDOUT) do
      silence_stream(STDERR) do
        exec(command)
      end
    end
  end

  Process.detach(pid)
  return pid
end

module Testjour
  VERSION = "0.4.0"

  def self.socket_hostname
    @socket_hostname ||= Socket.gethostname
  end

  def self.logger
    return @logger if @logger
    setup_logger
    @logger
  end
  
  def self.override_logger_pid(pid)
    @overridden_logger_pid = pid
  end
  
  def self.effective_pid
    @overridden_logger_pid || $PID
  end

  def self.setup_logger(dir = "./")
    hostname = `hostname`
    user_home = `echo $HOME`
    log_path = File.expand_path(File.join(user_home, "testjour.log"))
    @logger = Logger.new(log_path)
    @logger.formatter = proc do |severity, time, progname, msg|
      "#{time.strftime("%b %d %H:%M:%S")} [#{Testjour.effective_pid}]: #{msg}\n"
    end
    @logger.level = Logger::INFO
  end
end
