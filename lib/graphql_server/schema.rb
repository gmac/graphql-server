require "graphql_server/instrumentation/query"
require "graphql_server/instrumentation/field"
require "graphql_server/batch_executor"
require "graphql_server/field_resolution_router"
require "active_support/core_ext/time/zones"
require "graphql/errors"
require "graphql/batch"

module GraphQLServer
  module Schema

    def self.load
      schema = load_schema_from_definition

      schema.define do
        # for methods that return Interfaces or Unions,
        # this method is invoked, and we must tell GraphQL
        # which specific GraphQL type to use,
        # given the type of the object. e.g.,
        # for a SuperGroup that implements EntryGroupInterface,
        # use the GraphQL type: Types::SuperGroupType
        resolve_type ->(type, object, context) {
          unless GraphQLServer.config.type_resolution.nil?
            type_name = GraphQLServer.config.type_resolution.call(type, object, context)
            schema.types[type_name]
          end
        }

        # we include this module even if config.instrument_queries
        # is false, because it handles the overall stats collection
        # setup and flushing on which the other instrumenters
        # depend. (this module checks config.instrument_queries directly
        # to determine if individual queries should be instrumented.)
        instrument(:query, GraphQLServer::Instrumentation::Query)

        if GraphQLServer.config.instrument_fields
          instrument(:field, GraphQLServer::Instrumentation::Field.new)
        end

        use GraphQL::Batch, executor_class: GraphQLServer::BatchExecutor
        use GraphQL::Subscriptions::ActionCableSubscriptions if defined?(ActionCable)
      end

      setup_scalars!(schema)
      handle_errors!(schema) if defined?(ActiveRecord)

      GraphQLServer.config.run_schema_loaded_callbacks(schema)

      schema
    end

    # TODO: consider extracting scalar definitions out of this file, into
    # something that looks more like the /resolvers dir
    def self.setup_scalars!(schema)
      schema.types['Any'].define do
        coerce_input ->(value, context) do
          value
        end
        coerce_result ->(value, context) do
          value
        end
      end

      schema.types['DateTime'].define do
        coerce_input ->(value, context) do
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
        end
        coerce_result ->(value, context) do
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
        end
      end

      schema.types['JSON'].define do
        coerce_input ->(value, context) do
          value.present? ? JSON.parse(value) : nil
        end
        coerce_result ->(value, context) do
          value.present? ? value : nil
        end
      end

      schema.types['TimeZone'].define do
        coerce_input ->(value, context) do
          value.present? ? ActiveSupport::TimeZone[value] : nil
        end
        coerce_result ->(value, context) do
          if value.present? && ActiveSupport::TimeZone[value]
            ActiveSupport::TimeZone[value].tzinfo.canonical_identifier
          else
            nil
          end
        end
      end
    end

    def self.handle_errors!(schema)
      GraphQL::Errors.configure(schema) do
        rescue_from ActiveRecord::RecordNotFound do |e|
          nil
        end

        rescue_from ActiveRecord::RecordInvalid do |e|
          GraphQL::ExecutionError.new(e.record.errors.full_messages.join("\n"), extensions: { code: 'VALIDATION' })
        end
      end
    end

    def self.load_schema_from_definition
      schema_definition = ""
      files = Dir.glob(File.join(GraphQLServer.config.schema_dir_path, "*.graphql"))
      if files.count == 0
        raise RuntimeError,
          "no .graphql files found in path specified by "\
          "GraphQLServer.config.schema_dir_path. Please ensure that you are "\
          "initializing a config and passing a valid path to a directory with "\
          ".graphql files."
      end

      included = Dir.glob(File.join(File.dirname(__FILE__), "schema", "*.graphql"))

      (included + files).each do |f|
        schema_fragment = File.read(f)
        schema_definition += schema_fragment + "\n\n"
      end

      GraphQL::Schema.from_definition(
        schema_definition,
        default_resolve: GraphQLServer::FieldResolutionRouter
      )
    end

  end
end
