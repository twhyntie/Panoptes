class SubjectUpdateSchema < JsonSchema
  schema do
    type "object"
    description "A peice of media to classifiy"
    additional_properties false

    property "metadata" do
      type "object"
    end

    property "locations" do
      type "array"
      items do
        type "string"
      end
    end

    property "links" do
      type "object"

      property "subject_sets" do
        type "array"
        items do
          type "string", "integer"
        end
      end
    end
  end
end
