#!/opt/puppetlabs/puppet/bin/ruby

require_relative './splunk_hec/util_splunk_hec'
require 'json'

data_path = ARGV[0]

data = JSON.parse(File.read(data_path))

data_to_send = ''

EVENT_SOURCETYPE = INDICES.select { |index| settings['event_types'].include? index }

EVENT_SOURCETYPE.each_key do |index|
  # A nil value indicates that there were no new events.
  # A negative value indicates that the sourcetype has been disabled from the pe_event_forwarding module.
  next if data[index].nil? || data[index] == -1
  data_to_send << extract_events(data[index], INDICES[index], settings["#{index}_data_filter"])
end

submit_request data_to_send
