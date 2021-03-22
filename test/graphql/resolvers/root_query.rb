require "graphql_server/base_resolver"
require "graphql_server/base_entity"
require_relative "../../mocks/widget"

class TestEntity < GraphQLServer::BaseEntity
  attr_accessor :hash_field

  def initialize
    @hash_field = {
      :exists => true
    }
  end

  def field_with_args(args, ctx)
    ctx ? args[:value] : nil
  end

  def field_without_args
    "OK"
  end
end

class RootQueryResolver < GraphQLServer::BaseResolver
  def self.test(obj, args, context)
    TestEntity.new
  end

  def self.heartbeat(obj, args, context)
    "OK"
  end

  def self.abstract(obj, args, context)
    { :__typename => 'Orange', id: "orange" }
  end

  def self.arguments(obj, args, context)
    args.deep_transform_keys! { |key| key.to_s }
  end

  def self.argument_defaults(obj, args, context)
    default_arguments_for('TestInput')
  end

  def self.error(obj, args, context)
    map_errors(context, args[:id]) do |key|
      nil
    end
  end

  def self.errors(obj, args, context)
    map_errors(context, args[:ids]) do |keys|
      keys.map do |key|
        next { id: key } if key == 1
        next user_input_error(%(Invalid key "#{key}")) if key == 2
        nil
      end
    end
  end

  def self.parrot(obj, args, context)
    args[:says]
  end

  def self.scalars(obj, args, context)
    {
      any: 23,
      date: Time.iso8601('2020-07-13T03:01:49Z'),
      json: { hello: 'world' },
      url: URI.parse('https://vox.com'),
      tz: 'Chongqing'
    }
  end

  def self.loader_with_uid(obj, args, context)
    batch_loader(:record_loader).for(Widget).map_errors(context).load_uid(args[:uid], 'Widget')
  end

  def self.loader_with_uids(obj, args, context)
    batch_loader(:record_loader).for(Widget).map_errors(context).load_uids(args[:uids], 'Widget')
  end

  def self.loader_with_case_sensitive_keys(obj, args, context)
    batch_loader(:record_loader).for(Widget, column: 'name').map_errors(context).load_many(args[:names])
  end
end
