module GraphQLServer::Instrumentation
  module Field

    def instrument_resolve
      return resolve unless GraphQLServer.config.instrument_fields

      @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = resolve

      if result.is_a?(Promise)
        result.then do |value|
          end_timer
          value
        end
      else
        end_timer
        result
      end
    end

  private

    def end_timer
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time
      @ctx[:stats_collector].add_to_field_duration(type_name, field_name, elapsed)
    end
  end
end
