RSpec.shared_context 'event collection setup' do |manifest_type|
  manifest = case manifest_type
             when :default_manifest
               default_manifest
             when :splunk_token_manifest
               splunk_token_manifest
             end

  before(:all) do
    master.apply_manifest(manifest, catch_failures: true)
    5.times do
      response = master.run_shell("puppet task run enterprise_tasks::test_connect -n #{master.uri}")
      raise 'task run failed' unless response.exit_code == 0
    end
    # 'Waiting for the cron job to complete'
    @time_stamp ||= Time.now
    master.run_shell(cron_command)
  end

  after(:all) do
    @time_stamp = nil
  end

  let(:delay) do
    Time.at(@time_stamp.to_i).utc.strftime('%m/%d/%Y:%H:%M:%S')
  end
end
