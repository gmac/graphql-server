class MockActionControllerParameters
  def initialize(obj)
    @obj = obj
  end

  def permit!
    self
  end

  def to_h
    @obj
  end
end
