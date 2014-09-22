require 'rubygems'
require 'clockwork'
require 'faraday'
require 'json'
require 'docker'
require 'active_support'
require 'consul_api'
require 'yaml'
require 'logstash-logger'

logger = logger = LogStashLogger.new(type: :stdout)
module Clockwork
  configure do |config|
    config[:logger] = LogStashLogger.new(type: :stdout)
  end
end

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
          logger.info(message: 'possible rogue container',
                      image: container.json['Config']['Image'],
                      id: container.id)
        end
      end
    rescue => e
      # rescue ALL exceptions, including things like syntax
      logger.warn e.message
    end
  when 'report_self_to_health_check'
    @service_names.each do |service_name|
      begin
        check_id = "service:#{service_name}"
        ConsulApi::Agent.check_pass(check_id)
      rescue => e
        logger.warn e.message
      end
    end
  end
end


def register_self
  @service_names.each do |service_name|
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

def docker_host
  @docker_host ||= ENV['DOCKER_HOST']
  @docker_host ||= "http://#{`route -n | grep 'UG[ \t]' | awk '{print $2}'`.strip}:2375"
  @docker_host
end

# no aws?  no problem.  Assume that this is development machine, and support builds and api
@service_names = ['jockey-api-development', 'jockey-build-development']
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
  logger.warn 'unable to get aws user data'
  logger.warn e.message
end

register_self

every(30.seconds, 'update_consul')
every(30.seconds, 'report_self_to_health_check')
