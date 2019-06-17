require "graphql_server/batch_loaders/base_record_loader"

# Batch-load: look up many records using a common key
module GraphQLServer::BatchLoaders
  class RecordListLoader < BaseRecordLoader

    def perform(keys)
      records = query(keys)
      keys.each do |key|
        matching_records = records.select { |r| r.public_send(@column) == key }
        fulfill(key, matching_records)
      end
    end

  end
end
