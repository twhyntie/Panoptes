class SubjectSetCreateSchema < JsonSchema
  schema do
    type "object"
    description "A Set of Subjects"
    required "links", "display_name"
    additional_properties false

    property "display_name" do
      type "string"
    end

    property "metadata" do
      type "object"
    end

    property "links" do
      type "object"
      required "project"
      
      property "project" do
        type "string", "integer"
      end
      
      property "workflow" do
        type "string", "integer"
      end

      property "subjects" do
        type "array"
        items do
          type "string", "integer"
        end
      end
    end
  end
end
