class GraphQLServer::Railtie < Rails::Railtie
  config.before_configuration do |app|
    app.config.eager_load_paths += [
      "#{Rails.root}/app/graphql/entities",
      "#{Rails.root}/app/graphql/resolvers"
    ]

    app.config.autoload_paths += [
      "#{Rails.root}/app/graphql/entities",
      "#{Rails.root}/app/graphql/resolvers"
    ]
  end

  config.to_prepare do
    GraphQLServer::FieldResolutionRouter::FieldResolver.resolver_classes = {}
  end

  # Auto-configure the schema_dir_path
  initializer 'graphql_server.schema_dir' do
    GraphQLServer.configure do |c|
      c.schema_dir_path = Rails.root.join("app/graphql/schema").to_s
    end
  end

  # Reload schema when schema files change
  initializer 'graphql_server.schema_reloader' do |app|
    watched_dirs = { GraphQLServer.config.schema_dir_path => ['graphql'] }
    schema_reloader = app.config.file_watcher.new([], watched_dirs) do
      GraphQLServer.reload_schema!
    end
    app.reloaders << schema_reloader
    config.to_prepare { schema_reloader.execute_if_updated }
  end
end
