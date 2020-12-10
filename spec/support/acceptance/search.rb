require 'commmon_events_library'

SPLUNK_SERVER = 'residual-appeal.delivery.puppetlabs.net'

splunk_client = CommonEventsHttp.new(
  "http://#{SPLUNK_SERVER}",
  port: 8088,
  ssl_verify: false,
)

response = splunk_client.get_request('/services/search/jobs', { Authorization: "Splunk #{settings['token']}" })

require 'pry';binding.pry

puts response