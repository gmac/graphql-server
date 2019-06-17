$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "graphql_server"
require "pp"

require "active_support/concern"
require "minitest/autorun"
require "minitest/reporters"


reporter_options = { :color => true, :fast_fail => true }
reporter_options[:color] = false if ENV["NO_COLOR"]
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(reporter_options)]

module GraphQLServer::SchemaTestHelper
  extend ActiveSupport::Concern

  included do
    cattr_accessor :log_raw_response
  end

  GraphQLServer.configure do |config|
    config.schema_dir_path = File.join("test", "graphql", "schema")
  end

  def schema
    @schema ||= GraphQLServer.schema
  end

  def query(query, variables: {})
    @result = schema.execute(query, variables: variables)
    if self.class.log_raw_response
      puts
      puts @result.to_h.pretty_inspect
      puts
    end
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
