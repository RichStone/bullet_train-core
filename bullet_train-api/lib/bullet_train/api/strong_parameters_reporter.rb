module BulletTrain
  module Api
    class StrongParametersReporter
      def initialize(model, strong_params_module)
        @model = model
        @module = strong_params_module
        @filters = []
        extend @module
      end

      def require(namespace)
        @namespace = namespace
        self
      end

      def permit(*filters)
        @filters = filters
      end

      def params
        self
      end

      def permitted_fields
        defined?(super) ? super : []
      end

      def permitted_arrays
        defined?(super) ? super : {}
      end

      def process_params(params)
      end

      def model_name
        @model.name
      end

      # def method_missing(method_name, *args)
      #   if method_name.match?(/^assign_/)
      #     # It's typically the second argument that represents the parameter that would be set.
      #     @filters << args[1]
      #   else
      #     raise NoMethodError, message
      #   end
      # end

      def report(method_type = nil)
        method_type = ['create', 'update'].include?(method_type) ? method_type : nil
        base_method_name = "#{@model.name.split('::').last.underscore}"

        # method_name = method_type == 'create' ? "#{base_method_name}_params" : "#{base_method_name}_#{method_type}_params"

        @filters = if method_type == 'update' && respond_to?("#{base_method_name}_#{method_type}_params".to_sym, true)
          send("#{base_method_name}_#{method_type}_params".to_sym)
        else
          send("#{base_method_name}_params".to_sym)
        end

        # @filters = if method_type && respond_to?("#{base_method_name}_#{method_type}_params".to_sym, true)
        #   send("#{base_method_name}_#{method_type}_params".to_sym)
        # else
        #   send("#{base_method_name}_params".to_sym)
        # end

        # There's a reason I'm doing it this way.
        @filters
      end

      # def report(method_type = nil)
      #   @filters = send("#{@model.name.split("::").last.underscore}_params".to_sym)

      #   # There's a reason I'm doing it this way.
      #   @filters
      # end
    end
  end
end
