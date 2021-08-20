require 'serverspec'
require 'puppet_litmus'
require 'support/acceptance/helpers.rb'

include PuppetLitmus
PuppetLitmus.configure!

RSpec.configure do |config|
  include TargetHelpers

  config.before(:suite) do
    # Stop the puppet service on the puppetserver to avoid edge-case conflicting
    # Puppet runs (one triggered by service vs one we trigger)
    shell_command = 'puppet resource service puppet ensure=stopped; '\
      'puppet module install puppetlabs-inifile --version 5.1.0'
    puppetserver.run_shell(shell_command)
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

  puppetserver.write_file(content, '/etc/puppetlabs/code/environments/production/manifests/site.pp')
  puppetserver.run_shell("chown #{puppet_user}:#{puppet_user} /etc/puppetlabs/code/environments/production/manifests/site.pp")
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
  @puppetserver_hostname ||= puppetserver.run_shell('facter fqdn').stdout.chomp
end

def report_dir
  cmd = "reportdir=`puppet config print reportdir --section server` \n"\
        "hostname=`facter fqdn` \n"\
        'echo \"$reportdir/$hostname\"'
  @report_dir ||= puppetserver.run_shell(cmd).stdout.chomp
end

def setup_manifest(disabled: false, url: 'http://localhost:8088/services/collector/event')
  params = {
    url:            url,
    token:          'abcd1234',
    enable_reports: true,
    record_event:   true,
    pe_console:     'localhost',
    disabled:       disabled,
  }

  unless puppet_user == 'pe-puppet'
    params[:manage_routes] = true
    params[:facts_terminus] = 'yaml'
  end

  manifest = declare(:class, :splunk_hec, params)
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

def puppet_user
  @service_name ||= query_puppet_user
end

def query_puppet_user
  service_name = ''
  puppetserver.run_shell('[ -f /opt/puppetlabs/server/pe_version ]', expect_failures: true) do |result|
    service_name = result.exit_code == 0 ? 'pe-puppet' : 'puppet'
  end
  service_name
end

def get_splunk_report_count(earliest, latest)
  start_time =  earliest.strftime('%m/%d/%Y:%H:%M:%S')
  end_time   = (latest + 2).strftime('%m/%d/%Y:%H:%M:%S')
  query_command = 'curl -u admin:piepiepie -k '\
    'https://localhost:8089/services/search/jobs/export -d output_mode=json '\
    "-d search='search sourcetype=\"puppet:summary\" AND earliest=\"#{start_time}\" AND latest=\"#{end_time}\"'"
  response = puppetserver.run_shell(query_command).stdout
  data = JSON.parse("[#{response.split.join(',')}]")
  data[0]['result'].nil? ? 0 : data.count
end

def server_agent_run(manifest)
  set_sitepp_content(manifest)
  trigger_puppet_run(puppetserver)
end
