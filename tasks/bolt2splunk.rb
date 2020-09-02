#!/opt/puppetlabs/bolt/bin/ruby

# This task sends generic data to a given Splunk sourcetype via the Splunk HEC collector.
# To keep the task generalized the only required parameters are the sourcetype and a json payload.
# The payload can be whatever you'd like to send to Splunk.
# Splunk HEC credentials can be specified via a Bolt inventory.

require 'yaml'
require 'json'
require 'net/https'

params = JSON.parse(STDIN.read)

def make_error(msg)
  error = {
    '_error' => {
      'kind' => 'execution error',
      'msg'  => msg,
      'details' => {},
    },
  }
  error
end

# Collect Splunk HEC credentials from Bolt inventory.
target        = params['_target']

splunk_server = target['hostname']
splunk_token  = target['token']
# 8088 is the default port for the Splunk HEC Collector
splunk_port   = target['port'] || '8088'

payload = params['payload']
# The Splunk sourcetype you want to send this info to.
# You'll use this to search for these events in Splunk like 'sourcetype="my source type"'
# If the specified sourcetype doesn't yet exist, Splunk will create it.
payload['sourcetype'] = params['sourcetype']

# Assemble request
request = Net::HTTP::Post.new("https://#{splunk_server}:#{splunk_port}/services/collector")
request.add_field('Authorization', "Splunk #{splunk_token}")
request.add_field('Content-Type', 'application/json')
request.body = payload.to_json

# Make request
client = Net::HTTP.new(splunk_server, splunk_port)
client.use_ssl = true
client.verify_mode = OpenSSL::SSL::VERIFY_NONE
client.request(request)
