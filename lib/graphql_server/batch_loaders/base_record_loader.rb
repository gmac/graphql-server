require "graphql/batch"

# Abstract class for batch-loading ActiveRecord records by key, with optional
# where + includes + references args
module GraphQLServer::BatchLoaders
  class BaseRecordLoader < BaseLoader
    def initialize(model, column: model.primary_key, where: nil, includes: nil, references: nil)
      @model = model
      @column = column.to_s
      @column_type = model.type_for_attribute(@column)
      @where = where
      @includes = includes
      @references = references
    end

    def load(key)
      super(@column_type.cast(key))
    end

    def perform(keys)
      raise NotImplementedError, "#{self.class.name} needs to define #perform"
    end

    # we may ultimately want to extend this to include all the "where" and "includes"
    # as well (when present) so that we can instrument more granularly
    def instrumentation_key
      "#{self.class.name.demodulize}.#{@model.name.demodulize}.#{@column}"
    end

    private

    def query(keys)
      scope = @model
      scope = scope.where(@where) if @where
      scope = scope.includes(@includes) if @includes
      scope = scope.references(@references) if @references
      scope.where(@column => keys)
    end
  end
end
