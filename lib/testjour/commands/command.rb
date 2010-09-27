module Testjour
module Commands

  class Command

    def initialize(args = [], out_stream = STDOUT, err_stream = STDERR)
      @options = {}
      @args = args
      @out_stream = out_stream
      @err_stream = err_stream
    end

  protected

    def configuration
      return @configuration if @configuration
      @configuration = Configuration.new(@args)
      @configuration
    end

    def parser
      @parser ||= Cucumber::Parser::FeatureParser.new
    end
    
    def load_feature_files(files)
      loader = Cucumber::Runtime::FeaturesLoader.new(
        files,
        configuration.cucumber_configuration.filters,
        configuration.cucumber_configuration.tag_expression
      )
      features = loader.features
    end

    def runtime
      @runtime ||= Cucumber::Runtime.new(configuration.cucumber_configuration)
    end

    def testjour_path
      File.expand_path(File.dirname(__FILE__) + "/../../../bin/testjour")
    end

  end

end
end