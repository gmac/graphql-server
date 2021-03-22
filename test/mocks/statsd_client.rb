class StatsDClient
  cattr_accessor :current_stats

  self.current_stats = {}

  class StatsBatch
    def initialize(stats)
      @stats = stats
    end

    def timing(key, duration)
      @stats[key] ||= []
      @stats[key] << duration
    end

    def increment(key, count)
      @stats[key] ||= 0
      @stats[key] += count
    end
  end

  def self.batch
    yield(StatsBatch.new(current_stats))
  end

  # Test helpers...

  def self.reset!
    self.current_stats = {}
  end

  def self.timings(key)
    current_stats[key].length
  end

  def self.increments(key)
    current_stats[key]
  end
end
