# Base class for all Resolvers
module GraphQLServer
  class BaseResolver
    extend GraphQLServer::Errors

    cattr_accessor :batch_loader_classes

    self.batch_loader_classes = {}

    def self.field_aliases
      @field_aliases ||= {}
    end

    def self.alias_fields(aliases)
      field_aliases.merge!(aliases)
      aliases.each do |graphql_field_name, method|
        define_singleton_method(graphql_field_name) do |obj, args, ctx|
          result = obj.send(method)
          if ctx[:current_field].type.to_type_signature == "Boolean!"
            result == true # nil handling
          else
            result
          end
        end
      end
    end

    def self.alias_fields_with_association_loader(klass, aliases)
      field_aliases.merge!(aliases)
      aliases.each do |graphql_field_name, method|
        define_singleton_method(graphql_field_name) do |obj, args, ctx|
          batch_loader(:association_loader)
            .for(klass, method)
            .load(obj)
        end
      end
    end

    def self.alias_fields_with_record_loader(klass, aliases)
      field_aliases.merge!(aliases)
      aliases.each do |graphql_field_name, method|
        define_singleton_method(graphql_field_name) do |obj, args, ctx|
          # TODO: don't require that resolver class name match (store base class in resolver?)
          record_class = self.name.demodulize.downcase.gsub('resolver', '')
          batch_loader(:record_loader)
            .for(klass, :column => "#{record_class}_id")
            .load(obj.id)
            .then do |record|
              if record.present?
                record.send(method)
              # coerce nil records for non-nullable boolean fields to false.
              # allows you to make a schema non-nullable without having to
              # do a database migration.
              elsif ctx[:current_field].type.to_type_signature == "Boolean!"
                false
              end
            end
        end
      end
    end

    def self.batch_loader(name)
      key = name.to_s.classify
      batch_loader_classes[key] ||= "GraphQLServer::BatchLoaders::#{key}".constantize
    end

    def self.type(obj, args, context)
      obj.type.underscore.upcase
    end

    # return a hash of any arguments with default values in a type so you can
    # merge it with the provided arguments and pass them on in the case of an input
    # object where that isn't handled for you
    def self.default_arguments_for(type_name)
      type = GraphQLServer.schema.types.fetch(type_name)
      mapping = type.arguments.transform_values { |arg| arg.default_value == :__no_default__ ? nil : arg.default_value }
      mapping.with_indifferent_access
    end
  end
end
