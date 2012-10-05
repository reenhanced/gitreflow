module GitReflow
  class Service
    METHOD_MUST_BE_IMPLEMENTED_MESSAGE = "This method must be implemented for your service to work properly"

    def name
      raise METHOD_MUST_BE_IMPLEMENTED_MESSAGE
    end

    def required_credentials
      raise METHOD_MUST_BE_IMPLEMENTED_MESSAGE
    end

    def send_update(message="")
      raise METHOD_MUST_BE_IMPLEMENTED_MESSAGE
    end

    def setup()
      raise METHOD_MUST_BE_IMPLEMENTED_MESSAGE
    end

    def setup?
      raise METHOD_MUST_BE_IMPLEMENTED_MESSAGE
    end
  end
end
