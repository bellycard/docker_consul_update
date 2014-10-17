class UpdateConsul
  attr_accessor :docker_host, :system_services

  def initialize(docker_host: nil, system_services: nil)
    self.docker_host = docker_host
    self.system_services = system_services
  end

  def work
    logger = LogStashLogger.new(type: :stdout)
    # this script will get all running containers, then tell consul that they're still alive
    containers = Docker::Container.all({}, Docker::Connection.new(docker_host, {}))
    known_agent_services = ConsulApi::Agent.services
    containers.each do |container|
      matched_service = known_agent_services.select { |kas| container.id == kas }
      if matched_service.present?
        ConsulApi::Agent.check_pass("service:#{container.id}")
      elsif system_services.include?(container.json['Config']['Image'])
        # found a system service dictated by our user-data.  Ignore
      else
        logger.info(message: 'possible rogue container',
                    image: container.json['Config']['Image'],
                    id: container.id)
      end
    end
  rescue => e
    puts e
    puts e.backtrace
    # rescue ALL exceptions, including things like syntax
    logger.warn e.message
  end
end
