# Base class for Mutation Resolvers
module GraphQLServer
  class BaseMutationResolver
    extend GraphQLServer::Errors

    def self.type(obj, args, context)
      obj.type.underscore.upcase
    end
  end
end
