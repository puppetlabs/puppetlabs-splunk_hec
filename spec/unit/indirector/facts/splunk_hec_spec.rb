require 'spec_helper'
require 'puppet/node/facts'
require 'puppet/indirector/facts/splunk_hec'

describe Puppet::Node::Facts::Splunk_hec do
  let(:settings_hash) do
    {
      'url'             => 'https://splunk.example.com',
      'facts.allowlist' => ['os', 'networking'],
      'facts.blocklist' => nil,
    }
  end

  let(:incoming_facts) do
    {
      'os'         => { 'family' => 'RedHat', 'release' => { 'major' => '7' } },
      'networking' => { 'ip' => '10.0.0.1', 'mac' => 'AA:BB:CC:DD:EE:FF', 'interfaces' => { 'eth0' => { 'ip' => '10.0.0.1' } } },
      'secret'     => 'should not appear',
      'ipaddress'  => '10.0.0.1',
      'fqdn'       => 'node.example.com',
    }
  end

  let(:node_name) { 'node.example.com' }

  # Build a minimal facts indirector request double
  let(:request) do
    facts_obj = instance_double('Puppet::Node::Facts')
    allow(facts_obj).to receive(:name).and_return(node_name)
    allow(facts_obj).to receive(:values).and_return(incoming_facts)

    req = instance_double('Puppet::Indirector::Request')
    allow(req).to receive(:instance).and_return(facts_obj)
    allow(req).to receive(:key).and_return(node_name)
    allow(req).to receive(:node).and_return(node_name)
    allow(req).to receive(:options).and_return({ transaction_uuid: 'abc-123', environment: 'production' })
    allow(req).to receive(:environment).and_return('production')
    req
  end

  subject(:indirector) { described_class.new }

  before(:each) do
    allow(YAML).to receive(:load_file).with(%r{settings\.yaml}).and_return(settings_hash)
    allow(YAML).to receive(:load_file).with(%r{hec_secrets\.yaml}).and_return({ 'token' => 'test-token' })

    # Skip the yaml-cache super call
    allow_any_instance_of(Puppet::Node::Facts::Yaml).to receive(:save)

    # profile's arity check can fall through in newer Puppet versions, leaving the
    # block uncalled. Stub it to always yield so the save logic actually runs.
    allow(indirector).to receive(:profile).and_yield

    allow(indirector).to receive(:get_trusted_info).and_return({ 'authenticated' => 'remote' })
    allow(indirector).to receive(:submit_request)
    allow(indirector).to receive(:get_splunk_url).and_return('https://splunk.example.com/services/collector')

    # Surface any errors that would otherwise be silently swallowed by the rescue block
    allow(Puppet).to receive(:err) { |msg| raise msg }
    allow(Puppet).to receive(:info)
  end

  def submitted_event
    captured = nil
    allow(indirector).to receive(:submit_request) { |event| captured = event }
    indirector.save(request)
    captured
  end

  context 'allowlist filtering' do
    context 'with top-level fact names' do
      it 'includes allowlisted facts' do
        event = submitted_event
        expect(event['event']).to include('os', 'networking')
      end

      it 'excludes facts not in the allowlist' do
        event = submitted_event
        expect(event['event']).not_to have_key('secret')
      end

      it 'includes hardcoded facts regardless of allowlist' do
        event = submitted_event
        expect(event['event']).to include('ipaddress', 'fqdn')
      end
    end

    context 'with dotted-path entries' do
      let(:settings_hash) { super().merge('facts.allowlist' => ['networking.ip']) }

      it 'includes only the specified sub-key' do
        event = submitted_event
        expect(event['event']['networking']).to eq({ 'ip' => '10.0.0.1' })
      end

      it 'excludes unspecified sibling keys' do
        event = submitted_event
        expect(event['event']['networking']).not_to have_key('mac')
        expect(event['event']['networking']).not_to have_key('interfaces')
      end
    end

    context 'with multiple dotted-path entries under the same top-level key' do
      let(:settings_hash) { super().merge('facts.allowlist' => ['networking.ip', 'networking.mac']) }

      it 'merges both sub-keys under the shared top-level key' do
        event = submitted_event
        expect(event['event']['networking']).to eq({ 'ip' => '10.0.0.1', 'mac' => 'AA:BB:CC:DD:EE:FF' })
      end
    end

    context 'with a deeper dotted path' do
      let(:settings_hash) { super().merge('facts.allowlist' => ['networking.interfaces.eth0']) }

      it 'extracts the deeply nested value' do
        event = submitted_event
        expect(event['event']['networking']).to eq({ 'interfaces' => { 'eth0' => { 'ip' => '10.0.0.1' } } })
      end
    end

    context 'with a dotted path that does not exist in the facts' do
      let(:settings_hash) { super().merge('facts.allowlist' => ['networking.nonexistent']) }

      it 'omits the entry without raising an error' do
        event = submitted_event
        expect(event['event']).not_to have_key('networking')
      end
    end

    context 'with all.facts' do
      let(:settings_hash) { super().merge('facts.allowlist' => ['all.facts']) }

      it 'includes all facts' do
        event = submitted_event
        expect(event['event']).to include('os', 'networking', 'secret', 'ipaddress', 'fqdn')
      end
    end

    context 'with all.facts and a blocklist' do
      let(:settings_hash) { super().merge('facts.allowlist' => ['all.facts'], 'facts.blocklist' => ['secret']) }

      it 'excludes blocklisted facts' do
        event = submitted_event
        expect(event['event']).not_to have_key('secret')
      end

      it 'still includes non-blocklisted facts' do
        event = submitted_event
        expect(event['event']).to include('os', 'networking')
      end
    end
  end

  context 'event structure' do
    it 'sets the correct sourcetype' do
      event = submitted_event
      expect(event['sourcetype']).to eq('puppet:facts')
    end

    it 'sets the host to the node name' do
      event = submitted_event
      expect(event['host']).to eq(node_name)
    end

    it 'includes producer, environment, and transaction_uuid in the event payload' do
      event = submitted_event
      expect(event['event']).to include('producer', 'environment', 'transaction_uuid')
    end
  end
end
