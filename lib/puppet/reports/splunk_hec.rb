require 'puppet'
require 'yaml'
require 'json'
require 'net/https'

Puppet::Reports.register_report(:splunk_hec) do
  desc "Submits just a report summary to Splunk HEC endpoint"
  # Next, define and configure the report processor.
  def process
    splunk_event = {
      "host" => self.host,
      "event"  => {
        "status" => self.status,
        "corrective_change" => self.corrective_change,
        "noop" => self.noop,
        "noop_pending" => self.noop_pending,
        "environment" => self.environment,
        "configuration_version" => self.configuration_version,
        "transaction_uuid" => self.transaction_uuid,
        "catalog_uuid" => self.catalog_uuid,
        "cached_catalog_status" =>  self.cached_catalog_status,
        "code_id" => self.code_id,
        "time" => self.time,
        "job_id" => self.job_id,
        "puppet_version" => self.puppet_version,
        "report_format" => self.report_format
      },
    }

    splunkhec = YAML.load_file(Puppet[:confdir] + '/splunkhec.yaml')

    splunk_server = splunkhec['server']
    splunk_token  = splunkhec['token']
    # optionally set hec port
    splunk_port = splunkhec['port'] || 8088
    # adds timeout, 2x value because of open and read timeout options
    splunk_timeout = splunkhec['timeout'] || 2

    #  create header here
    #header = "Authorization: Splunk #{splunk_token}"

    request = Net::HTTP::Post.new("https://#{splunk_server}:#{splunk_port}/services/collector")
    request.add_field("Authorization", "Splunk #{splunk_token}")
    request.add_field("Content-Type", "application/json")
    request.body = splunk_event.to_json

    client = Net::HTTP.new(splunk_server, splunk_port)
    client.open_timeout = splunk_timeout
    client.read_timeout = splunk_timeout

    client.use_ssl = true
    client.verify_mode = OpenSSL::SSL::VERIFY_NONE

    client.request(request)

  end
  
end