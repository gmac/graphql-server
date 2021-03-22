require "graphql/batch"

module GraphQLServer::Instrumentation
  module BatchLoader

    def instrumentation_key
      raise NotImplementedError, "#{self.class.name} needs to define #instrumentation_key"
    end

    def resolve(*args)
      if GraphQLServer.config.instrument_batch_loaders
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ret = super
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        stats_collector.add_to_batch_loader_duration(instrumentation_key, duration)
        ret
      else
        super
      end
    end

    private

    def stats_collector
      GraphQL::Batch::Executor.current.stats_collector
    end

  end
end
