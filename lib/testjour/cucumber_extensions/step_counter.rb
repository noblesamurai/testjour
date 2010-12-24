module Testjour

    class StepCounter

      def initialize
	  	@step_count = 0
      end

	  def before_feature(feature)
	  	@feature_step_count = 0
		@bg = []
		@current = nil
	  end

	  def after_feature(feature)
		@step_count += @feature_step_count
	  end

	  def scenario_name *a
		@current = a
		if @current.first == "Scenario Outline"
		  @feature_step_count += @bg.length
		elsif @current.first == "Scenario"
		  @feature_step_count += @bg.length * 2
		else
		  raise "Don't know how to count backgrounds for a #{@current.first}"
		end
	  end

	  def after_step(step)
	    if step.background? and @current.nil?
		  @bg << step.name
		elsif step.background?
		  # ignore bg steps, we add their counts in +scenario_name+
		else
		  @feature_step_count += 1
		end
	  end

      def count
        @step_count
      end

    end
end

# vim: set sw=2:
