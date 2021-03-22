require "graphql_server/base_resolver"

class TestResolver < GraphQLServer::BaseResolver
  alias_fields({
    aliased_field: :field_without_args
  })

  def self.resolver_field(obj, args, context)
    ":tada:"
  end
end
