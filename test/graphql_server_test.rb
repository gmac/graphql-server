require "test_helper"
require "mocks/parameters"

class GraphQLServerTest < Minitest::Spec
  include GraphQLServer::SchemaTestHelper

  before do
    StatsDClient.reset!
  end

  def test_query
    query(%({
      heartbeat
    }))

    assert_result({
      "heartbeat" => "OK"
    })

    assert_equal StatsDClient.current_stats.keys, [
      'graphql.query',
      'graphql.field.root_query.heartbeat'
    ]
  end

  def test_mutation_resolver
    query(%(
      mutation {
        widget: makeWidget(name: "droid") {
          id
          name
        }
      }
    ))

    assert_result({
      "widget" => {
        "id" => "r2D2c3P0",
        "name" => "droid",
      }
    })

    assert_equal StatsDClient.current_stats.keys, [
      'graphql.mutation',
      'graphql.field.root_mutation.make_widget',
      'graphql.field.widget.id',
      'graphql.field.widget.name',
    ]
  end

  def test_custom_field_resolver
    query(%({
      test {
        resolverField
      }
    }))

    assert_result({
      "test" => {
        "resolverField" => ":tada:"
      }
    })
  end

  def test_hash_field_resolution
    query(%({
      test {
        hashField {
          exists
          doesNotExist
        }
      }
    }))
    assert_result({
      "test" => {
        "hashField" => {
          "exists" => true,
          "doesNotExist" => nil,
        }
      }
    })
  end

  def test_aliased_field_resolution
    query(%({
      test {
        aliasedField
      }
    }))
    assert_result({
      "test" => {
        "aliasedField" => "OK"
      }
    })
  end

  def test_scalar_resolution
    query(%({
      scalars {
        any
        date
        json
        url
        tz
      }
    }))

    assert_result({
      "scalars"=>{
        "any"=>23,
        "date"=>"2020-07-13T03:01:49Z",
        "json"=>{:hello=>"world"},
        "url"=>"https://vox.com",
        "tz"=>"Asia/Chongqing",
      }
    })
  end

  def test_abstract_type_resolution
    query(%({
      abstract {
        __typename
        id
      }
    }))

    assert_result({
      "abstract"=>{
        "__typename"=>"Orange",
        "id"=>"orange",
      }
    })
  end

  def test_method_arguments
    query(%({
      arguments(
        theObject: {
          pageNumber: 23,
          perPage: 77,
          nested: [{ theId: "abc" }]
        }
        theArray: [{
          pageNumber: 7,
          perPage: 55
        }]
      )
    }))

    assert_result({
      "arguments" => {
        "theObject" => {
          "pageNumber" => 23,
          "perPage" => 77,
          "nested" => [{
            "theId" => "abc",
          }]
        },
        "theArray" => [{
          "pageNumber" => 7,
          "perPage" => 55,
        }]
      }
    })
  end

  def test_default_arguments
    query(%({
      argumentDefaults
    }))

    assert_result({
      "argumentDefaults"=>{
        "nested" => nil,
        "pageNumber" => 1,
        "perPage" => 10
      }
    })
  end

  def test_entity_arguments
    query(%({
      test {
        fieldWithArgs(value: "OK")
        fieldWithoutArgs
      }
    }))

    assert_result({
      "test"=>{
        "fieldWithArgs"=>"OK",
        "fieldWithoutArgs"=>"OK"
      }
    })
  end

  def test_errors_single
    query(%({
      error(id: 1) {
        id
      }
    }))

    assert_result({
      "error"=>nil
    })

    errors = result.to_h.dig('errors')
    assert_equal errors.length, 1
    assert_equal errors[0].dig('extensions', 'code'), 'NOT_FOUND'
  end

  def test_mixed_errors_array
    query(%({
      errors(ids: [1, 2]) {
        id
      }
    }))

    assert_result({
      "errors"=>[{"id"=>"1"}, nil]
    })

    errors = result.to_h.dig('errors')
    assert_equal errors.length, 1

    assert_equal errors[0].dig('message'), 'Invalid key "2"'
    assert_equal errors[0].dig('path'), ['errors', 1]
    assert_equal errors[0].dig('extensions', 'code'), 'BAD_USER_INPUT'
  end

  def test_only_errors_array
    query(%({
      errors(ids: [2, 3]) {
        id
      }
    }))

    assert_result({
      "errors"=>[nil, nil]
    })

    errors = result.to_h.dig('errors')
    assert_equal errors.length, 2

    assert_equal errors[0].dig('message'), 'Invalid key "2"'
    assert_equal errors[0].dig('path'), ['errors', 0]
    assert_equal errors[0].dig('extensions', 'code'), 'BAD_USER_INPUT'

    assert_equal errors[1].dig('message'), 'Record not found for "3"'
    assert_equal errors[1].dig('path'), ['errors', 1]
    assert_equal errors[1].dig('extensions', 'code'), 'NOT_FOUND'
  end

  def test_network_batched_query_execution
    result = GraphQLServer.execute([
      { query: 'query($says:String!){ parrot(says:$says) }', variables: { says: 'squawk' } },
      { query: 'query($says:String!){ parrot(says:$says) }', variables: { says: 'screech' } },
    ])

    assert_equal result.map(&:to_h), [
      {"data"=>{"parrot"=>"squawk"}},
      {"data"=>{"parrot"=>"screech"}},
    ]
  end

  def test_ensure_hash
    result = { "id" => 23 }
    assert_equal GraphQLServer.ensure_hash({ id: 23 }), result
    assert_equal GraphQLServer.ensure_hash({ id: 23 }.with_indifferent_access), result
    assert_equal GraphQLServer.ensure_hash(MockActionControllerParameters.new({ id: 23 })), result
    assert_equal GraphQLServer.ensure_hash('{"id":23}'), result
    assert_equal GraphQLServer.ensure_hash(nil), {}
    assert_equal GraphQLServer.ensure_hash(''), {}
  end
end
