module GraphQLServer::Instrumentation

  class StatsCollector

    def initialize(statsd_logger)
      @statsd = statsd_logger
      reset_stats!
    end

    def set_query_start_time(start_time)
      @query_start_time = start_time
    end

    def set_query_end_time(end_time)
      if @query_start_time.nil?
        raise "Can't set a query end time without setting a start time first."
      end

      @query_end_time = end_time
      @query_duration = @query_end_time - @query_start_time
    end

    def add_to_field_duration(type_name, field_name, duration)
      key = field_key(type_name, field_name)
      @field_durations[key] += duration
    end

    def add_to_batch_loader_duration(name, duration)
      key = batch_loader_key(name)
      @batch_loader_durations[key] += duration
    end

    def increment_error_count(err)
      key = error_key(err)
      @error_counts[key] += 1
    end

    def flush!
      @statsd.batch do |batch|
        if @query_duration.present?
          batch.timing query_key, @query_duration
        end

        @batch_loader_durations.each do |key, duration|
          batch.timing key, duration
        end

        @field_durations.each do |key, duration|
          batch.timing key, duration
        end

        @error_counts.each do |key, count|
          batch.increment key, count
        end
      end
      reset_stats!
    end

    private

    def reset_stats!
      @field_durations        = Hash.new(0.0)
      @batch_loader_durations = Hash.new(0.0)
      @error_counts           = Hash.new(0)
      @query_start_time       = nil
      @query_end_time         = nil
    end

    def query_key
      statsd_key("query")
    end

    def field_key(type_name, field_name)
      statsd_key("field.#{type_name.underscore}.#{field_name.underscore}")
    end

    def batch_loader_key(name)
      statsd_key("batch_loader.#{name.underscore}")
    end

    def error_key(err)
      case err
      when GraphQL::ParseError
        code = 'PARSE'
      when GraphQL::ExecutionError
        code = err.extensions.try(:[], :code) || 'UNKNOWN'
      else
        code = 'UNKNOWN'
      end

      statsd_key("error.#{code.downcase}")
    end

    def statsd_key(suffix)
      "graphql.#{suffix}"
    end

  end
end
