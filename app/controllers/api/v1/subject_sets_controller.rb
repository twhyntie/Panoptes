class Api::V1::SubjectSetsController < Api::ApiController
  include JsonApiController
  
  before_filter :require_login, only: [:update, :destroy, :create]
  doorkeeper_for :create, :update, :destroy, scopes: [:project]
  access_control_for :create, :update, :destroy, resource_class: SubjectSet

  resource_actions :default

  allowed_params :create, :name, links: [:project,
                                           workflows: [],
                                           subjects: []]

  allowed_params :update, :name, links: [workflows: [], subjects: []]


end
