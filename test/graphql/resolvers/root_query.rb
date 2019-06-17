require "graphql_server/base_resolver"
require "graphql_server/base_entity"

class TestEntity < GraphQLServer::BaseEntity
  attr_accessor :hash

  def initialize
    @hash = {
      :exists => true
    }
  end
end

class RootQueryResolver < GraphQLServer::BaseResolver
  def self.test(obj, args, context)
    TestEntity.new
  end

  def self.heartbeat(obj, args, context)
    "OK"
  end
end
