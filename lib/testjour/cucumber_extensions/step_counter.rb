module Testjour

    class StepCounter

      def initialize
        @step_count = 0
      end

      def before_feature(feature)
        @feature_step_count = nil
        @feature_row_count = nil
      end

      def before_feature_element(feature_element)
        @feature_step_count = 0
      end

      def after_step(step)
        @feature_step_count += 1 if !@feature_step_count.nil?
      end

      def before_outline_table(outline_table)
        @feature_row_count = 0
      end

      def after_table_row(table_row)
        @feature_row_count += 1 if table_row.scenario_outline
      end

      def after_feature_element(feature_element)
        @feature_step_count *= @feature_row_count if !@feature_row_count.nil?
        @step_count += @feature_step_count
      end

      def count
        @step_count
      end

    end
end
