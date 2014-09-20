require 'rubygems'
require 'clockwork'
require 'faraday'
require 'json'
require 'docker'
require 'active_support'
require 'consul_api'
require 'yaml'

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
        elsif @system_services.include?(container.json['Config']['Image'])
          # found a system service dictated by our user-data.  Ignore
        else
          puts 'possible rogue container ' + container.json['Config']['Image'] + ' ' + container.id
        end
      end
    rescue => e
      # rescue ALL exceptions, including things like syntax
      puts e.message
    end
  when 'report_self_to_health_check'
    @service_ids.each do |service_id|
      begin
        check_id = "service:#{service_id}"
        ConsulApi::Agent.check_pass(check_id)
      rescue => e
        puts e.message
      end
    end
  end
end


def register_self
  @service_names.each_with_index do |service_name, index|
    # de-register all services on this agent (in case there's a stale service)
    ConsulApi::Agent.service_deregister(@service_ids[index])

    # register this as a service on the consul agent
    service_hash =
      {
        'Name' => service_name,
        'ID' => @service_ids[index],
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

def docker_host
  @docker_host ||= ENV['DOCKER_HOST']
  @docker_host ||= "http://#{`route -n | grep 'UG[ \t]' | awk '{print $2}'`.strip}:2375"
  @docker_host
end

# no aws?  no problem.  Assume that this is development machine, and support builds and api
@service_names = ['jockey-api-development', 'jockey-build-development']
@service_ids = []
@system_services = []
begin
  # if you're using AWS, you can query the user data for what kind of deploys this can take
  conn = Faraday.new('http://169.254.169.254/latest/user-data')
  response = conn.get do |req|
    req.options[:timeout] = 10
  end
  aws_user_data = YAML.load(response.body)
  @service_names = ["jockey-#{aws_user_data['jockey']['stack']}-#{aws_user_data['jockey']['env']}"]
  @system_services = aws_user_data['jockey']['system_images']
rescue => e
  puts 'unable to get aws user data'
  puts e.message
end

@service_names.each do |service|
  @service_ids << SecureRandom.uuid
end

register_self

every(30.seconds, 'update_consul')
every(30.seconds, 'report_self_to_health_check')
