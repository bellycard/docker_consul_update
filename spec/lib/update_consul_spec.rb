require 'spec_helper'
require 'docker'

describe UpdateConsul do

  def all_services
    JSON.parse('
      {
        "123": {
          "ID": "123",
          "Service": "abc",
          "Tags": null,
          "Port": 0
        },
        "jockey_consul_update": {
          "ID": "jockey_consul_update",
          "Service": "docker_consul_update",
          "Tags": [],
          "Port": 0
        }
      }'
    )
  end

  def docker_containers
    [
      Hashie::Mash.new(id: '123',
                       connection: { url: 'tcp://localhost', options: { port: 2375 } },
                       json: { 'Config' => { 'Image' => 'x' } }),
      Hashie::Mash.new(id: '456',
                       connection: { url: 'tcp://localhost', options: { port: 2375 } },
                       json: { 'Config' => { 'Image' => 'x' } })
    ]
  end

  describe '#work' do
    before do
      @update_consul = UpdateConsul.new(docker_host: 'foobar', system_services: [])
      allow(Docker::Container).to receive(:all) { docker_containers }
      allow(ConsulApi::Agent).to receive(:services) { all_services }
    end

    it 'issues a health check pass for all services on the consul node' do
      expect(ConsulApi::Agent).to receive(:check_pass) do |check_id|
        expect(check_id).to eq('service:123')
      end
      @update_consul.work
    end

    it 'logs when an unknown container is detected' do
      expect(ConsulApi::Agent).to receive(:check_pass)
      expect_any_instance_of(Logger).to receive(:info) do |message|
        expect(message[:message]).to eq('possible rogue container')
        expect(message[:id]).to eq('456')
      end
      @update_consul.work
    end
  end
end
