ENV['RACK_ENV'] = 'test'
require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, :test)
require 'simplecov'

SimpleCov.start

# require our files so that simplecov knows about them
Dir['./lib/**/*.rb'].each { |f| require f }

SimpleCov.start do
  add_filter "/spec\/.*/"
end

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir['./spec/support/**/*.rb'].each { |f| require f }

RSpec.configure do |_config|

end
