$LOAD_PATH.unshift "#{Dir.pwd}/spec/fixtures/modules/common_events_library/lib"

require 'spec_helper_acceptance'
require 'common_events_library'
require 'ostruct'

describe 'Verify the minimum install' do
  describe 'with a basic test' do
    it 'Sets up the pe-puppetserver service and splunk_hec class' do
      apply_manifest(standard_manifest, catch_failures: true)
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
      failmanifest = <<-MANIFEST
        service { 'pe-puppetserver':
          ensure     => running,
          hasrestart => true,
          restart    => "service pe-puppetserver reload",
        }
        class { 'splunk_hec':
          url => 'notanendpoint/nicetry',
          token => '',
          record_event => true,
          include_api_collection = true,
        }
        MANIFEST
      expect { apply_manifest(failmanifest, catch_failures: true) }.to raise_error(RuntimeError)
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
          pe_username            => 'admin',
          pe_console             => 'localhost',
          pe_password            => Sensitive('pie'),
          include_api_collection => true,
        }
        MANIFEST
      apply_manifest(failmanifest, catch_failures: true)
      cmd = 'cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/foo.json | puppet splunk_hec --sourcetype puppet:summary --saved_report'
      results = run_shell(cmd, expect_failures: true).to_s
      expect(results).to match %r{exit_code=1}
    end
  end

  describe 'Collect events from PE and sends to the splunk endpoint' do
    before(:all) do
      apply_manifest(standard_manifest, catch_failures: true)
      5.times do
        response = master.run_shell("puppet task run enterprise_tasks::test_connect -n #{master.uri}")
        raise 'task run failed' unless response.exit_code == 0
      end
      # 'Waiting for the cron job to complete'
      sleep(130)
    end

    it 'collects the api results and pushes correctly to splunk' do
      # Get the total jobs
      orchestrator = Orchestrator.new(master.uri.to_s, username: 'admin', password: 'pie', ssl_verify: false)
      jobs = orchestrator.get_jobs(limit: 1)

      # Do a splunk search for the orchestrator sourcetype for the last 5 minutes
      cmd = 'docker exec splunk_enterprise_1 bash -c \'sudo /opt/splunk/bin/splunk search sourcetype="puppet:events_summary" -earliest_time -5m -latest_time now -auth admin:piepiepie\''

      result = run_shell(cmd, expect_failures: true)
      events = result['stdout'].split("\n")

      job_id = jobs.total - 4
      expect(events.size).to equal(5)
      events.each do |event_str|
        event = JSON.parse(event_str)
        expect(event['options']['task']).to eq('enterprise_tasks::test_connect')
        expect(event['options']['environment']).to eq('production')
        expect(event['command']).to eq('task')
        expect(event['name'].to_i).to eq(job_id)
        expect(event['report']['id']).to match %r{/orchestrator/v1/jobs/}
        job_id += 1
      end
    end
  end
end
