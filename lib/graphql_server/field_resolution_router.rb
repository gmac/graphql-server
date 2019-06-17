require "active_support/core_ext/class/attribute_accessors"
require "active_support/core_ext/string/inflections"

module GraphQLServer

  # The field resolution router maps types and fields defined
  # in the GraphQL schema to Ruby objects and methods. Details here:
  #
  # TODO: move or copy this to the gem's wiki instead of sbn's
  # https://github.com/voxmedia/sbn/wiki/SbnGraphQL#how-field-resolution-works
  module FieldResolutionRouter
    class Error < StandardError; end

    def self.call(type, field, obj, args, ctx)
      FieldResolver.new(type, field, obj, args, ctx).resolve
    end

    class FieldResolver
      cattr_accessor :resolver_classes
      self.resolver_classes = {}

      def initialize(type, field, obj, args, ctx)
        @type  = type
        @field = field
        @obj   = obj
        @args  = args
        @ctx   = ctx
      end

      def resolve
        if resolver_class_implements_field?
          # FooResolver#field(obj, args, ctx)
          call_field_resolution_method(resolver_class, args: [@obj, @args, @ctx])
        elsif can_invoke_method_of_same_name_on_obj?
          # obj#field
          call_field_resolution_method(@obj)
        elsif is_hash_obj?
          # obj[:field] OR obj["field"]
          retrieve_attr_from_hash_obj
        else
          raise_resolver_missing_error
        end
      end

      private

      def call_field_resolution_method(target, args: [])
        target.public_send(field_name, *args)
      end

      def resolver_class_implements_field?
        resolver_class.present? &&
          resolver_class.respond_to?(field_name) &&
          resolver_class.method(field_name).arity == 3
      end

      # only allow this magic if the given field takes no arguments
      # (otherwise I think we would be trying to infer too much about
      # what the developer is trying to do)
      def can_invoke_method_of_same_name_on_obj?
        method_of_same_name_exists_on_obj? && @field.arguments.size == 0
      end

      def method_of_same_name_exists_on_obj?
        @obj.respond_to?(field_name)
      end

      def is_hash_obj?
        (
          (@obj.respond_to?(:key?) && @obj.respond_to?(:[])) &&
          @field.arguments.size == 0
        )
      end

      def retrieve_attr_from_hash_obj
        return @obj[field_name.to_sym] if @obj.key?(field_name.to_sym)
        @obj[field_name]
      end

      def raise_resolver_missing_error
        errors = []
        errors << "#{resolver_class_name}##{field_name}(obj, args, ctx) was not defined."

        if @obj.nil?
          errors << "obj was nil, so could not attempt to fallback on a call to obj##{field_name}."
        elsif method_of_same_name_exists_on_obj? && !can_invoke_method_of_same_name_on_obj?
          errors << "Because the '#{field_name}' field accepts arguments, it must be implemented on #{resolver_class_name}."
        else
          errors << "#{@obj.class.name}##{field_name} was not defined."
        end

        raise FieldResolutionRouter::Error.new(errors.join(" "))
      end

      def resolver_class
        unless resolver_classes.key?(type_name)
          resolver_classes[type_name] = begin
            resolver_class_name.constantize
          rescue NameError
            nil
          end
        end
        resolver_classes[type_name]
      end

      def resolver_class_name
        "#{type_name.camelize}Resolver"
      end

      def type_name
        @type.name
      end

      def field_name
        @field.name.underscore
      end

    end

  end

end
