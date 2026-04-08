require 'serverspec'
require 'puppet_litmus'
require 'base64'
require 'support/acceptance/helpers.rb'

include PuppetLitmus
PuppetLitmus.configure!

EVENT_FORWARDING_CONFDIR     = '/etc/puppetlabs/pe_event_forwarding'.freeze
DIR_TEST_COMMAND             = '[[ -d /etc/puppetlabs/code/environments/production/modules/pe_event_forwarding ]] '\
                               '&& rm /etc/puppetlabs/code/environments/production/modules/pe_event_forwarding -rf'.freeze
EVENT_FORWARDING_LOCAL_PATH  = './spec/fixtures/modules/pe_event_forwarding'.freeze
EVENT_FORWARDING_REMOTE_PATH = '/etc/puppetlabs/code/environments/production/modules'.freeze

TARGET_SERVER = ENV['TARGET_HOST']

RSpec.configure do |config|
  include TargetHelpers

  config.before(:suite) do
    # Reset site.pp to an empty node block so stale classes from previous test
    # runs don't interfere with the fresh setup each spec's before(:all) performs.
    TARGET_SERVER.write_file("node default {}\n", '/etc/puppetlabs/code/environments/production/manifests/site.pp')

    # Remove pe_event_forwarding configs so each run starts from a clean slate.
    TARGET_SERVER.run_shell(
      'rm -rf /etc/puppetlabs/pe_event_forwarding '\
      '/opt/puppetlabs/pe_event_forwarding '\
      '/var/log/puppetlabs/pe_event_forwarding',
      expect_failures: true,
    )

    # Stop the puppet service on the puppetserver to avoid edge-case conflicting
    # Puppet runs (one triggered by service vs one we trigger)
    shell_command = 'puppet resource service puppet ensure=stopped; '\
      'puppet module install puppetlabs-inifile --version 5.1.0'
    TARGET_SERVER.run_shell(shell_command)
    TARGET_SERVER.run_shell(DIR_TEST_COMMAND, expect_failures: true)
    TARGET_SERVER.run_shell('rm -rf /etc/puppetlabs/code/environments/production/modules/pe_event_forwarding', expect_failures: true)
    TARGET_SERVER.bolt_upload_file(EVENT_FORWARDING_LOCAL_PATH, EVENT_FORWARDING_REMOTE_PATH)
  end
end

# TODO: This will cause some problems if we run the tests
# in parallel. For example, what happens if two targets
# try to modify site.pp at the same time?
def set_sitepp_content(manifest)
  content = <<-HERE
  node default {
    #{manifest}
  }
  HERE

  TARGET_SERVER.write_file(content, '/etc/puppetlabs/code/environments/production/manifests/site.pp')
  TARGET_SERVER.run_shell("chown #{puppet_user}:#{puppet_user} /etc/puppetlabs/code/environments/production/manifests/site.pp")
end

def trigger_puppet_run(target, acceptable_exit_codes: [0, 2])
  result = target.run_shell('puppet agent -t --detailed-exitcodes', expect_failures: true)
  unless acceptable_exit_codes.include?(result[:exit_code])
    raise "Puppet run failed\nstdout: #{result[:stdout]}\nstderr: #{result[:stderr]}"
  end
  result
end

def declare(type, title, params = {})
  params = params.map do |name, value|
    value = "'#{value}'" if value.is_a?(String)
    "  #{name} => #{value},"
  end

  <<-HERE
  #{type} { '#{title}':
  #{params.join("\n")}
  }
  HERE
end

def to_manifest(*declarations)
  declarations.join("\n")
end

def host_name
  @puppetserver_hostname ||= TARGET_SERVER.run_shell('facter fqdn').stdout.chomp
end

def report_dir
  cmd = "reportdir=`puppet config print reportdir --section server` \n"\
        "hostname=`facter fqdn` \n"\
        'echo \"$reportdir/$hostname\"'
  @report_dir ||= TARGET_SERVER.run_shell(cmd).stdout.chomp
end

def local_splunk_host
  inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
  all_nodes = inventory_hash['groups'].find { |g| g['name'] == 'ssh_nodes' }['targets']
  current_node = all_nodes.find { |t| t['uri'] == ENV['TARGET_HOST'] }
  splunk_target = current_node&.dig('vars', 'splunk_target')
  splunk_target ? splunk_target.split(':').first : 'localhost'
rescue StandardError
  'localhost'
end

def setup_manifest(disabled: false, cert_store: false, ssl_ca: nil, url: nil, with_event_forwarding: false)
  if url.nil?
    url = if ENV['SPLUNK_CI_URL'] && !ENV['SPLUNK_CI_URL'].empty?
            "#{ENV['SPLUNK_CI_URL']}:8088/services/collector"
          else
            "https://#{local_splunk_host}:8088/services/collector"
          end
  end

  manifest = ''
  params = {
    url:                       url,
    token:                     ENV.fetch('SPLUNK_CI_HEC_TOKEN', 'abcd1234'),
    enable_reports:            true,
    manage_routes:             true,
    facts_terminus:            'yaml',
    record_event:              true,
    disabled:                  disabled,
    include_system_cert_store: cert_store,
  }

  params[:ssl_ca] = ssl_ca unless ssl_ca.nil?

  if with_event_forwarding
    manifest << add_event_forwarding
    params[:events_reporting_enabled] = true
    params[:orchestrator_data_filter] = ['options.scope.nodes', 'options.scope.blah', 'environment.name']
    params[:orchestrator_plan_data_filter] = ['options.parameters.targets', 'options.parameters.blah', 'options.environment']
    params[:pe_console_data_filter] = ['subject.name', 'subject.blah', 'events']
  end

  manifest << declare(:class, :splunk_hec, params)
  manifest << add_service_resource unless puppet_user == 'pe-puppet'
  manifest
end

def add_service_resource
  params = {
    ensure: :running,
    hasrestart: true,
    restart: 'puppetserver reload'
  }
  declare(:service, :puppetserver, params)
end

def add_event_forwarding
  token = TARGET_SERVER.run_shell('puppet access show').stdout.chomp
  params = {
    pe_token: token,
    disabled: true
  }
  declare(:class, :pe_event_forwarding, params)
end

def configure_ssl(cert_store: false)
  ca_pem = if ENV['SPLUNK_CI_URL'] && !ENV['SPLUNK_CI_URL'].empty?
             # CI mode: using the persistent Splunk instance — its CA cert must be provided.
             ca_b64 = ENV.fetch('SPLUNK_CI_HEC_CA', nil)
             raise 'SPLUNK_CI_HEC_CA env var not set — required for SSL tests against the CI Splunk instance' if ca_b64.nil? || ca_b64.empty?
             Base64.decode64(ca_b64)
           else
             # Local mode: setup_hec_ssl in start_splunk_instance.sh signs Splunk's cert with
             # the puppet CA, so use the puppet CA cert so splunk_hec can verify Splunk's cert.
             TARGET_SERVER.run_shell('cat $(puppet config print localcacert)').stdout
           end

  TARGET_SERVER.run_shell('mkdir -p /etc/puppetlabs/puppet/splunk_hec')
  TARGET_SERVER.write_file(ca_pem, '/etc/puppetlabs/puppet/splunk_hec/ca.pem')
  TARGET_SERVER.run_shell('chmod 644 /etc/puppetlabs/puppet/splunk_hec/ca.pem')

  return unless cert_store

  inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
  image = LitmusHelpers.facts_from_node(inventory_hash, TARGET_SERVER)
  cmd = if image['platform'].include?('ubuntu')
          'cp /etc/puppetlabs/puppet/splunk_hec/ca.pem /usr/local/share/ca-certificates/splunk_hec.crt && update-ca-certificates'
        else
          'cp /etc/puppetlabs/puppet/splunk_hec/ca.pem /etc/pki/ca-trust/source/anchors/splunk_hec.pem && update-ca-trust'
        end
  TARGET_SERVER.run_shell(cmd)
end

def puppet_user
  @service_name ||= query_puppet_user
end

def query_puppet_user
  service_name = ''
  TARGET_SERVER.run_shell('[ -f /opt/puppetlabs/server/pe_version ]', expect_failures: true) do |result|
    service_name = (result.exit_code == 0) ? 'pe-puppet' : 'puppet'
  end
  service_name
end

def get_splunk_report(earliest, latest, sourcetype = 'puppet:summary', host: host_name)
  splunk_user = ENV.fetch('SPLUNK_CI_USER', 'admin')
  splunk_pass = ENV.fetch('SPLUNK_CI_PASS', 'piepiepie')
  splunk_host = (ENV['SPLUNK_CI_URL'] && !ENV['SPLUNK_CI_URL'].empty?) ? ENV['SPLUNK_CI_URL'] : "https://#{local_splunk_host}"
  search_url  = "#{splunk_host}:8089/services/search/v2/jobs/export"
  start_time  = earliest.strftime('%m/%d/%Y:%H:%M:%S')
  end_time    = (latest + 2).strftime('%m/%d/%Y:%H:%M:%S')
  sleep 1
  query_command = "curl -u #{splunk_user}:#{splunk_pass} -k " \
    "#{search_url} -d output_mode=json " \
    "-d search='search sourcetype=\"#{sourcetype}\" AND host=\"#{host}\" AND earliest=\"#{start_time}\" AND latest=\"#{end_time}\"'"
  response = TARGET_SERVER.run_shell(query_command).stdout
  JSON.parse("[#{response.split.join(',')}]")
end

def splunk_hec_source
  (ENV['SPLUNK_CI_URL'] && !ENV['SPLUNK_CI_URL'].empty?) ? 'http:splunk_hec_ci' : 'http:splunk_hec_token'
end

def report_count(report)
  report[0]['result'].nil? ? 0 : report.count
end

def log_count(message, log)
  cmd = "grep '#{message}' #{log} -c"
  TARGET_SERVER.run_shell(cmd, expect_failures: true).stdout.chomp.to_i
end

def server_agent_run(manifest)
  set_sitepp_content(manifest)
  trigger_puppet_run(TARGET_SERVER)
end

def console_host_fqdn
  @console_host_fqdn ||= TARGET_SERVER.run_shell('hostname -f').stdout.strip
end
