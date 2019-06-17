require "graphql_server/batch_loaders/base_record_loader"

# Batch-load: look up a single record by key
module GraphQLServer::BatchLoaders
  class RecordLoader < BaseRecordLoader

    def perform(keys)
      query(keys).each { |record| fulfill(record.public_send(@column), record) }
      keys.each { |key| fulfill(key, nil) unless fulfilled?(key) }
    end

  end
end
