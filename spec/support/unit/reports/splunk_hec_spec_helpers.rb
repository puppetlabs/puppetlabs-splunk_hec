require 'json'
require 'spec_helper'
require 'puppet/reports'

def new_processor
  processor = Puppet::Transaction::Report.new('apply')
  processor.extend(Puppet::Reports.report(:splunk_hec))

  allow(processor).to receive(:host).and_return 'host'
  allow(processor).to receive(:environment).and_return 'production'
  allow(processor).to receive(:job_id).and_return '1'
  allow(processor).to receive(:time).and_return(run_start_time)
  allow(processor).to receive(:metrics).and_return(metrics_hash)
  # The report processor logs all exceptions to Puppet.err. Thus, we mock it out
  # so that we can see them (and avoid false-positives).
  allow(Puppet).to receive(:err) do |msg|
    raise msg
  end
  processor
end

def metrics_hash
  {
    'time'      => { 'total' => 5 },
    'resources' => { 'total' => 0 },
    'changes'   => { 'total' => 0 },
  }
end

def run_total_time
  (run_start_time + metrics_hash['time']['total']).iso8601(3)
end

def epoch_time
  '%10.3f' % Time.parse(run_total_time).to_f
end

def default_credentials
  {
    user: 'test_user',
    password: 'test_password',
  }
end

def default_settings_hash
  {
    'url'                  => 'splunk_testing.com',
    'token'                => 'test_token',
    'collect_facts'        => ['dmi', 'disks', 'partitions', 'processors', 'networking'],
    'enable_reports'       => true,
    'record_event'         => true,
    'disabled'             => false,
    'managed_routes'       => true,
    'facts_terminus'       => 'puppetdb',
    'facts_cache_terminus' => 'splunk_hec',
  }
end

def mock_settings_file(settings_hash)
  allow(YAML).to receive(:load_file).with(%r{(.*)(settings|hec_secrets).yaml}).and_return(settings_hash)
end

def new_mock_response(status, body)
  response = instance_double('mock HTTP response')
  allow(response).to receive(:code).and_return(status.to_s)
  allow(response).to receive(:body).and_return(body)
  response
end

def new_mock_event(event_fields = {})
  event_fields[:property] = 'message'
  event_fields[:message]  = 'defined \'message\' as \'hello\''
  Puppet::Transaction::Event.new(property: event_fields[:property], message: event_fields[:message], status: event_fields[:event_status], corrective_change: event_fields[:event_corrective_change])
end

def new_mock_resource_status(events, status_changed, status_failed)
  status = instance_double('resource status')
  allow(status).to receive(:events).and_return(events)
  allow(status).to receive(:out_of_sync).and_return(status_changed)
  allow(status).to receive(:failed).and_return(status_failed)
  allow(status).to receive(:containment_path).and_return(['foo', 'bar'])
  allow(status).to receive(:file).and_return('site.pp')
  allow(status).to receive(:line).and_return(1)
  allow(status).to receive(:resource).and_return('resource')
  allow(status).to receive(:resource_type).and_return('resource_type')
  allow(status).to receive(:corrective_change).and_return(true)
  allow(status).to receive(:intentional_change).and_return(false)
  status
end

def mock_events(processor, *events)
  allow(processor).to receive(:resource_statuses).and_return('mock_resource' => new_mock_resource_status(events, true, false))
end

def mock_event_as_resource_status(processor, event_status, event_corrective_change, status_changed = true, status_failed = false)
  mock_events = [new_mock_event(status: event_status, corrective_change: event_corrective_change)]
  mock_resource_status = new_mock_resource_status(mock_events, status_changed, status_failed)
  allow(processor).to receive(:resource_statuses).and_return('mock_resource' => mock_resource_status)
end

def expect_sent_event(_expected_credentials = {})
  #  will only be called to send an event
  expect(processor).to receive(:submit_request) do |request_body|
    yield request_body
    new_mock_response(200, '')
  end
end

def expect_requested_client(client)
  case client
  when :non_fips
    expect(processor).to receive(:send_with_nonfips).and_return(new_mock_response(200, ''))
    expect(processor).not_to receive(:send_with_fips)
  when :fips
    expect(processor).to receive(:send_with_fips).and_return(new_mock_response(200, ''))
    expect(processor).not_to receive(:send_with_nonfips)
  end
end

def default_facts
  {
    'host'       => 'foo.splunk.c.internal',
    'time'       => 'epoch',
    'sourcetype' => 'puppet:summary',
    'event'      => {
      'cached_catalog_status' =>  'not_used',
      'catalog_uuid'          => '12345asdf',
      'certname'              => 'foo.splunk.internal',
      'code_id'               => 'null',
      'configuration_version' => '123456789',
      'corrective_change'     => 'false',
      'environment'           => 'production',
      'job_id'                => 'null',
      'metrics'               => metrics_hash,
      'noop'                  => 'false',
      'noop_pending'          => 'false',
      'pe_console'            => 'https://localhost',
      'producer'              => 'foo.splunk-1234.c.internal',
      'puppet_version'        => '6.22.1',
      'report_format'         => '11',
      'status'                => 'changed',
      'time'                  => '2021-06-07T20:10:42.696Z',
      'transaction_uuid'      => 'a1s2d3f4g56',
    },
  }
end
