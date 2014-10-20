require 'spec_helper'

describe ReportSelfToHealthCheck do
  describe '#work' do
    before do
      @report_self_to_health_check = ReportSelfToHealthCheck.new(service_names: ['jockey-api-development'])
    end

    it 'passes a health check for all services' do
      expect(ConsulApi::Agent).to receive(:check_pass) do |check_id|
        expect(check_id).to eq('service:jockey-api-development')
      end
      @report_self_to_health_check.work
    end
  end
end
