
require 'spec_helper_acceptance'

describe 'Verify the minimum install' do
  describe 'with a basic test' do
    # The following manifest first ensures pe-puppetserver is running, which is a requirement for this module.
    cleanmanifest = <<-MANIFEST
    # cloned from https://github.com/puppetlabs/puppetlabs-puppet_enterprise/blob/a82d3adafcf1dfd13f1c338032f325d80fa58eda/manifests/trapperkeeper/pe_service.pp#L10-L17
    service { 'pe-puppetserver':
      ensure     => running,
      hasrestart => true,
      restart    => "service pe-puppetserver reload",
    }

    class { 'splunk_hec':
      url                    => 'http://localhost:8088/services/collector/event',
      token                  => 'abcd1234',
      record_event           => true,
      pe_console             => 'localhost',
    }
    MANIFEST

    it 'Sets up the pe-puppetserver service and splunk_hec class' do
      apply_manifest(cleanmanifest, catch_failures: true)
    end

    it 'Successfully creates a report after a simple puppet apply' do
      host = return_host
      run_shell('puppet apply -e \' notify { "Hello World" : }\' --reports=splunk_hec')
      expect(run_shell("ls /opt/puppetlabs/puppet/cache/reports/#{host}").stdout).to match %r{\.yaml}
    end

    it 'Successfully sends data to an http endpoint' do
      run_shell('cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/orchestrator_metrics.json | puppet splunk_hec --sourcetype puppet:summary --saved_report')
    end

    it 'Fails when given a bad endpoint' do
      failmanifest = <<-MANIFEST
        service { 'pe-puppetserver':
          ensure     => running,
          hasrestart => true,
          restart    => "service pe-puppetserver reload",
        }
        class { 'splunk_hec':
          url                    => 'notanendpoint/nicetry',
          token                  => '',
          record_event           => true,
          pe_console             => 'localhost',
        }
        MANIFEST
      apply_manifest(failmanifest, catch_failures: true)
      cmd = 'cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/foo.json | puppet splunk_hec --sourcetype puppet:summary --saved_report'
      results = run_shell(cmd, expect_failures: true).to_s
      expect(results).to match %r{exit_code=1}
    end
  end
end
