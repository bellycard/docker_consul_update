class UpdateConsul
  attr_accessor :docker_host, :system_services, :kill_rogues

  def initialize(docker_host: nil, system_services: nil, kill_rogues: nil)
    self.docker_host = docker_host
    self.system_services = system_services
    self.kill_rogues = kill_rogues
  end

  def work
    logger = LogStashLogger.new(type: :stdout)
    # this script will get all running containers, then tell consul that they're still alive
    containers = Docker::Container.all
    known_agent_services = ConsulApi::Agent.services
    containers.each do |container|
      matched_service = known_agent_services.select { |kas| container.id == kas }
      if matched_service.present?
        ConsulApi::Agent.check_pass("service:#{container.id}")
      elsif system_services.include?(container.json['Config']['Image'])
        # found a system service dictated by our user-data.  Ignore
      else

        if kill_rogues
          logger.info(message: 'possible rogue container. killing it softly.',
                    image: container.json['Config']['Image'],
                    id: container.id)
          container.kill
        else
          logger.info(message: 'possible rogue container',
                    image: container.json['Config']['Image'],
                    id: container.id)
        end
      end
    end
  rescue => e
    # rescue ALL exceptions, including things like syntax
    logger.warn e.message
  end
end
