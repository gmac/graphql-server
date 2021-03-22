require "graphql_server/instrumentation/stats_collector"
require "graphql/batch"

module GraphQLServer::Instrumentation
  module Query

    # TODO: decide whether to send data into GraphQLCounter
    # to track how much time is spend executing graphql queries, and how many
    # queries are executed, in the context of a given rails request.
    # those metrics are currently included in the set of request-level
    # CustomInstrumenting metrics, but they are currently unused.
    # do we actually need them, or is what we're tracking here sufficient?

    def self.before_query(query)
      # Always install a stats collector instance so that it's available
      # to other instrumentations that may be enabled separately (fields)
      query.context[:stats_collector] = GraphQLServer::Instrumentation::StatsCollector.new(query.context)

      if GraphQLServer.config.instrument_queries
        op_type = query.selected_operation.operation_type
        query.context[:stats_collector].set_execution_start_time(op_type, Process.clock_gettime(Process::CLOCK_MONOTONIC))
        GraphQL::Batch::Executor.current.stats_collector(query.context) if GraphQLServer.config.instrument_batch_loaders
      end
    end

    def self.after_query(query)
      if GraphQLServer.config.instrument_queries
        query.context[:stats_collector].set_execution_end_time(Process.clock_gettime(Process::CLOCK_MONOTONIC))
        query.context.errors.each do |err|
          query.context[:stats_collector].increment_error_count(err)
        end
        query.context[:stats_collector].flush!
      end

      # batch loaders don't have access to the query context,
      # so we store their metrics separately in the
      # GraphQL::Batch::Executor.current object (our custom
      # GraphQLServer::BatchExecutor class), which is created fresh for
      # every new query
      if GraphQLServer.config.instrument_batch_loaders && GraphQL::Batch::Executor.current.stats_collector.present?
        GraphQL::Batch::Executor.current.stats_collector.flush!
      end
    end
  end
end
