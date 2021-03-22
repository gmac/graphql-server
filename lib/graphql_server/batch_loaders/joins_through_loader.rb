module GraphQLServer::BatchLoaders
  class JoinsThroughLoader < BaseLoader

    RECORD_KEY = '__record_key__'

    def initialize(model, association_name, column)
      @model = model
      @column = column
      @association = model.reflect_on_association(association_name)

      if !@association.is_one_of?([ActiveRecord::Reflection::HasOneReflection, ActiveRecord::Reflection::HasManyReflection])
        raise ArgumentError, "must join through has_one or has_many"
      end
    end

    def instrumentation_key
      [
        self.class.name.demodulize,
        @model.name.underscore,
        @association.name,
        @column,
      ].join('.')
    end

    def perform(keys)
      results = @model
        .joins(@association.name)
        .select("#{@model.table_name}.*, #{@association.table_name}.#{@column} AS #{RECORD_KEY}")
        .where("#{@association.table_name}.#{@column}" => keys)

      if @association.collection?
        results = results.each_with_object({}) do |record, memo|
          memo[record[RECORD_KEY]] ||= []
          memo[record[RECORD_KEY]] << record
        end

        keys.each { |key| fulfill(key, results[key] || []) }
      else
        results.each { |record| fulfill(record[RECORD_KEY], record) }
      end

      keys.each { |key| fulfill(key, nil) unless fulfilled?(key) }
    end
  end
end
