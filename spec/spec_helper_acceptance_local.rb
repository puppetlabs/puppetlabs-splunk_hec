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
    puppetserver.run_shell('puppet resource service puppet ensure=stopped')
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

  puppetserver.run_shell("echo '#{content}' > /etc/puppetlabs/code/environments/production/manifests/site.pp")
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

def setup_manifest(servicename, disabled: false, url: 'http://localhost:8088/services/collector/event')
  <<-MANIFEST
  # cloned from https://github.com/puppetlabs/puppetlabs-puppet_enterprise/blob/a82d3adafcf1dfd13f1c338032f325d80fa58eda/manifests/trapperkeeper/pe_service.pp#L10-L17
  service { '#{servicename}':
    ensure     => running,
    hasrestart => true,
    restart    => "service #{servicename} reload",
  }

  class { 'splunk_hec':
    url                    => '#{url}',
    token                  => 'abcd1234',
    record_event           => true,
    pe_console             => 'localhost',
    disabled               => #{disabled},
  }
  MANIFEST
end

def puppet_service_name
  service_name = ''
  run_shell('[ -f /opt/puppetlabs/server/pe_version ]', expect_failures: true) do |result|
    service_name = result.exit_code == 0 ? 'pe-puppetserver' : 'puppetserver'
  end
  service_name
end

def clear_testing_setup
  run_shell("if [ -d \"#{report_dir}\" ]; then find #{report_dir} -type f -delete; fi")
end
