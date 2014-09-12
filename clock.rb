require 'rubygems'
require 'clockwork'
require 'faraday'
require 'json'
require 'docker'
require 'active_support'

include Clockwork

 # do all timing in memory
handler do |job|
  case job
  when 'update_consul'
    # this script will get all running containers, then tell consul that they're still alive
    begin
      eval(@update_consul_script) if @update_consul_script
    rescue Exception => e
      # rescue ALL exceptions, including things like syntax
      puts e.message
    end
  when 'update_self'
    begin
      response = Faraday.get(ENV['REMOTE_SCRIPT_URL'])
      response_hash = JSON.parse(response.body)
      @update_consul_script = response_hash['data']['command']
      puts @update_consul_script
    rescue => e
      puts e.message
      puts 'remote url is not responding with happy thoughts'
    end
  end
end

puts "remove script URL: #{ENV['REMOTE_SCRIPT_URL']}"
every(1.hour, 'update_self')
every(30.seconds, 'update_consul')
