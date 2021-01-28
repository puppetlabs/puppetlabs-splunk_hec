
$LOAD_PATH.unshift "#{Dir.pwd}/spec/fixtures/modules/common_events_library/lib"

require 'spec_helper_acceptance'
require 'common_events_library'
require 'ostruct'
require 'support/acceptance/shared_context'
require 'support/acceptance/shared_examples'

describe 'Verify the minimum install' do
  context 'with a basic test' do
    it 'Sets up the pe-puppetserver service and splunk_hec class' do
      apply_manifest(default_manifest, catch_failures: true)
    end

    it 'Successfully creates a report after a simple puppet apply' do
      host = return_host
      run_shell('puppet apply -e \' notify { "Hello World" : }\' --reports=splunk_hec')
      expect(run_shell("ls /opt/puppetlabs/puppet/cache/reports/#{host}").stdout).to match %r{\.yaml}
    end

    it 'Successfully sends data to an http endpoint' do
      run_shell('cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/orchestrator_metrics.json | puppet splunk_hec --sourcetype puppet:summary --saved_report')
    end

    it 'Fails when missing required parameters' do
      expect { apply_manifest(missing_parameter_manifest, catch_failures: true) }.to raise_error(RuntimeError)
    end

    it 'Fails when given a bad endpoint' do
      apply_manifest(bad_endpoint_manfest, catch_failures: true)
      cmd = 'cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/foo.json | puppet splunk_hec --sourcetype puppet:summary --saved_report'
      results = run_shell(cmd, expect_failures: true).to_s
      expect(results).to match %r{exit_code=1}
    end
  end

  context 'Send events from PE using username/pass auth' do
    include_context 'event collection setup', :default_manifest

    include_examples 'configuration tests', :without_pe_token_key
    include_examples 'collect and push API results'
  end

  context 'Send events from PE using token authentication' do
    include_context 'event collection setup', :splunk_token_manifest

    include_examples 'configuration tests', :without_pe_password_key
    include_examples 'collect and push API results'
  end
end
