RSpec.shared_examples 'configuration tests' do |without_key|
  key_name = case without_key
             when :without_pe_password_key
               'pe_password'
             when :without_pe_token_key
               'pe_token'
             end

  it "does not have a #{key_name} setting in the config file" do
    expect(splunk_hec_config.key?(key_name)).to be false
  end
end

RSpec.shared_examples 'collect and push API results' do
  context 'Create and send the events' do
    include_context 'send and collect events'
    it 'collects the api results and pushes correctly to splunk' do
      job_id = jobs_starting_count
      events.each do |event|
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
