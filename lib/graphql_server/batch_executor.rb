require "graphql/batch"
require "graphql_server/instrumentation/stats_collector"

module GraphQLServer
  class BatchExecutor < GraphQL::Batch::Executor

    def stats_collector(context = nil)
      @stats_collector ||= GraphQLServer::Instrumentation::StatsCollector.new(context)
    end

  end
end
