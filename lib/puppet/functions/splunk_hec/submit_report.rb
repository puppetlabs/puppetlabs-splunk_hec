require 'yaml'
require 'json'
require 'net/https'
require 'date'

Puppet::Functions.create_function(:'splunk_hec::submit_report') do
  def submit_report(report, facts, guid)
    splunk_hec_config = YAML.load_file('/Users/cbarker/.puppetlabs/etc/puppet/splunk_hec.yaml')

    splunk_server = splunk_hec_config['server']
    splunk_token  = splunk_hec_config['token']
    # optionally set hec port
    splunk_port = splunk_hec_config['port'] || '8088'
    # adds timeout, 2x value because of open and read timeout options
    splunk_timeout = splunk_hec_config['timeout'] || '2'
    # since you can have multiple installs sending to splunk, this looks for a puppetdb server splunk
    # can query to get more info. Defaults to the server processing report if none provided in config

    #convert to epoch

    time = DateTime.parse("#{report['time']}")
    epoch = time.strftime('%Q').to_str.insert(-4, '.')

    report['facts'] = facts
    report['plan_guid'] = guid

    splunk_event = {
      "host" => facts['clientcert'],
      "time" => epoch,
      "event"  => report
    }

    #  create header here
    #header = "Authorization: Splunk #{splunk_token}"

    request = Net::HTTP::Post.new("https://#{splunk_server}:#{splunk_port}/services/collector")
    request.add_field("Authorization", "Splunk #{splunk_token}")
    request.add_field("Content-Type", "application/json")
    request.body = splunk_event.to_json

    client = Net::HTTP.new(splunk_server, splunk_port)
    client.open_timeout = splunk_timeout.to_i
    client.read_timeout = splunk_timeout.to_i

    client.use_ssl = true
    client.verify_mode = OpenSSL::SSL::VERIFY_NONE

    client.request(request)
  end
end