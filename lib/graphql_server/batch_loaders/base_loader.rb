require "graphql_server/instrumentation/batch_loader"

module GraphQLServer::BatchLoaders
  class BaseLoader < GraphQL::Batch::Loader
    include GraphQLServer::Instrumentation::BatchLoader
  end
end
