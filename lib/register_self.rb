class RegisterSelf
  attr_accessor :service_names, :availability_zone

  def initialize(service_names: nil, availability_zone: nil)
    self.service_names = service_names
    self.availability_zone = availability_zone
  end

  def work
    service_names.each do |service_name|
      # de-register all services on this agent (in case there's a stale service)
      ConsulApi::Agent.service_deregister(service_name)

      # register this as a service on the consul agent
      service_hash =
        {
          'Name' => service_name,
          'Tags' => [ "az-#{availability_zone }" ],
          'Port' => nil,
          'Check' => {
            # name of this check is "service:<ServiceId>".
            'TTL' => '60s'
          }
        }
      ConsulApi::Agent.service_register(service_hash)
    end
  end
end
