require 'puppet/util/splunk_hec'

Puppet::Reports.register_report(:splunk_hec) do
  desc "Submits just a report summary to Splunk HEC endpoint"
  # Next, define and configure the report processor.

  include Puppet::Util::Splunk_hec
  def process
    # now we can create the event with the timestamp from the report
    time = DateTime.parse(self.time)
    epoch = time.strftime('%Q').to_str.insert(-4, '.')

    # pass simple metrics for report processing later
    #  STATES = [:skipped, :failed, :failed_to_restart, :restarted, :changed, :out_of_sync, :scheduled, :corrective_change]
    metrics = {
      "time" => {
        "config_retrieval" => self.metrics['time']['config_retrieval'],
        "fact_generation" => self.metrics['time']['fact_generation'],
        "catalog_application" => self.metrics['time']['catalog_application'],
        "total" => self.metrics['time']['total'],
      },
      "resources" => self.metrics['resources']['total'],
      "changes" => self.metrics['changes']['total'],
    }

    event = {
      "host" => self.host,
      "time" => epoch,
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
        "puppetdb_callback_hostname" => settings['puppetdb_callback_hostname'] || Puppet[:certname],
        "report_format" => self.report_format,
        "metrics" => metrics
      }
    }
    
    Puppet.info "Submitting report to Splunk at #{splunk_server}"
    submit_request event

  rescue StandardError => e
    Puppet.err "Could not send report to Splunk: #{e}\n#{e.backtrace}"
  end

end