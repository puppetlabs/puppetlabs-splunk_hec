require 'support/unit/reports/splunk_hec_spec_helpers'

describe 'Splunk_hec report processor: miscellaneous tests' do
  let(:processor) { new_processor }
  let(:settings_hash) { default_settings_hash }
  let(:expected_credentials) { default_credentials }
  let(:facts) { default_facts }
  let(:run_start_time) { Time.now }

  before(:each) do
    mock_settings_file(settings_hash)
    allow(processor).to receive(:facts).and_return(facts)
  end

  context 'metrics' do
    it 'sends the correct timestamp' do
      expect_sent_event do |event|
        expect(event['time']).to eql(epoch_time)
        expect(event['event']['time']).to eql(run_total_time)
      end
      processor.process
    end
  end

  context 'testing splunk_hec disabling feature' do
    before(:each) do
      allow(processor).to receive(:status).and_return('changed')
      mock_event_as_resource_status(processor, 'success', false)
    end

    context 'when disabled is set to true' do
      let(:settings_hash) { super().merge('disabled' => true) }

      it 'does not run report processor' do
        expect(processor).not_to receive(:submit_request)
        processor.process
      end
    end

    context 'when disabled is set to false' do
      let(:settings_hash) { super().merge('disabled' => false) }

      it 'does run report processor' do
        expect_sent_event(expected_credentials) do |actual_event|
          expect(actual_event['event']['status']).to eql('changed')
        end
        processor.process
      end
    end
  end

  context 'when fips is enabled' do
    let(:settings_hash) { super().merge('fips_enabled' => true) }

    it 'the correct function get called' do
      expect_requested_client(:fips)
      processor.process
    end
  end

  context 'when fips is not enabled' do
    let(:settings_hash) { super().merge('fips_enabled' => false) }

    it 'the correct function is called' do
      expect_requested_client(:non_fips)
      processor.process
    end
  end
end
