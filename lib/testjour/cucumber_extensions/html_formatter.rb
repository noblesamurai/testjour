require 'cucumber/formatter/html'

module Testjour

  class HtmlFormatter < Cucumber::Formatter::Html
    
    #stop the html formatter doing JS otherwise it's almost impossible to load the page in a browser
    def after_step(step)
      # do nothing
    end
    
    def print_stats(features)
      # do nothing
    end
    
    def move_progress
      # do nothing
    end
    
  end
  
end
  