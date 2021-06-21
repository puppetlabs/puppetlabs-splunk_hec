
require 'spec_helper_acceptance'

describe 'Verify the minimum install' do
  let(:service_name) do
    @servicename ||= puppet_service_name
  end

  before(:context) do
    run_shell("puppet config set reports 'puppetdb, splunk_hec'")
  end

  describe 'with a basic test' do
    before(:each) do
      clear_testing_setup
    end

    it 'Sets up the pe-puppetserver service and splunk_hec class' do
      apply_manifest(setup_manifest(service_name), catch_failures: true)
    end

    it 'Successfully creates a report after a simple puppet apply' do
      run_shell('puppet agent -t')
      expect(run_shell("ls #{report_dir}").stdout).to match %r{\.json}
    end

    it 'Successfully sends data to an http endpoint' do
      run_shell('cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/orchestrator_metrics.json | puppet splunk_hec --sourcetype puppet:summary --saved_report')
    end

    it 'Fails when given a bad endpoint' do
      apply_manifest(setup_manifest(service_name, url: 'notanendpoint/nicetry'), catch_failures: true)
      cmd = 'cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/foo.json | puppet splunk_hec --sourcetype puppet:summary --saved_report'
      results = run_shell(cmd, expect_failures: true).to_s
      expect(results).to match %r{exit_code=1}
    end

    it 'Does not run report processor when disabled set to true' do
      apply_manifest(setup_manifest(service_name, disabled: true), catch_failures: true)
      expect(run_shell("ls #{report_dir}").stdout).not_to match %r{\.json}
    end
  end
end
