# frozen_string_literal: true

require 'spec_helper'
require_relative '../../files/splunk_hec_collect_api_events.rb'

describe 'collect_api_events' do
  it 'correctly removes the protocol from pe_console' do
    expect(hostname_without_protocol('localhost')).to eq('localhost')
    expect(hostname_without_protocol('https://localhost')).to eq('localhost')
    expect(hostname_without_protocol('35.247.59.208')).to eq('35.247.59.208')
    expect(hostname_without_protocol('https://35.247.59.208')).to eq('35.247.59.208')
    expect(hostname_without_protocol('puppet-master.c.splunk-275519.internal')).to eq('puppet-master.c.splunk-275519.internal')
    expect(hostname_without_protocol('https://puppet-master.c.splunk-275519.internal')).to eq('puppet-master.c.splunk-275519.internal')
    expect(hostname_without_protocol('http://puppet-master.c.splunk-275519.internal')).to eq('puppet-master.c.splunk-275519.internal')
  end
end
