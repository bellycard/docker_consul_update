class RegisterSelf
  attr_accessor :service_names

  def initialize(service_names: nil)
    self.service_names = service_names
  end

  def work
    service_names.each do |service_name|
      # de-register all services on this agent (in case there's a stale service)
      ConsulApi::Agent.service_deregister(service_name)

      # register this as a service on the consul agent
      service_hash =
        {
          'Name' => service_name,
          'Tags' => [

          ],
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
