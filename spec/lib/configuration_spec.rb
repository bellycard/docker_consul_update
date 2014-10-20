require 'spec_helper'

describe Configuration do
  def user_data
    Hashie::Mash.new(body: File.read('./spec/fixtures/user-data.yml'))
  end

  def availability_zone
    Hashie::Mash.new(body: File.read('./spec/fixtures/availability_zone'))
  end

  describe '#initialize' do
    it 'reads from AWS for cloud config' do
      allow_any_instance_of(Faraday::Connection).to receive(:get) { user_data }
      config = Configuration.new
      expect(config.service_names).to include('jockey-build-production')
    end

    it 'reads from AWS for AZ information' do
      allow_any_instance_of(Faraday::Connection).to receive(:get) { availability_zone }
      # stub out the yaml processing
      allow(YAML).to receive(:load) { Hashie::Mash.new(jockey: { stack: :foo, env: :bar }) }
      config = Configuration.new
      expect(config.service_names).to include('jockey-zone-us-east-1b')
    end

    it 'sets services to development if AWS is not reachable' do
      config = Configuration.new
      expect(config.service_names).to include('jockey-api-development')
      expect(config.service_names).to include('jockey-zone-none')
    end
  end
end
