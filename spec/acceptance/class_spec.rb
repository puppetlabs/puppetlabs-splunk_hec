
require 'spec_helper_acceptance'

describe 'Verify the minimum install' do
  before(:context) do
    run_shell("sudo puppet config set reports 'puppetdb, splunk_hec'")
  end

  describe 'with a basic test' do
    before(:each) do
      clear_testing_setup
    end

    it 'Sets up the pe-puppetserver service and splunk_hec class' do
      apply_manifest(setup_manifest, catch_failures: true)
    end

    it 'Successfully creates a report after a simple puppet apply' do
      host = return_host
      run_shell('puppet apply -e \' notify { "Hello World" : }\' --reports=splunk_hec')
      expect(run_shell("ls /opt/puppetlabs/puppet/cache/reports/#{host}").stdout).to match %r{\.json}
    end

    it 'Successfully sends data to an http endpoint' do
      run_shell('cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/orchestrator_metrics.json | puppet splunk_hec --sourcetype puppet:summary --saved_report')
    end

    it 'Fails when given a bad endpoint' do
      apply_manifest(setup_manifest(url: 'notanendpoint/nicetry'), catch_failures: true)
      cmd = 'cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/foo.json | puppet splunk_hec --sourcetype puppet:summary --saved_report'
      results = run_shell(cmd, expect_failures: true).to_s
      expect(results).to match %r{exit_code=1}
    end

    it 'Does not run report processor when disabled set to true' do
      host = return_host
      apply_manifest(setup_manifest(disabled: true), catch_failures: true)
      expect(File).not_to exist("/opt/puppetlabs/puppet/cache/reports/#{host}/*.json")
    end
  end
end
