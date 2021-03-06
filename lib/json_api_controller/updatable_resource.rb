module JsonApiController
  module UpdatableResource
    include RelationManager

    def update
      ActiveRecord::Base.transaction do
        build_resource_for_update(update_params)
        controlled_resource.save!
      end

      controlled_resource.reload
      updated_resource_response(controlled_resource)
    end

    def update_links
      check_relation
      ActiveRecord::Base.transaction do
        add_relation(relation, params[relation])
        controlled_resource.save!
      end

      updated_resource_response(controlled_resource)
    end

    def destroy_links
      ActiveRecord::Base.transaction do
        destroy_relation(relation, params[:link_ids])
      end
      deleted_resource_response
    end

    protected

    def build_resource_for_update(update_params)
      links = update_params.delete(:links)
      controlled_resource.assign_attributes(update_params)
      links.try(:each) { |k, v| update_relation(k.to_sym, v) }
    end

    def check_relation
      if params[relation].nil?
        raise Api::BadLinkParams.new("Link relation must match body keys")
      end
    end

    def update_response(resource)
      serializer.resource({}, resource_scope(resource), context)
    end

    def relation
      params[:link_relation].to_sym
    end
  end
end
