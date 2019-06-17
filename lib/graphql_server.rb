require "graphql_server/version"
require "graphql_server/config"
require "graphql_server/schema"
require "graphql_server/base_entity"
require "graphql_server/base_resolver"
require "graphql_server/base_mutation_resolver"
require "graphql_server/batch_loaders/base_loader"
require "graphql_server/batch_loaders/association_loader" if defined?(ActiveRecord)
require "graphql_server/batch_loaders/includes_loader" if defined?(ActiveRecord)
require "graphql_server/batch_loaders/record_list_loader"
require "graphql_server/batch_loaders/record_loader"
require "graphql_server/railtie" if defined?(Rails)
require "active_support/core_ext/module/attribute_accessors"

module GraphQLServer
  mattr_accessor :config

  def self.configure
    self.config ||= GraphQLServer::Config.new
    yield(config)
  end

  def self.reload_schema!
    @schema = nil
  end

  def self.schema
    @schema ||= GraphQLServer::Schema.load
  end

  def self.log(s='')
    puts(s.white_on_blue)
  end
end

GraphQLServer.configure do |config|
  config.instrument_queries = false
  config.instrument_fields = false
  config.instrument_batch_loaders = false
end
