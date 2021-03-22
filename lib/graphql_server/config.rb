module GraphQLServer
  class Config
    attr_accessor :instrument_fields, :instrument_queries,
      :instrument_batch_loaders, :schema_dir_path, :statsd_logger, :camelize_arguments,
      :after_schema_load_callbacks, :type_resolution, :scalar_resolution

    def initialize
      @instrument_queries = false
      @instrument_fields = false
      @instrument_batch_loaders = false
      @camelize_arguments = false
      @schema_dir_path = nil
      @statsd_logger = nil
      @after_schema_load_callbacks = []
      @type_resolution_callback = nil
      @scalar_resolution = {}
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

    def resolve_scalar(name, coerce_input:, coerce_result:)
      @scalar_resolution[name.to_s] = {
        coerce_input: coerce_input,
        coerce_result: coerce_result,
      }.freeze
    end
  end

end
