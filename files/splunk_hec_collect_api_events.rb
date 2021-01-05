#!/opt/puppetlabs/puppet/bin/ruby
require 'fileutils'
require 'benchmark'
require 'json'
require 'net/https'
require 'time'
require 'yaml'
require 'find'

modulepaths = `puppet config print modulepath`.chomp.split(':')

catch :done do
  modulepaths.each do |modulepath|
    Find.find(modulepath) do |path|
      if path =~ %r{common_events_library.gemspec}
        $LOAD_PATH.unshift("#{File.dirname(path)}/lib")
        throw :done
      end
    end
  end
end

require 'common_events_library'

STORE_DIR = ENV['STORE_DIR'] || '/etc/puppetlabs/splunk/'

API_EVENTS_STORE = "#{STORE_DIR}/splunk-events-store".freeze
API_ACTIVITY_STORE = "#{STORE_DIR}/splunk-activity-store".freeze

def load_settings(configfile)
  raise "Failed to load the config file [#{configfile}]" unless File.file?(configfile)
  open(configfile) { |f| YAML.safe_load(f) }
end

def transform(body, pe_console, source_type)
  events = ''
  body.each do |pe_event|
    timestamp = Time.new
    event = {
      'host' => pe_console,
      'time' => timestamp.to_i,
      'sourcetype' => source_type,
      'event' => pe_event,
    }
    events << "#{event.to_json} "
  end
  events
end

def store_index(index, filepath)
  open(filepath, 'w') { |f| f.puts index }
end

def get_index(filepath)
  # rubocop:disable Style/RescueModifier
  File.open(filepath, &:readline).to_i rescue 0
end

def process_response(body, total, settings, index_file, source_type, splunk_client)
  return false if total.nil? || total.zero?

  events_json = transform(body, settings['pe']['console'], source_type)
  store_index(body.empty? ? 0 : total, index_file)

  response = splunk_client.post_request('/services/collector', events_json, { Authorization: "Splunk #{settings['splunk']['token']}" }, use_raw_body: true)
  raise "Failed to POST to the splunk server [#{response.error!}]" unless response.code == '200'
  true
end

config_file = ENV['CONFIG_FILE'] || "#{File.expand_path(File.dirname(__FILE__))}/../conf/splunk_config.yaml"

# ensure the config directory is created.
FileUtils.mkdir_p STORE_DIR

# load our settings from the config file.
settings = load_settings(config_file)

# setup clients
splunk_client = CommonEventsHttp.new('http://' + settings['splunk']['server'], port: settings['splunk']['port'], ssl_verify: false)
orchestrator  = Orchestrator.new(settings['pe']['console'], settings['pe']['username'], settings['pe']['password'], ssl_verify: false)
events        = Events.new(settings['pe']['console'], settings['pe']['username'], settings['pe']['password'], ssl_verify: false)

# source and process the orchestrator events
previous_index = get_index(API_EVENTS_STORE)

response = orchestrator.get_all_jobs(offset: previous_index, limit: 1000)
raise "Failed to get the jobs from PE [#{response.error!}]" unless response.code == '200'
body = JSON.parse(response.body)

puts body['pagination']

result = process_response(body['items'], body['pagination']['total'], settings, API_EVENTS_STORE, 'puppet:events_summary', splunk_client)
puts 'There were no orchestrator events to send to splunk' unless result
puts 'Orchestrator events sent to splunk' if result

# source and process the activity service events
previous_index = get_index(API_ACTIVITY_STORE)

response = events.get_all_events(offset: previous_index)
raise "Failed to get the activity API events from PE [#{response.error!}]" unless response.code == '200'
body = JSON.parse(response.body)
puts body['total-rows']
result = process_response(body['commits'], body['total-rows'], settings, API_ACTIVITY_STORE, 'puppet:activity', splunk_client)
puts 'There were no activity service events to send to splunk' unless result
puts 'Activity events sent to splunk' if result
