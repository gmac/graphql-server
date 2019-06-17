require "active_model"
require "active_model/model"

module GraphQLServer
  class BaseEntity
    include ActiveModel::Model
  end
end
