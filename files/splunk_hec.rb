#!/opt/puppetlabs/puppet/bin/ruby

require_relative './splunk_hec/util_splunk_hec'
require 'json'

data_path = ARGV[0]

# data_path = '/tmp/splunk_hec'

data = JSON.parse(File.read(data_path))

data_to_send = ''

INDICES.each_key do |index|
  next unless data[index]
  data_to_send << case index
                  when 'orchestrator'
                    extract_jobs(data[index])
                  else
                    extract_commits(data[index]['commits'], INDICES[index])
                  end
end

submit_request data_to_send
