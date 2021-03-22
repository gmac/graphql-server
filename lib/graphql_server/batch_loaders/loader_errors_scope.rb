module GraphQLServer::BatchLoaders
  class LoaderErrorsScope
    include GraphQLServer::Errors
    attr_reader :loader, :context

    def initialize(loader, context, options={})
      @loader = loader
      @context = context
      @options = options
    end

    def load(key)
      map_errors(@context, key, **@options) { loader.load(key) }
    end

    def load_many(keys)
      map_errors(@context, keys, **@options) { loader.load_many(keys) }
    end

    def load_uid(uid, class_name, cast_as=:to_i)
      map_errors(@context, uid, **@options) { loader.load_uid(uid, class_name, cast_as) }
    end

    def load_uids(uids, class_name, cast_as=:to_i)
      map_errors(@context, uids, **@options) { loader.load_uids(uids, class_name, cast_as) }
    end
  end
end
