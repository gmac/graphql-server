# GraphQLServer

GraphQLServer is an opinionated way to build a GraphQL server in Ruby via a schema and set of resolvers.

## Setup

The only required configuration is `schema_dir_path`, the location of the directory that contains your `.graphql` SDL files. The rest of the values default to false.

If you are using Rails, then `schema_dir_path` is automatically set to `app/graphql/schema`, and the schema is automatically reloaded when `.graphql` files are modified in development. To achieve this with other frameworks, you can call `GraphQLServer.reload_schema!` in a code reload hook.

If you have any Unions or Interfaces defined in your schema, graphql-ruby needs extra information in order to know how to resolve to a concrete base type. You can read about this more [in their docs](http://graphql-ruby.org/schema/definition.html#object-identification-hooks), but the gist is that you need to provide a `on_type_resolution` block that returns the concrete type name as a String. You are given the `type`, `object`, and `context` instances, similar to the process of writing a resolver, in order to return the correct type names.

It's likely that you want to configure the `graphql-errors` package, which you can do via the `after_schema_load` block. See below for an example.

```ruby
# In an initializer or similar
GraphQLServer.configure do |config|
  config.instrument_queries = true
  config.instrument_fields = true
  config.instrument_batch_loaders = true
  config.statsd_logger = $STATSD
  config.schema_dir_path = Rails.root.join("app/graphql/schema").to_s

  config.on_type_resolution do |type, object, context|
    case type.name
    when 'ExampleInterface'
      object.class.base_class.name
    when 'ExampleUnion'
      object.type_name
    end
  end

  config.after_schema_load do |schema|
    GraphQL::Errors.configure(schema) do
      # can choose any error class here and define multiple rescue_from blocks
      rescue_from StandardError do |e|
        # some combination of...

        report_to_notifier(e) # to send to an outbound service
        log_error(e) # to log the error in a centralized location

        # to provide a standard GraphQL response wrapped in an error code
        GraphQL::ExecutionError.new(
          e.message,
          extensions: { code: 'UNKNOWN' }
        )

        # ...and so on
      end
    end
  end
end
```
