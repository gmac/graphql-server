require "graphql_server/base_resolver"

class TestResolver < GraphQLServer::BaseResolver
  def self.smooth_lyrics(obj, args, context)
    "Man, it's a hot one / Like seven inches from the midday sun"
  end

  def self.greater_than_three(obj, args, context)
    4
  end
end
