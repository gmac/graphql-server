require "graphql/batch"
require "graphql_server/instrumentation/stats_collector"

module GraphQLServer
  class BatchExecutor < GraphQL::Batch::Executor

    def stats_collector
      @stats_collector ||= GraphQLServer::Instrumentation::StatsCollector.new(GraphQLServer.config.statsd_logger)
    end

  end
end
