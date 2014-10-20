class ReportSelfToHealthCheck
  attr_accessor :service_names

  def initialize(service_names: nil)
    self.service_names = service_names
  end

  def work
    service_names.each do |service_name|
      begin
        check_id = "service:#{service_name}"
        ConsulApi::Agent.check_pass(check_id)
      rescue => e
        logger.warn e.message
      end
    end
  end
end
