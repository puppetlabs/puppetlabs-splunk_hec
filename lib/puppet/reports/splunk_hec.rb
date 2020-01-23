require 'puppet/util/splunk_hec'

Puppet::Reports.register_report(:splunk_hec) do
  desc 'Submits just a report summary to Splunk HEC endpoint'
  # Next, define and configure the report processor.

  include Puppet::Util::Splunk_hec
  def process
    # now we can create the event with the timestamp from the report

    epoch = sourcetypetime(time.iso8601(3))

    # pass simple metrics for report processing later
    #  STATES = [:skipped, :failed, :failed_to_restart, :restarted, :changed, :out_of_sync, :scheduled, :corrective_change]
    metrics = {
      'time' => {
        'config_retrieval' => self.metrics['time']['config_retrieval'],
        'fact_generation' => self.metrics['time']['fact_generation'],
        'catalog_application' => self.metrics['time']['catalog_application'],
        'total' => self.metrics['time']['total'],
      },
      'resources' => {
        'total' => self.metrics['resources']['total'],
      },
      'changes' => {
        'total' => self.metrics['changes']['total'],
      },
    }

    event = {
      'host' => host,
      'time' => epoch,
      'sourcetype' => 'puppet:summary',
      'event' => {
        'cached_catalog_status' =>  cached_catalog_status,
        'catalog_uuid' => catalog_uuid,
        'certname' => host,
        'code_id' => code_id,
        'configuration_version' => configuration_version,
        'corrective_change' => corrective_change,
        'environment' => environment,
        'job_id' => job_id,
        'metrics' => metrics,
        'noop' => noop,
        'noop_pending' => noop_pending,
        'pe_console' => pe_console,
        'producer' => Puppet[:certname],
        'puppet_version' => puppet_version,
        'report_format' => report_format,
        'status' => status,
        'time' => time.iso8601(3),
        'transaction_uuid' => transaction_uuid,
      },
    }

    if defined?(include_logs_status)
      if include_logs_status.include? status
       event['event']['logs'] = self.logs
      end
    end

    if include_logs_catalog_failure && catalog_uuid == ''
      event['event']['logs'] = self.logs
    end

    if include_resources_corrective_change && corrective_change
      event['event']['resource_statuses'] = self.resource_statuses
    end

    Puppet.info "Submitting report to Splunk at #{get_splunk_url('summary')}"
    submit_request event
    if record_event
      store_event event
    end
  rescue StandardError => e
    Puppet.err "Could not send report to Splunk: #{e}\n#{e.backtrace}"
  end
end
