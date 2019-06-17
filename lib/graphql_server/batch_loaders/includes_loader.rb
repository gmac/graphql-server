require "active_support/cache"

# Batch-load: preload many associations for an ActiveRecord model.
# Loads the association graph and returns the original object.
# Works like `.includes(:sfoo, :bar => [:baz])` for preloading
# a deep object graph before accessing combined data.
# Usage:
#
# batch_loader(:includes_loader)
#   .for(::Thing, [:sfoo, :bar => [:baz]])
#   .load(obj).then do |loaded_obj|
#     loaded_obj.get_sfoo_bar_baz_data
#   end
#
module GraphQLServer::BatchLoaders
  class IncludesLoader < BaseLoader

    def initialize(model, associations)
      @model = model
      @associations = associations
      validate
    end

    def instrumentation_key
      association_ns = ::ActiveSupport::Cache.expand_cache_key(@associations).gsub("/", ".")
      "#{self.class.name.demodulize}.#{@model.name.demodulize}.#{association_ns}"
    end

    def cache_key(record)
      record.object_id
    end

    def perform(records)
      ::ActiveRecord::Associations::Preloader.new.preload(records, @associations)

      records.each do |record|
        fulfill(record, record)
      end
    end

    private

    def validate
      root_associations =\
      if [String, Symbol].include?(@associations.class)
        [@associations]
      elsif @associations.class == Hash
        @associations.keys
      else
        @associations
      end

      unless root_associations.class == Array
        raise ArgumentError, "Invalid definition of associations. Use array, hash, string, or symbol."
      end

      root_associations.each do |assoc_name|
        assoc_name = assoc_name.class == Hash ? assoc_name.keys.first : assoc_name
        unless @model.reflect_on_association(assoc_name)
          raise ArgumentError, "No association #{assoc_name} on #{@model}"
        end
      end
    end

  end
end