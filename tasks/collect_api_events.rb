require 'common_events_library'
require 'benchmark'
require 'json'
require 'net/https'
require 'time'

params = JSON.parse(STDIN.read)

pe_console = params['pe_console']
pe_username = params['pe_username'] || 'admin'
pe_password = params['pe_password'] || 'pie'
splunk_server = params['splunk_server'] || 'localhost'
splunk_token  = params['splunk_token'] || 'abcd1234'
splunk_port = params['splunk_port'] || '8088'

def transform(body, pe_console, source_type, splunk_client, splunk_token)
  events_json = ''
  body.each do |pe_event|
    timestamp = Time.new
    event = {
      'host' => pe_console,
      'time' => timestamp.to_i,
      'sourcetype' => source_type,
      'event' => pe_event,
    }
    splunk_client.post_request('/services/collector', event, {'Authorization': "Splunk #{splunk_token}"})
  end
  events_json
end

def parse_body(response_body)
  body = {}
  begin
    body = JSON.parse(response_body)
  rescue JSON::ParserError => e
    raise("PE response is invalid json [#{e}]")
  end
  body
end


splunk_client = CommonEventsHttp.new(splunk_server, port: splunk_port, ssl_verify: false)
orchestrator = Orchestrator.new(pe_console, pe_username, pe_password, ssl_verify: false)
response = orchestrator.get_all_jobs
raise "Failed to get the jobs from PE [#{response.error!}]" unless response.code == '200'

body = parse_body(response.body)
transform(body['items'], pe_console, 'puppet:summary', splunk_client, splunk_token)

puts "Post of orchestrator events successful"

events = Events.new(pe_console, pe_username, pe_password, ssl_verify: false)
response = events.get_all_events
raise "Failed to get the activity API events from PE [#{response.error!}]" unless response.code == '200'

body = parse_body(response.body)
transform(body['commits'], pe_console, 'puppet:summary', splunk_client, splunk_token)
puts "Post of activity service events successful"
