# GraphQLServer

GraphQLServer is an opinionated way to build a GraphQL server in Ruby via a schema and set of resolvers. Some of its choices (and, we believe, benefits) include:

* Schema definition via GraphQL SDL in pure `.graphql` files
* Automatic field resolution, when desired, based on matching GraphQL type names to Ruby class names
* Automatic case conversion so all your ruby code can be snake_case while your GraphQL fields are camelCase
* Some amount of Rails compatibility, including classifying some ActiveRecord error classes, but compatible with any framework
* Provides some default scalar types for Ruby interoperability:
    * DateTime, based on an ISO 8601-formatted string
    * TimeZone, based on ActiveSupport::TimeZone
    * JSON
* Extended error messages including machine-readable error classification, traceable request ids, and timestamps
* An extensible set of ActiveRecord-ready [DataLoader](https://github.com/facebook/dataloader)-style classes via [graphql-batch](https://github.com/Shopify/graphql-batch)
* statsd-friendly instrumentation

GraphQLServer is built on top of [graphql-ruby](https://github.com/rmosolgo/graphql-ruby), [graphql-batch](https://github.com/Shopify/graphql-batch), and [graphql-errors](https://github.com/kadirahq/graphql-errors).

We recommend the use of [graphiql-rails](https://github.com/rmosolgo/graphiql-rails) for rails projects using this gem.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "graphql_server", :git => "git@github.com:voxmedia/graphql_server.git"
```

**NOTE:** It is recommended that you add a version range before taking your code into production. See [the Bundler site](https://bundler.io/gemfile.html) for more info.

Then execute:

```bash
$ bundle install
```

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

## Usage

### Creating a schema

* make a directory that will hold all of your graphql files
* add a file called `schema.graphql` with the following:

```graphql
schema {
  query: RootQuery
  mutation: RootMutation
}
```

* create corresponding .graphql files for each of those two types (you can remove the Mutation field and type if you don't plan on having any of them in your API) and build out your schema from there.

### Automatic field resolution

Our [custom field resolution router](https://github.com/voxmedia/graphql_server/blob/master/lib/graphql_server/field_resolution_router.rb) governs how the GraphQL schema maps to Ruby code. It uses some light metaprogramming magic and works like this:

1. When resolving field `bar` on type `Foo`, check whether a `FooResolver#bar` class method exists; if it does, invoke it
2. If the method does not exist, then check whether a zero-argument `bar` instance method exists on the `foo` parent object; if it does, invoke it
3. If neither method exists, then raise a `FieldResolutionRouter::Error`

This strategy allows for some conveniences when working with ActiveRecord models or "entities" (see below) that inherit from `GraphQLServer::BaseEntity`. For example, a `Network` schema definition might define `id` and `name` fields, but we don't actually need to implement those methods in the resolver if methods with the same names already exist on the underlying ActiveRecord model.

The router also handles underscoring field names that appear in queries, so that a query for the `Foo#barBaz` field will map to the `Foo#bar_baz` resolver method.

### Setting up resolvers

If you need to write custom code to fulfill a query or a mutation for a GraphQL type, or want to override behavior of automatic field resolution, you will want to create a resolver for that type. To do so, define a class `[Type]Resolver < GraphQLServer::BaseResolver` and ensure that the file is loaded by your app. (In the case of a mutation, use `< GraphQLServer::BaseMutationResolver` instead.) When writing a query you have two options: you can alias fields or define a custom resolver method. With a mutation, you can skip straight to the custom resolver definition, since you'll need to define what the mutation does.

#### Aliasing fields

`alias_fields` is a method inherited from the `BaseResolver` that accepts a hash mapping from GraphQL field name symbol keys to ruby method name symbol values. This works similarly to the automatic field resolution—it still requires the Ruby object method to have no arguments, for example—but allows you to have a GraphQL field named something different from the method or attribute on the Ruby object.

#### Custom resolver methods

You can define a method on the resolver class you've created with the snake_case version of the field you want to resolve, like so:

```ruby
class UserResolver < GraphQLServer::BaseResolver
  def self.full_name(object, context, arguments)
    "#{object.first_name object.family_name}"
  end
end
```

where the `object` is the retrieved Ruby object of the same class name as the GraphQL type, `context` contains whatever you pass into graphql-ruby's `Schema#execute` method, and `arguments` is the hash of any arguments that were added to the field in the query.

### Using batch loaders with ActiveRecord

GraphQLServer provides several built-in batch loaders that assist with the N+1 problem of querying fields that return collections of related objects. You should use a batch loader at any point in your GraphQL API that you'd normally call on [ActiveRecord.includes](https://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations).

Batch loaders are a [Ruby implementation](https://github.com/Shopify/graphql-batch) of the [Facebook data loader strategy](https://github.com/facebook/dataloader). See the [graphql-batch README](https://github.com/Shopify/graphql-batch) for more information. GraphQLServer's built-in batch loaders wrap `ActiveRecord::Associations::Preloader` to handle most common situations. For unique situations that require special optimization patterns, consider writing a [[custom batch loader|Custom Batch Loaders]].

#### The `association_loader` batch loader

Here's a model:

```ruby
class Album < ActiveRecord::Base
  belongs_to :band
  has_many :songs
end
```

There are two points of potential inefficiency here: an album needs to batch all of its songs, and a list of albums would need to batch all bands together. The `association_loader` handles these bulk operations:

```ruby
class AlbumResolver < GraphQLServer::BaseResolver
  def self.band(obj, args, ctx)
    batch_loader(:association_loader)
      .for(::Album, :band)
      .load(obj)
  end

  def self.songs(obj, args, ctx)
    batch_loader(:association_loader)
      .for(::Album, :songs)
      .load(obj)
  end
end
```

The `association_loader` fetches all associated records in bulk, and then return the relations for each requested object. This works extremely well for fulfilling direct associations.

#### The `includes_loader` batch loader

It's not uncommon to encounter situations involving deeply-nested data access. Here's another model:

```ruby
class Band < ActiveRecord::Base
  has_many :albums

  def total_songs
    albums.reduce(0) { |sum, a| sum += a.songs.size }
  end
end
```

A band has a direct association to albums that can be resolved with the `association_loader`. However, the `total_songs` method reduces data using albums _and_ their songs. This is a situation where the `includes_loader` can preload all related objects before calling on the computed value.

```ruby
class BandResolver < GraphQLServer::BaseResolver
  def self.albums(obj, args, ctx)
    batch_loader(:association_loader)
      .for(::Band, :albums)
      .load(obj)
  end

  def self.total_songs(obj, args, ctx)
    batch_loader(:includes_loader)
      .for(::Band, { albums: [:songs] })
      .load(obj)
      .then(&:total_songs)
  end
end
```

The `includes_loader` accepts a relationship graph in any format compatible with [ActiveRecord.includes](https://guides.rubyonrails.org/active_record_querying.html#eager-loading-associations). It will load the deeply-nested associations, and then return the _original request object_ which may now efficiently call upon computed data.

### Custom Batch Loaders
Associations are tricky. You may encounter situations where efficiently loading data surpasses the capabilities of `association_loader` and `includes_loader` alone. That's okay, because you can always write a custom batch loader tailored to the needs of your model.

#### Setup a batch loader class

Custom batch loaders are typically stored at `app/graphql/loaders`. You'll want to add the loaders directory to Rails' eager load paths. Then, setup a skeleton loader class:

```ruby
class MyCustomLoader < GraphQLServer::BatchLoaders::BaseLoader
  
  def initialize(scope)
    @scope = scope
  end

  def instrumentation_key
    [self.class.name.demodulize, @scope].join('.')
  end

  def cache_key(record)
    record.object_id
  end
  
  def perform(records)
    # do work...
  end
end
```

* `initialize`: this method is optional. It accepts arguments that scope the loader, passed via `MyCustomLoader.for(x, y, ...)`. The loader will run once per generation for each unique set of scoping arguments. If initialization is omitted, the loader will be _unscoped_ and only run once per generation for all calls to it.

* `instrumentation_key`: defines a namespace string for instrumentation logging. This namespace should include the loader class name and any scoping arguments.

* `cache_key`: a method for keying objects passed to the loader. Returning the object's `object_id` (Ruby memory address) is a good default to ensure that all requested objects are considered unique.

* `perform`: receives a list of requested records to be fulfilled, and will do the work of loading them.

#### Write the `perform` method

Example scenario: we have `User` models related through a Twitter-style `Follow` relationship – a user follows many, and has many followers. All of this data exists in a single join table, so a custom loader could fetch all follows/followers for many users with a single query. It might look like this:

```ruby
class UserFollowsLoader < GraphQLServer::BatchLoaders::BaseLoader
  
  def instrumentation_key
    self.class.name.demodulize
  end

  def cache_key(record)
    record.object_id
  end
  
  # Many user records are passed in to the `perform` method...
  def perform(users)

    # Query for all follows that include these user ids
    ids = users.map(&:id).uniq
    follows_by_user = Follow.where('followed_id IN (?) OR follower_id IN (?)', ids, ids).each_with_object({}) do |follow, memo|
      
      # Reduce the results down to a partitioned mapping of user_id => [follow]
      memo[follow.followed_id] ||= []
      memo[follow.followed_id] << follow

      memo[follow.follower_id] ||= []
      memo[follow.follower_id] << follow
    end

    # Loop through all users and fulfill each with their corresponding follows
    users.each do |user|
      fulfill(user, follows_by_user[user.id] || []) unless fulfilled?(user)
    end
  end
end
```

#### Call on the loader from resolvers

Lastly, we need to call on the loader in our resolvers (and possibly do some light filtering on the results...). By chaining a `.then` onto the loader, we may do some final alterations to the resolved data before returning it in the API response.

```ruby
class UserResolver < GraphQLServer::BaseResolver

  def self.followers(obj, args, ctx)
    ::UserFollowsLoader
      .load(obj)
      .then do |follows|
        follows.select { |f| f.followed_id == obj.id }
      end
  end

  def self.following(obj, args, ctx)
    ::UserFollowsLoader
      .load(obj)
      .then do |follows|
        follows.select { |f| f.follower_id == obj.id }
      end
  end

end
```

### When to use Entities

Entities act as a stand-in for objects when there is no analogous Ruby object existing in the app to mirror a GraphQL type. You can create one by defining a class called `[Type]Entity < GraphQLServer::BaseEntity` and give it attributes using ActiveModel's `attr_accessor` syntax as a quick way to spec out attributes that match a GraphQL type.

### Hooking up instrumentation

Right now GraphQLServer assumes that when you enable instrumentation, you'll also pass in a statsd client. Set the `statsd_logger` attribute of the server config to the client and you get per-field instrumentation on all of your types.


## TODO

* support for Interfaces and Unions
* support for custom Scalars (see schema.rb)
* writing more TODO items here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `gem_push=no bundle exec rake release`, which will create a git tag for the version, push git commits and tags.

## Changelog

This project keeps a changelog. It's the [CHANGELOG.md](https://github.com/voxmedia/graphql_server/blob/master/CHANGELOG.md) file located in the project root.  Please update it accordingly.
You should also update the [release notes](https://github.com/voxmedia/graphql_server/releases) when tagging a new release.

## Contributing

Bug reports are welcome in Slack on #product-ecosystem or #product-graphql. Pull requests are welcome on GitHub at https://github.com/voxmedia/graphql_server.

## License

The gem is available under the terms of the [MIT License](https://opensource.org/licenses/MIT).
