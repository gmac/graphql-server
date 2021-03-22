class Widget

  class TypeCaster
    def initialize(column)
      @column = column.to_s
    end

    def cast(val)
      case @column
      when 'id'
        val.to_i
      when 'name'
        val.to_s
      end
    end
  end

  def self.type_for_attribute(column)
    TypeCaster.new(column)
  end

  def self.primary_key
    'id'
  end

  def self.where(options)
    if options[primary_key].is_a?(Array)
      options[primary_key].map { |id| id < 100 ? Widget.new(id) : nil }.compact
    elsif options['name'].is_a?(Array)
      options['name'].each_with_index.map { |name, index| Widget.new(index, name.downcase) }
    else
      self
    end
  end

  def self.includes(options)
    self
  end

  def self.references(options)
    self
  end

  attr_reader :id, :name

  def initialize(id, name=nil)
    @id = id
    @name = name || "Widget #{id}"
  end
end
