$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'warning'
Gem.path.each do |path|
  # ignore warnings from auto-generated GraphQL lib code.
  # makes our test suite run without hundreds of lines of benign warnings
  Warning.ignore(/.*mismatched indentations.*/)
  Warning.ignore(/.*splat keyword arguments.*/)
  Warning.ignore(/.*passed as a single Hash.*/)
  Warning.ignore(/.*instance variable @\w+ not initialized*/)
end

require "graphql_server"
require "pp"

require "active_support/concern"
require "active_support/core_ext/hash"
require "minitest/autorun"
require "minitest/reporters"

require_relative "graphql/resolvers/root_query"
require_relative "graphql/resolvers/root_mutation"
require_relative "graphql/resolvers/test"
require_relative "mocks/statsd_client"
require_relative "mocks/widget"


reporter_options = { :color => true, :fast_fail => true }
reporter_options[:color] = false if ENV["NO_COLOR"]
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(reporter_options)]

module GraphQLServer::SchemaTestHelper
  extend ActiveSupport::Concern

  GraphQLServer.configure do |config|
    config.statsd_logger = StatsDClient
    config.camelize_arguments = true
    config.instrument_queries = true
    config.instrument_fields = true
    config.instrument_batch_loaders = true
    config.schema_dir_path = File.join("test", "graphql", "schema")
    config.on_type_resolution do |type, object, context|
      object[:__typename]
    end
  end

  def query(query, variables: {}, context: {})
    @result = GraphQLServer.execute({ query: query, variables: variables }, context)
  end

  def result
    @result
  end

  def result_as_hash
    hsh = result.to_hash
    if hsh.key?("data")
      hsh = hsh["data"]
    end
    hsh
  end

  def assert_result(expectation)
    assert_equal expectation, result_as_hash
  end

end
