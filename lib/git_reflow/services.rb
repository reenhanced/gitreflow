module GitReflow
  module Services

    @@services = []

    def self.add_service(service)
      @@services << service
    end

    def self.supported_services
      @@services
    end
  end
end
