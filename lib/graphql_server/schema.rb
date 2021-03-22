require "graphql_server/instrumentation/query"
require "graphql_server/batch_executor"
require "graphql_server/field_resolution_router"
require "active_support/core_ext/time/zones"
require "graphql/errors"
require "graphql/batch"

module GraphQLServer
  module Schema

    def self.load
      schema = load_schema_from_definition

      # Always include Query instrumentation because it establishes
      # the stats collection framework used by other parts of the query (fields)
      schema.instrument(:query, GraphQLServer::Instrumentation::Query)
      schema.use(GraphQL::Batch, executor_class: GraphQLServer::BatchExecutor)
      schema.use(GraphQL::Subscriptions::ActionCableSubscriptions) if defined?(ActionCable)
      handle_errors!(schema) if defined?(ActiveRecord)

      GraphQLServer.config.run_schema_loaded_callbacks(schema)
      schema
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
      files = Dir.glob(File.join(GraphQLServer.config.schema_dir_path, "**/*.graphql"))
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
