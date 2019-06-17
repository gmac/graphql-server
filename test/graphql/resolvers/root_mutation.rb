require "graphql_server/base_mutation_resolver"

class RootMutationResolver < GraphQLServer::BaseMutationResolver
  def self.make_hay(obj, args, context)
    {
      description: "That sure is some hay",
      color: args[:color],
      was_sun_shining: args[:whileSunShines]
    }
  end
end
