module GraphQLServer
  class Config
    attr_accessor :instrument_fields, :instrument_queries,
      :instrument_batch_loaders, :schema_dir_path, :statsd_logger,
      :after_schema_load_callbacks, :type_resolution

    def initialize
      @instrument_queries = false
      @instrument_fields = false
      @instrument_batch_loaders = false
      @schema_dir_path = nil
      @statsd_logger = nil
      @after_schema_load_callbacks = []
      @type_resolution_callback = nil
    end

    def after_schema_load(&callback)
      @after_schema_load_callbacks << callback
    end

    def run_schema_loaded_callbacks(schema)
      @after_schema_load_callbacks.each do |callback|
        callback.call(schema)
      end
    end

    def on_type_resolution(&callback)
      @type_resolution = callback
    end
  end

end
