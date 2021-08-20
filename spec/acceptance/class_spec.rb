
require 'spec_helper_acceptance'

describe 'Verify the minimum install' do
  let(:earliest) { Time.now.utc }

  before(:all) do
    server_agent_run(setup_manifest)
  end

  describe 'with a basic test' do
    it 'Successfully sends a report to splunk' do
      before_run = earliest
      trigger_puppet_run(puppetserver)
      after_run = Time.now.utc
      report_count = get_splunk_report_count(before_run, after_run)
      expect(report_count).to be 1
    end

    it 'Successfully sends data to an http endpoint' do
      run_shell('cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/orchestrator_metrics.json | puppet splunk_hec --sourcetype puppet:summary --saved_report')
    end

    it 'Fails when given a bad endpoint' do
      server_agent_run(setup_manifest(url: 'notanendpoint/nicetry'))
      cmd = 'cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/foo.json | puppet splunk_hec --sourcetype puppet:summary --saved_report'
      results = puppetserver.run_shell(cmd, expect_failures: true).to_s
      expect(results).to match %r{exit_code=1}
    end

    it 'Does not run report processor when disabled set to true' do
      before_run = earliest
      server_agent_run(setup_manifest(disabled: true))
      after_run = Time.now.utc
      expect(get_splunk_report_count(before_run, after_run)).to be 0
    end
  end
end
