RSpec.shared_examples 'collects and pushed API results' do |without_key|
  key_name = case without_key
             when :without_pe_password_key
               'pe_password'
             when :without_pe_token_key
               'pe_token'
             end

  it "does not have a #{key_name} setting in the config file" do
    expect(splunk_hec_config.key?(key_name)).to be false
  end

  it 'collects the api results and pushes correctly to splunk' do
    # Get the total jobs
    jobs = orchestrator_client.get_jobs(limit: 1)

    # Do a splunk search for the orchestrator sourcetype for the last 5 minutes
    cmd = %(docker exec splunk_enterprise_1 bash -c "sudo /opt/splunk/bin/splunk search 'sourcetype=\"puppet:jobs\" earliest=\"#{delay}\"' -auth admin:piepiepie")

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
