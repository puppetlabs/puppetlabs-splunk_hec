require 'spec_helper_acceptance'
require 'common_events_library'


describe 'Verify the minimum install' do
  # describe 'with a basic test' do
  #   # The following manifest first ensures pe-puppetserver is running, which is a requirement for this module.
  #   cleanmanifest = <<-MANIFEST
  #   # cloned from https://github.com/puppetlabs/puppetlabs-puppet_enterprise/blob/a82d3adafcf1dfd13f1c338032f325d80fa58eda/manifests/trapperkeeper/pe_service.pp#L10-L17
  #   service { 'pe-puppetserver':
  #     ensure     => running,
  #     hasrestart => true,
  #     restart    => "service pe-puppetserver reload",
  #   }

  #   class { 'splunk_hec':
  #     url                    => 'http://localhost:8088/services/collector/event',
  #     token                  => 'abcd1234',
  #     record_event           => true,
  #     pe_username            => 'admin',
  #     pe_console             => 'localhost',
  #     pe_password            => Sensitive('pie'),
  #     include_api_collection => true,
  #   }
  #   MANIFEST

  #   it 'Sets up the pe-puppetserver service and splunk_hec class' do
  #     apply_manifest(cleanmanifest, catch_failures: true)
  #   end

  #   it 'Successfully creates a report after a simple puppet apply' do
  #     host = return_host
  #     run_shell('puppet apply -e \' notify { "Hello World" : }\' --reports=splunk_hec')
  #     expect(run_shell("ls /opt/puppetlabs/puppet/cache/reports/#{host}").stdout).to match %r{\.yaml}
  #   end

  #   it 'Successfully sends data to an http endpoint' do
  #     run_shell('cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/orchestrator_metrics.json | puppet splunk_hec --sourcetype puppet:summary --saved_report')
  #   end

  #   it 'Fails when missing required parameters' do
  #     failmanifest = <<-MANIFEST
  #       service { 'pe-puppetserver':
  #         ensure     => running,
  #         hasrestart => true,
  #         restart    => "service pe-puppetserver reload",
  #       }
  #       class { 'splunk_hec':
  #         url => 'notanendpoint/nicetry',
  #         token => '',
  #         record_event => true,
  #       }
  #       MANIFEST
  #     expect { apply_manifest(failmanifest, catch_failures: true) }.to raise_error(RuntimeError)
  #   end

  #   it 'Fails when given a bad endpoint' do
  #     failmanifest = <<-MANIFEST
  #       service { 'pe-puppetserver':
  #         ensure     => running,
  #         hasrestart => true,
  #         restart    => "service pe-puppetserver reload",
  #       }
  #       class { 'splunk_hec':
  #         url                    => 'notanendpoint/nicetry',
  #         token                  => '',
  #         record_event           => true,
  #         pe_username            => 'admin',
  #         pe_console             => 'localhost',
  #         pe_password            => Sensitive('pie'),
  #         include_api_collection => true,
  #       }
  #       MANIFEST
  #     apply_manifest(failmanifest, catch_failures: true)
  #     cmd = 'cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/foo.json | puppet splunk_hec --sourcetype puppet:summary --saved_report'
  #     results = run_shell(cmd, expect_failures: true).to_s
  #     expect(results).to match %r{exit_code=1}
  #   end
  # end

  it 'tests cool stuff' do
    splunk_client = CommonEventsHttp.new(
      "http://#{master.uri.to_s}",
      port: 8089,
      ssl_verify: false,
    )

    require 'pry';binding.pry

    response = splunk_client.get_request('services/search/jobs', { Authorization: 'Splunk abcd1234' })


    puts response
  end

  # it 'Collect events from PE and sends to the splunk endpoint' do
  #   manifest = <<-MANIFEST
  #     service { 'pe-puppetserver':
  #       ensure     => running,
  #       hasrestart => true,
  #       restart    => "service pe-puppetserver reload",
  #     }
  #     class { 'splunk_hec':
  #       url => "#{master.uri}:8088/services/collector/event",
  #       pe_console => master.uri.to_s,
  #       token => "abcd1234",
  #       pe_username => "admin",
  #       pe_password => Sensitive('pie'),
  #       enable_reports => true,
  #       manage_routes => true,
  #       include_api_collection => true,
  #     }
  #     MANIFEST
  #   apply_manifest(manifest, catch_failures: true)

  #   orchestrator = Orchestrator.new(master.uri.to_s, 'admin', 'pie', ssl_verify: false)

  #   r = 1..5
  #   puts 'Sending batch tasks to PE'
  #   r.each do |x|
  #     puts "Injecting task [#{x}]"
  #     response = orchestrator.run_facts_task([master.uri.to_s])
  #     expect(response.code.to_i).to equal(202)
  #   end

    

  #   require 'pry';binding.pry

  #   # cmd = 'cat /etc/puppetlabs/code/environments/production/modules/splunk_hec/examples/foo.json | puppet splunk_hec --sourcetype puppet:summary --saved_report'
  #   # results = run_shell(cmd, expect_failures: true).to_s
  #   # expect(results).to match %r{exit_code=1}
  # end
end
