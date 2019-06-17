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
      if GraphQLServer.config.instrument_queries
        query.context[:stats_collector] = GraphQLServer::Instrumentation::StatsCollector.new(GraphQLServer.config.statsd_logger)
        query.context[:stats_collector].set_query_start_time(Process.clock_gettime(Process::CLOCK_MONOTONIC))
      end
    end

    def self.after_query(query)
      if GraphQLServer.config.instrument_queries
        query.context[:stats_collector].set_query_end_time(Process.clock_gettime(Process::CLOCK_MONOTONIC))
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
      if GraphQLServer.config.instrument_batch_loaders &&
         GraphQL::Batch::Executor.current.stats_collector.present?
        GraphQL::Batch::Executor.current.stats_collector.flush!
      end
    end

  end
end
