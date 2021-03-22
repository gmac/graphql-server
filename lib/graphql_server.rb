require "graphql_server/version"
require "graphql_server/config"
require "graphql_server/schema"
require "graphql_server/errors"
require "graphql_server/base_entity"
require "graphql_server/base_resolver"
require "graphql_server/base_mutation_resolver"
require "graphql_server/batch_loaders/base_loader"
require "graphql_server/batch_loaders/loader_errors_scope"
require "graphql_server/batch_loaders/association_loader" if defined?(ActiveRecord)
require "graphql_server/batch_loaders/includes_loader" if defined?(ActiveRecord)
require "graphql_server/batch_loaders/joins_through_loader" if defined?(ActiveRecord)
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

  # Executes a single GraphQL operation, or maps an array of operations
  # All submitted variables are formatted into HashWithIndifferentAccess
  def self.execute(ops, context={})
    if ops.is_a?(Array)
      ops.map { |op| execute(op, context) }
    else
      schema.execute(ops[:query],
        operation_name: ops[:operationName],
        variables: ensure_hash(ops[:variables]),
        context: context,
      )
    end
  end

  def self.ensure_hash(ambiguous_param)
    if ambiguous_param.is_a?(Hash)
      # Hash, HashWithIndifferentAccess
      ambiguous_param.with_indifferent_access
    elsif ambiguous_param.respond_to?(:permit!)
      # ActionController::Parameters
      ensure_hash(ambiguous_param.permit!.to_h)
    elsif ambiguous_param.blank?
      # nil, empty string
      {}
    elsif ambiguous_param.is_a?(String)
      ensure_hash(JSON.parse(ambiguous_param))
    else
      raise ArgumentError, "Unexpected GraphQL variables: #{ambiguous_param}"
    end
  end
end

GraphQLServer.configure do |config|
  config.instrument_queries = false
  config.instrument_fields = false
  config.instrument_batch_loaders = false
  config.resolve_scalar('Any',
    coerce_input: ->(value, context) {
      value
    },
    coerce_result: ->(value, context) {
      value
    }
  )

  config.resolve_scalar('DateTime',
    coerce_input: ->(value, context) {
      case value
      when nil, DateTime
        value
      when Time
        value.to_datetime
      when Integer
        Time.at(value).to_datetime
      else
        DateTime.iso8601(value.to_s)
      end
    },
    coerce_result: ->(value, context) {
      case value
      when nil
        value
      when Time, DateTime
        value.utc.iso8601
      when Integer
        Time.at(value).iso8601
      else
        DateTime.iso8601(value.to_s).utc.iso8601
      end
    }
  )

  config.resolve_scalar('JSON',
    coerce_input: ->(value, context) {
      if value.present?
        begin
          JSON.parse(value)
        rescue JSON::ParserError
          raise GraphQL::CoercionError("#{value.inspect} is not valid JSON")
        end
      else
        nil
      end
    },
    coerce_result: ->(value, context) {
      value.presence
    }
  )

  config.resolve_scalar('TimeZone',
    coerce_input: ->(value, context) {
      value.present? ? ActiveSupport::TimeZone[value] : nil
    },
    coerce_result: ->(value, context) {
      if value.present? && ActiveSupport::TimeZone[value]
        ActiveSupport::TimeZone[value].tzinfo.canonical_identifier
      else
        nil
      end
    }
  )

  config.resolve_scalar('URL',
    coerce_input: ->(value, context) {
      url = URI.parse(value)
      if url.is_a?(URI::HTTP) || url.is_a?(URI::HTTPS)
        url
      else
        raise GraphQL::CoercionError, "#{value.inspect} is not a valid URL"
      end
    },
    coerce_result: ->(value, context) {
      value.present? ? value.to_s : nil
    }
  )
end
