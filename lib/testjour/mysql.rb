module Testjour
  
  # Stolen from deep-test
  
  class MysqlDatabaseSetup

    def initialize(runner_database_name = nil, options = nil)
      @runner_database_name = runner_database_name
      @username = options["dbusername"] if options && options["dbusername"]
      @password = options["dbpassword"] if options && options["dbpassword"]
    end
    
    def create_database
      run "/usr/local/mysql/bin/mysqladmin#{@username ? " -u " + @username : ""}#{@password ? " --password=" + @password : ""} create #{runner_database_name}"
    end
    
    def drop_database
      run "/usr/local/mysql/bin/mysqladmin#{@username ? " -u " + @username : ""}#{@password ? " --password=" + @password : ""} -f drop #{runner_database_name}"
    end

    def load_schema
      schema_file = File.expand_path("./db/development_structure.sql")
      
      unless File.exist?(schema_file)
      end
      
      run "/usr/local/mysql/bin/mysql#{@username ? " -u " + @username : ""}#{@password ? " --password=" + @password : ""} #{runner_database_name} < #{schema_file}"

    end
    
    def runner_database_name
      @runner_database_name ||= "testjour_runner_#{rand(1_000)}_#{Testjour.effective_pid}"
    end
    
  protected
  
    def run(cmd)
      Testjour.logger.info "Executing: #{cmd}"
      status, stdout, stderr = systemu(cmd)
      exit_code = status.exitstatus
    
      unless exit_code.zero?
        Testjour.logger.info "Failed: #{exit_code}"
        Testjour.logger.info stderr
        Testjour.logger.info stdout
      end
    end
    
  end
  
end

