#!/opt/puppetlabs/puppet/bin/ruby

require_relative './splunk_hec/util_splunk_hec'
require 'json'

data_path = ARGV[0]

data = JSON.parse(File.read(data_path))

data_to_send = ''

EVENT_SOURCETYPE = INDICES.select { |index| settings['event_types'].include? index }

EVENT_SOURCETYPE.each_key do |index|
  next unless data[index]
  data_to_send << extract_events(data[index], INDICES[index])
end

submit_request data_to_send
