require 'puppet'
require 'yaml'
require 'json'
require 'net/https'

Puppet::Reports.register_report(:splunk_hec) do
  desc "Submits just a report summary to Splunk HEC endpoint"
  # Next, define and configure the report processor.
  def process

    splunk_hec_config = YAML.load_file(Puppet[:confdir] + '/splunk_hec.yaml')

    splunk_server = splunk_hec_config['server']
    splunk_token  = splunk_hec_config['token']
    # optionally set hec port
    splunk_port = splunk_hec_config['port'] or '8088'
    # adds timeout, 2x value because of open and read timeout options
    splunk_timeout = splunk_hec_config['timeout'] or '2'
    # since you can have multiple installs sending to splunk, this looks for a puppetdb server splunk
    # can query to get more info. Defaults to the server processing report if none provided in config
    puppetdb_callback_hostname = splunk_hec_config['puppetdb_callback_hostname'] or Puppet[:certname]

    # pass simple metrics for report processing later
    #  STATES = [:skipped, :failed, :failed_to_restart, :restarted, :changed, :out_of_sync, :scheduled, :corrective_change]
    metrics = {
      "time" => {
        "config_retrieval" => self.metrics['time']['config_retrieval'],
        "total" => self.metrics['time']['total'],
      },
      "resources" => self.metrics['resources']['total'],
      "changes" => self.metrics['changes']['total'],
    }

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
        "certname" => self.host,
        "puppetdb_callback_hostname" => puppetdb_callback_hostname,
        "report_format" => self.report_format,
        "metrics" => metrics
      }
    }



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