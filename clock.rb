require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
require './lib/register_self'
require './workers/report_self_to_health_check'
require './workers/update_consul'


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
    UpdateConsul.new(docker_host: docker_host, system_services: @system_services).work
  when 'report_self_to_health_check'
    ReportSelfToHealthCheck.new(service_names: @service_names).work
  end
end

def docker_host
  @docker_host ||= ENV['DOCKER_HOST']
  @docker_host ||= "http://#{`route -n | grep 'UG[ \t]' | awk '{print $2}'`.strip}:2375"
  @docker_host
end

def setup
  logger = LogStashLogger.new(type: :stdout)

  # no aws?  no problem.  Assume that this is development machine, and support builds and api
  @service_names = ['jockey-api-development', 'jockey-build-development', 'jockey-zone-none']
  @system_services = []
  begin
    # if you're using AWS, you can query the user data for what kind of deploys this can take
    conn = Faraday.new('http://169.254.169.254/')
    user_data = conn.get do |req|
      req.url '/latest/user-data'
      req.options[:timeout] = 10
    end
    aws_user_data = YAML.load(user_data.body)
    availability_zone = conn.get do |req|
      req.url '/lastest/meta-data/placement/availability-zone'
    end

    @service_names = [
      "jockey-#{aws_user_data['jockey']['stack']}-#{aws_user_data['jockey']['env']}",
      "jockey-zone-#{availability_zone.strip}"
    ]
    @system_services = aws_user_data['jockey']['system_images']
  rescue => e
    logger.warn 'unable to get aws data'
    logger.warn e.message
  end
  RegisterSelf.new(service_names: @service_names).work
end

setup

every(30.seconds, 'update_consul')
every(30.seconds, 'report_self_to_health_check')
