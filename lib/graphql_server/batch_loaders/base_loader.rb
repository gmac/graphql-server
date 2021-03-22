require "graphql/batch"
require "graphql_server/instrumentation/batch_loader"
require "graphql_server/batch_loaders/loader_errors_scope"

module GraphQLServer::BatchLoaders
  class BaseLoader < GraphQL::Batch::Loader
    include GraphQLServer::Instrumentation::BatchLoader

    def self.map_errors(context, options={})
      self.for.map_errors(context, options)
    end

    def self.load_uid(uid, class_name, cast_as=:to_i)
      self.for.load_uid(uid, class_name, cast_as)
    end

    def self.load_uids(uids, class_name, cast_as=:to_i)
      self.for.load_uids(uids, class_name, cast_as)
    end

    def map_errors(context, options={})
      LoaderErrorsScope.new(self, context, options)
    end

    def load_uid(uid, class_name, cast_as=:to_i)
      parse_and_load_uids([uid], class_name, cast_as).first
    end

    def load_uids(uids, class_name, cast_as=:to_i)
      Promise.all(parse_and_load_uids(uids, class_name, cast_as))
    end

  private

    def parse_and_load_uids(uids, class_name, cast_as=:to_i)
      prefix = "#{class_name}:"
      uids.map do |uid|
        if uid.start_with?(prefix)
          load(uid.delete_prefix(prefix).send(cast_as))
        else
          ::GraphQLServer::BaseResolver.user_input_error(%(Invalid uid: expected "#{uid}" to start with "#{prefix}"))
        end
      end
    end
  end
end
