require 'spec_helper'
require './lib/register_self'

describe RegisterSelf do
  describe '#work' do
    before do
      @register_self = RegisterSelf.new(service_names: ['jockey-api-development'])
    end

    it 'calls ConsulApi to register services in service_names' do
      allow(ConsulApi::Agent).to receive(:service_deregister)
      expect(ConsulApi::Agent).to receive(:service_register) do |service_hash|
        expect(service_hash['Name']).to eq('jockey-api-development')
      end
      @register_self.work
    end

    it 'deregisters the service before registering it' do
      allow(ConsulApi::Agent).to receive(:service_register)
      expect(ConsulApi::Agent).to receive(:service_deregister) do |service_name|
        expect(service_name).to eq('jockey-api-development')
      end
      @register_self.work
    end
  end

end
