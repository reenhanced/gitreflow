module RspecStubHelpers
  def stub_with_fallback(obj, method)
    original_method = obj.method(method)
    allow(obj).to receive(method).with(anything()) { |*args| original_method.call(*args) }
    return allow(obj).to receive(method)
  end
end
