require "graphql_server/batch_loaders/base_record_loader"

# Batch-load: look up a single record by key
module GraphQLServer::BatchLoaders
  class RecordLoader < BaseRecordLoader

    def perform(keys)
      key_set = keys.to_set

      query(keys).each do |record|
        # anticipate case-insensitive results that may not match a loader key
        key = record.public_send(@column)
        fulfill(key, record) if key_set.include?(key)
      end

      keys.each { |key| fulfill(key, nil) unless fulfilled?(key) }
    end

  end
end
