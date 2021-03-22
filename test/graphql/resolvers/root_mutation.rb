require "graphql_server/base_mutation_resolver"

class RootMutationResolver < GraphQLServer::BaseMutationResolver
  def self.make_widget(obj, args, context)
    { id: 'r2D2c3P0', name: args[:name] }
  end
end
