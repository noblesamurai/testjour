require './lib/testjour.rb'

Gem::Specification.new do |s|
  s.name         = "testjour"
  s.version      = Testjour::VERSION
  s.author       = "Bryan Helmkamp"
  s.email        = "bryan" + "@" + "brynary.com"
  s.homepage     = "http://github.com/raldred/testjour"
  s.summary      = "Distributed test running with autodiscovery via Bonjour (for Cucumber first)"
  s.description  = s.summary
  s.executables  = "testjour"
  s.files        = %w[History.txt MIT-LICENSE.txt README.rdoc Rakefile] + Dir["bin/*"] + Dir["lib/**/*"] + Dir["vendor/**/*"]
end