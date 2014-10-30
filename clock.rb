require 'rubygems'
require 'bundler/setup'
Bundler.require(:default)
require './lib/register_self'
require './lib/report_self_to_health_check'
require './lib/update_consul'
require './lib/configuration'

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
    UpdateConsul.new(docker_host: @config.docker_host, system_services: @config.system_services).work
  when 'report_self_to_health_check'
    ReportSelfToHealthCheck.new(service_names: @config.service_names).work
  end
end

@config = Configuration.new
RegisterSelf.new(service_names: @config.service_names, availability_zone: @config.availability_zone).work

every(30.seconds, 'update_consul')
every(30.seconds, 'report_self_to_health_check')
