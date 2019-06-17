require "test_helper"

require_relative "graphql/resolvers/root_query"
require_relative "graphql/resolvers/root_mutation"
require_relative "graphql/resolvers/test"

class GraphQLServerTest < Minitest::Test
  include GraphQLServer::SchemaTestHelper

  # turn this on to see the full hash that comes back from the graphql query
  self.log_raw_response = false

  TEST_QUERY = <<~GRAPHQL
    {
      heartbeat
    }
  GRAPHQL

  def test_query
    query(TEST_QUERY)
    assert_result({
      "heartbeat" => "OK"
    })
  end

  TEST_RESOLVER_QUERY = <<~GRAPHQL
    {
      test {
        smoothLyrics
        greaterThanThree
      }
    }
  GRAPHQL

  def test_custom_resolver
    query(TEST_RESOLVER_QUERY)

    assert_result({
      "test" => {
        "smoothLyrics" => "Man, it's a hot one / Like seven inches from the midday sun",
        "greaterThanThree" => 4
      }
    })
  end

  TEST_MUTATION_QUERY = <<~GRAPHQL
    mutation {
      makeHay(color: "Green") {
        description
        wasSunShining
        color
      }
    }
  GRAPHQL

  def test_mutation_resolver
    query(TEST_MUTATION_QUERY)

    assert_result({
      "makeHay" => {
        "description" => "That sure is some hay",
        "wasSunShining" => true,
        "color" => "Green"
      }
    })
  end

  TEST_ROUTER_QUERY_POSITIVE = <<~GRAPHQL
    query {
      test {
        hash {
          exists
        }
      }
    }
  GRAPHQL

  TEST_ROUTER_QUERY_NEGATIVE = <<~GRAPHQL
    query {
      test {
        hash {
          doesNotExist
        }
      }
    }
  GRAPHQL

  def test_field_resolution_router
    query(TEST_ROUTER_QUERY_POSITIVE)
    assert_result({
      "test" => {
        "hash" => {
          "exists" => true
        }
      }
    })

    query(TEST_ROUTER_QUERY_NEGATIVE)
    assert_result({
      "test" => {
        "hash" => {
          "doesNotExist" => nil
        }
      }
    })
  end
end
