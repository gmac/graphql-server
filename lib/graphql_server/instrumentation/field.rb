module GraphQLServer::Instrumentation
  class Field

    def instrument(type, field)
      old_resolve_proc = field.resolve_proc
      new_resolve_proc = ->(obj, args, ctx) {
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        ret = old_resolve_proc.call(obj, args, ctx)
        ctx[:stats_collector].add_to_field_duration(
          type.name, field.name, Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
        )
        ret
      }
      # Return a copy of the field with the new resolve proc
      field.redefine do
        resolve(new_resolve_proc)
      end
    end

  end
end
