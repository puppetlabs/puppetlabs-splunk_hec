require 'spec_helper_acceptance'

describe 'Event Forwarding' do
  is_pe = puppet_user == 'pe-puppet'
  let(:earliest) { Time.now.utc }

  describe 'With event forwarding enabled', if: is_pe do
    before(:all) do
      server_agent_run(setup_manifest(with_event_forwarding: true))
    end

    let(:report) do
      before_run = Time.now.utc
      puppetserver.run_shell("puppet task run facts --nodes #{host_name}")
      puppetserver.run_shell("#{EVENT_FORWARDING_CONFDIR}/collect_api_events.rb")
      after_run = Time.now.utc
      get_splunk_report(before_run, after_run, 'puppet:jobs')
    end

    it 'does not send report on first run' do
      puppetserver.run_shell('rm /etc/puppetlabs/pe_event_forwarding/pe_event_forwarding_indexes.yaml', expect_failures: true)
      count = report_count(report)
      expect(count).to be 0
    end

    it 'Successfully sends a job event to splunk' do
      # ensure the indexes.yaml file is created
      puppetserver.run_shell("#{EVENT_FORWARDING_CONFDIR}/collect_api_events.rb")

      count = report_count(report)
      expect(count).to be 1
    end

    it 'Sets event properties correctly' do
      data   = report[0]['result']
      event  = JSON.parse(data['_raw'])
      expect(data['source']).to                eql('http:splunk_hec_token')
      expect(data['sourcetype']).to            eql('puppet:jobs')
      expect(event['command']).to              eql('task')
      expect(event['options']['transport']).to eql('pxp')
    end
  end
end
