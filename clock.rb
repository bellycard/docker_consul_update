require 'rubygems'
require 'clockwork'
require 'faraday'
require 'json'
require 'docker'
require 'active_support'
require 'consul_api'

include Clockwork

# do all timing in memory
handler do |job|
  case job
  when 'update_consul'
    # this script will get all running containers, then tell consul that they're still alive
    begin
      containers = Docker::Container.all({}, Docker::Connection.new(docker_host, {}))
      known_agent_services = ConsulApi::Agent.services
      containers.each do |container|
        matched_service = known_agent_services.select { |kas| container.id == kas }
        if matched_service.present?
          ConsulApi::Agent.check_pass("service:#{container.id}")
        else
          puts 'possible rogue container ' + container.json['Config']['Image'] + ' ' + container.id
        end
      end
    rescue => e
      # rescue ALL exceptions, including things like syntax
      puts e.message
    end
  when 'report_self_to_health_check'
    begin
      check_id = "service:#{@service_id}"
      ConsulApi::Agent.check_pass(check_id)
    rescue => e
      puts e.message
    end
  end
end

def register_self
  # de-register all services on this agent (in case there's a stale service)
  ConsulApi::Agent.service_deregister(@service_id)

  # register this as a service on the consul agent
  service_hash =
    {
      'ID' => @service_id,
      'Name' => 'docker_consul_update',
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

def docker_host
  @docker_host ||= ENV['DOCKER_HOST']
  @docker_host ||= "http://#{`route -n | grep 'UG[ \t]' | awk '{print $2}'`.strip}:2375"
  @docker_host
end

# no aws?  no problem.  Everything will deployable here using the following service name
@service_id = 'jockey_consul_update'
begin
  # if you're using AWS, you can query the user data for what kind of deploys this can take
  conn = Faraday.new('http://169.254.169.254/latest/user-data', timeout: 10, open_timeout: 10)
  response = conn.get
  aws_user_data = response.body
  @service_id = "jockey-#{aws_user_data['jockey']['stack']}-#{aws_user_data['jockey']['env']}"
rescue
  puts 'unable to get aws user data'
end

register_self

every(30.seconds, 'update_consul')
every(30.seconds, 'report_self_to_health_check')
