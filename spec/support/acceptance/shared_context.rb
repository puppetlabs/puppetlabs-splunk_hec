RSpec.shared_context 'event collection setup' do |manifest_type|
  manifest = case manifest_type
             when :default_manifest
               default_manifest
             when :splunk_token_manifest
               splunk_token_manifest
             end

  before(:each) do
    master.apply_manifest(manifest, catch_failures: true)
  end
end

RSpec.shared_context 'send and collect events' do
  before(:each) do
    cmd = %(for i in {1..#{TASK_COUNT}}; do puppet task run enterprise_tasks::test_connect -n #{master.uri}; done)
    response = master.run_shell(cmd)
    raise 'task run failed' unless response.exit_code == 0
    master.run_shell(cron_command)
  end

  let(:jobs_starting_count) do
    # Get the number of available jobs minus the standard 4 extra that show up
    orchestrator_client.get_jobs(limit: 1).total - 4
  end

  let(:events) do
    cmd = %(docker exec splunk_enterprise_1 bash -c "sudo /opt/splunk/bin/splunk search 'sourcetype=\"puppet:jobs\"' -maxout #{TASK_COUNT} -auth admin:piepiepie")

    result = run_shell(cmd, expect_failures: true)
    events = result['stdout'].split("\n")
    events.map do |event|
      JSON.parse(event)
    end
  end
end
