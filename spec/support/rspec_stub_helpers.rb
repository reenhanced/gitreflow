module RspecStubHelpers
  def stub_with_fallback(obj, method)
    original_method = obj.method(method)
    obj.stub(method).with(anything()) { |*args| original_method.call(*args) }
    return obj.stub(method)
  end
end
