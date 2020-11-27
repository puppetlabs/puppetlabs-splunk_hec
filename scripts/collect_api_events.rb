#!/opt/puppetlabs/puppet/bin/ruby

require 'common_events_library'
require 'benchmark'
require 'json'
require 'net/https'
require 'time'
require 'yaml'

def load_settings(configfile)
  raise "Failed to load the config file [#{configfile}]" unless File.file?(configfile)
  open(configfile) {|f| YAML.load(f) }
end

def transform(body, pe_console, source_type, splunk_client, splunk_token)
  events = ''
  body.each do |pe_event|
    timestamp = Time.new
    event = {
      'host' => pe_console,
      'time' => timestamp.to_i,
      'sourcetype' => source_type,
      'event' => pe_event,
    }
    events = events + ' ' unless events.empty?
    events = events + event.to_json
  end
  events
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

config_file = ENV['CONFIG_FILE'] || "#{File.expand_path(File.dirname(__FILE__))}/../conf/splunk_config.yaml"
settings = load_settings(config_file)

splunk_client = CommonEventsHttp.new('http://' + settings['splunk']['server'], port: settings['splunk']['port'], ssl_verify: false)
orchestrator = Orchestrator.new(settings['pe']['console'], settings['pe']['username'], settings['pe']['password'], ssl_verify: false)
response = orchestrator.get_all_jobs
raise "Failed to get the jobs from PE [#{response.error!}]" unless response.code == '200'

body = parse_body(response.body)

events_json = transform(body['items'], settings['pe']['console'], 'puppet:summary', splunk_client, settings['splunk']['token'])

unless events_json.empty?
  response = splunk_client.post_request('/services/collector', events_json, {'Authorization': "Splunk #{settings['splunk']['token']}"}, use_raw_body: true)
  raise "Failed to POST to the splunk server [#{response.error!}]" unless response.code == '200'

  puts "Post of orchestrator events successful"
else
  puts "There were no orchestrator events"
end

events = Events.new(settings['pe']['console'], settings['pe']['username'], settings['pe']['password'], ssl_verify: false)
response = events.get_all_events
raise "Failed to get the activity API events from PE [#{response.error!}]" unless response.code == '200'

body = parse_body(response.body)
activity_json = transform(body['commits'], settings['pe']['console'], 'puppet:summary', splunk_client, settings['splunk']['token'])
unless activity_json.empty?
  response = splunk_client.post_request('/services/collector', activity_json, {'Authorization': "Splunk #{settings['splunk']['token']}"}, use_raw_body: true)
  raise "Failed to POST to the splunk server [#{response.error!}]" unless response.code == '200'

  puts "Post of activity service events successful"
else
  puts "There were no activity service events"
end
