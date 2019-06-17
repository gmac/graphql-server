# Base class for Mutation Resolvers
module GraphQLServer
  class BaseMutationResolver
    def self.type(obj, args, context)
      obj.type.underscore.upcase
    end

    def self.graphql_error(type, message=nil)
      message = type.capitalize if message.nil?
      GraphQL::ExecutionError.new(
        message,
        extensions: { code: type }
      )
    end
  end
end
