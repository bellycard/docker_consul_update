require 'yaml'
class Configuration
  attr_accessor :service_names, :system_services, :availability_zone

  def initialize
    logger = LogStashLogger.new(type: :stdout)

    # no aws?  no problem.  Assume that this is development machine, and support builds and api
    self.service_names = ['jockey-api-development', 'jockey-build-development']
    self.system_services = []
    begin
      # if you're using AWS, you can query the user data for what kind of deploys this can take
      conn = Faraday.new('http://169.254.169.254')
      user_data = conn.get do |req|
        req.url '/latest/user-data'
        req.options[:timeout] = 10
      end
      aws_user_data = YAML.load(user_data.body)
      availability_zone_response = conn.get do |req|
        req.url '/latest/meta-data/placement/availability-zone'
      end

      self.service_names = ["jockey-#{aws_user_data['jockey']['stack']}-#{aws_user_data['jockey']['env']}"]
      self.system_services = aws_user_data['jockey']['system_images']
      self.availability_zone = availability_zone_response.body.strip
    rescue => e
      logger.warn 'unable to get aws data'
      logger.warn e.message
    end
  end

  def docker_host
    @docker_host ||= ENV['DOCKER_HOST']
    @docker_host ||= "http://#{`route -n | grep 'UG[ \t]' | awk '{print $2}'`.strip}:2375"
    @docker_host
  end
end
