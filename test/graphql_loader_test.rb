require "test_helper"

class GraphQLLoaderTest < Minitest::Spec
  include GraphQLServer::SchemaTestHelper

  before do
    StatsDClient.reset!
  end

  def test_single_loader_with_valid_uid
    query(%({
      loaderWithUid(uid: "Widget:23") {
        id
      }
    }))

    assert_result({
      "loaderWithUid"=>{"id"=>"23"}
    })

    assert_equal StatsDClient.current_stats.keys, [
      'graphql.query',
      'graphql.field.root_query.loader_with_uid',
      'graphql.field.widget.id',
      'graphql.batch_loader.record_loader.widget.id',
    ]
  end

  def test_single_loader_with_invalid_uid
    query(%({
      loaderWithUid(uid: "Sprocket:23") {
        id
      }
    }))

    assert_result({
      "loaderWithUid"=>nil
    })

    errors = result.to_h.dig('errors')
    assert_equal errors.length, 1
    assert_equal errors[0].dig('message'), 'Invalid uid: expected "Sprocket:23" to start with "Widget:"'
    assert_equal errors[0].dig('path'), ['loaderWithUid']
    assert_equal errors[0].dig('extensions', 'code'), 'BAD_USER_INPUT'
    assert_equal 1, StatsDClient.increments('graphql.error.bad_user_input')
  end

  def test_single_loader_with_not_found
    query(%({
      loaderWithUid(uid: "Widget:101") {
        id
      }
    }))

    assert_result({
      "loaderWithUid"=>nil
    })

    errors = result.to_h.dig('errors')
    assert_equal errors.length, 1

    assert_equal errors[0].dig('message'), 'Record not found for "Widget:101"'
    assert_equal errors[0].dig('path'), ['loaderWithUid']
    assert_equal errors[0].dig('extensions', 'code'), 'NOT_FOUND'
    assert_equal 1, StatsDClient.increments('graphql.error.not_found')
  end

  def test_array_loader_with_valid_uids
    query(%({
      loaderWithUids(uids: ["Widget:23", "Widget:24"]) {
        id
      }
    }))

    assert_result({
      "loaderWithUids"=>[{"id"=>"23"}, {"id"=>"24"}]
    })
  end

  def test_array_loader_with_invalid_uids
    query(%({
      loaderWithUids(uids: ["Sprocket:23", "Sprocket:24", "Widget:101"]) {
        id
      }
    }))

    assert_result({
      "loaderWithUids"=>[nil, nil, nil]
    })

    errors = result.to_h.dig('errors')
    assert_equal errors.length, 3

    assert_equal errors[0].dig('path'), ['loaderWithUids', 0]
    assert_equal errors[0].dig('extensions', 'code'), 'BAD_USER_INPUT'

    assert_equal errors[1].dig('path'), ['loaderWithUids', 1]
    assert_equal errors[1].dig('extensions', 'code'), 'BAD_USER_INPUT'

    assert_equal errors[2].dig('path'), ['loaderWithUids', 2]
    assert_equal errors[2].dig('extensions', 'code'), 'NOT_FOUND'

    assert_equal 2, StatsDClient.increments('graphql.error.bad_user_input')
    assert_equal 1, StatsDClient.increments('graphql.error.not_found')
  end

  def test_array_loader_with_mixed_uids
    query(%({
      loaderWithUids(uids: ["Widget:23", "Sprocket:24", "Widget:101"]) {
        id
      }
    }))

    assert_result({
      "loaderWithUids"=>[{"id"=>"23"}, nil, nil]
    })

    errors = result.to_h.dig('errors')
    assert_equal errors.length, 2

    assert_equal errors[0].dig('path'), ['loaderWithUids', 1]
    assert_equal errors[0].dig('extensions', 'code'), 'BAD_USER_INPUT'

    assert_equal errors[1].dig('path'), ['loaderWithUids', 2]
    assert_equal errors[1].dig('extensions', 'code'), 'NOT_FOUND'

    assert_equal 1, StatsDClient.timings('graphql.query')
    assert_equal 1, StatsDClient.timings('graphql.batch_loader.record_loader.widget.id')
    assert_equal 1, StatsDClient.increments('graphql.error.bad_user_input')
    assert_equal 1, StatsDClient.increments('graphql.error.not_found')
  end

  def test_array_loader_with_case_sensitive_keys
    query(%({
      loaderWithCaseSensitiveKeys(names: ["yessir", "Nope"]) {
        name
      }
    }))

    assert_result({
      "loaderWithCaseSensitiveKeys"=>[{"name"=>"yessir"}, nil]
    })

    errors = result.to_h.dig('errors')
    assert_equal errors.length, 1

    assert_equal errors[0].dig('path'), ['loaderWithCaseSensitiveKeys', 1]
    assert_equal errors[0].dig('extensions', 'code'), 'NOT_FOUND'
  end
end
