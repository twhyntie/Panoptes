module JsonApiController
  module JsonSchemaValidator
    extend ActiveSupport::Concern

    module ClassMethods
      def allowed_params(action, &block)
        @action_params[action] = if block_given?
                                   JsonSchema.build(&block)
                                 else
                                   schema_class(action).new
                                 end
      end

      def action_params
        @action_params
      end

      private
      
      def schema_class(action)
        "#{ resource_name }_#{ action }_schema".camelize.constantize
      end
    end

    protected

    def params_for(action=action_name.to_sym)
      ps = params.require(resource_sym).permit!
      self.class.action_params[action].validate!(ps)
      ps
    end
    
    alias_method :create_params, :params_for
    alias_method :update_params, :params_for
  end
end
