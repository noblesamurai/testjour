module Testjour
  
  class FeatureFileFinder
    attr_reader :feature_files
    
    def initialize
      @feature_files = []
    end

    def scenario_name(keyword, name, file_colon_line, source_indent)
      @feature_files << file_colon_line
      @feature_files.uniq!
    end
  end

end
