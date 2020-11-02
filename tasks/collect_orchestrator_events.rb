require 'common_events_library'
require 'benchmark'
require 'net/https'
require 'time'

PE_CONSOLE = ENV['PT_PE_CONSOLE']
USERNAME = ENV['PT_PE_USERNAME'] || 'admin'
PASSWORD = ENV['PT_PE_PASSWORD'] || 'pie'

SPLUNK_SERVER = ENV['PT_SPLUNK_SERVER']
SPLUNK_PORT = ENV['PT_SPLUNK_PORT']
SPLUNK_TOKEN = ENV['PT_SPLUNK_TOKEN']

token = Http.get_token(PE_CONSOLE, USERNAME, PASSWORD)

response = Orchestrator.get_all_jobs(token, PE_CONSOLE)

request = Net::HTTP::Post.new("https://#{SPLUNK_SERVER}:#{SPLUNK_PORT}/services/collector")
request.add_field('Authorization', "Splunk #{SPLUNK_TOKEN}")
request.add_field('Content-Type', 'application/json')

timestamp = Time.new
event = {
  'host' => PE_CONSOLE,
  'time' => timestamp.to_i,
  'sourcetype' => 'puppet:summary',
  'event' => {
    'pe_orchestrator_events' =>  response.body,
  },
}

request.body = event.to_json

client = Net::HTTP.new(SPLUNK_SERVER, SPLUNK_PORT)

client.use_ssl = false
client.verify_mode = OpenSSL::SSL::VERIFY_NONE
client.request(request)

