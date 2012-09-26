# credit: interfacing thanks to http://metabates.com/2011/02/07/building-interfaces-and-abstract-classes-in-ruby/
module GitReflow
  extend self

  class Service
    def initialize
      @services = []
    end

    def required_credentials
      {}
    end
  end

  def supported_services
  end
end
