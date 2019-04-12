require 'puppet/util/splunk_hec'

Puppet::Reports.register_report(:splunk_hec) do
  desc 'Submits just a report summary to Splunk HEC endpoint'
  # Next, define and configure the report processor.

  include Puppet::Util::Splunk_hec
  def process
    # now we can create the event with the timestamp from the report
    time = DateTime.parse(self.time.to_str)
    epoch = time.strftime('%Q').to_str.insert(-4, '.')

    # pass simple metrics for report processing later
    #  STATES = [:skipped, :failed, :failed_to_restart, :restarted, :changed, :out_of_sync, :scheduled, :corrective_change]
    metrics = {
      'time' => {
        'config_retrieval' => self.metrics['time']['config_retrieval'],
        'fact_generation' => self.metrics['time']['fact_generation'],
        'catalog_application' => self.metrics['time']['catalog_application'],
        'total' => self.metrics['time']['total'],
      },
      'resources' => self.metrics['resources']['total'],
      'changes' => self.metrics['changes']['total'],
    }

    event = {
      'host' => host,
      'time' => epoch,
      'sourcetype' => 'puppet:summary',
      'event' => {
        'status' => status,
        'corrective_change' => corrective_change,
        'noop' => noop,
        'noop_pending' => noop_pending,
        'environment' => environment,
        'configuration_version' => configuration_version,
        'transaction_uuid' => transaction_uuid,
        'catalog_uuid' => catalog_uuid,
        'cached_catalog_status' =>  cached_catalog_status,
        'code_id' => code_id,
        'time' => time,
        'job_id' => job_id,
        'puppet_version' => puppet_version,
        'certname' => host,
        'producer' => Puppet[:certname],
        'pe_console' => pe_console,
        'report_format' => report_format,
        'metrics' => metrics,
      },
    }

    Puppet.info "Submitting report to Splunk at #{splunk_url}"
    submit_request event
  rescue StandardError => e
    Puppet.err "Could not send report to Splunk: #{e}\n#{e.backtrace}"
  end
end
