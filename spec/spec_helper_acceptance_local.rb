# rubocop:disable Style/AccessorMethodName

require 'serverspec'
require 'puppet_litmus'
require 'support/acceptance/helpers'
require 'yaml'

include PuppetLitmus

# Silence warnings that a backend is not set.
set :backend, :exec

# Set the number of tasks that should be invoked and then sent to splunka as events
TASK_COUNT = 5

RSpec.configure do |config|
  include TargetHelpers

  config.before(:suite) do
    # Stop the puppet service on the master to avoid edge-case conflicting
    # Puppet runs (one triggered by service vs one we trigger)
    master.run_shell('puppet resource service puppet ensure=stopped')
  end
end

# Creating these clients here not only makes them available for later use, but
# Also creates Auth tokens that can be inserted into splunk_hec.yaml for testing
# token auth configuration.
def orchestrator_client
  @orchestrator ||= Orchestrator.new(master.uri.to_s, username: 'admin', password: 'pie', ssl_verify: false)
end

def events_client
  @events ||= Events.new(master.uri.to_s, username: 'admin', password: 'pie', ssl_verify: false)
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

  master.run_shell("echo '#{content}' > /etc/puppetlabs/code/environments/production/manifests/site.pp")
end

def splunk_hec_config
  command = 'cat `puppet config print confdir`/splunk_hec.yaml'
  yaml_content = master.run_shell(command).stdout
  YAML.safe_load(yaml_content)
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

def return_host
  master.uri
end

def default_splunk_class
  <<-MANIFEST
    class{'splunk_hec':
      url                    => "http://#{master.uri}:8088/services/collector/event",
      pe_console             => "#{master.uri}",
      splunk_token           => 'abcd1234',
      pe_username            => 'admin',
      pe_password            => Sensitive('pie'),
      enable_reports         => true,
      manage_routes          => true,
      include_api_collection => true,
    }
  MANIFEST
end

def token_splunk_class
  <<-MANIFEST
    class{'splunk_hec':
      url                    => "http://#{master.uri}:8088/services/collector/event",
      pe_console             => "#{master.uri}",
      splunk_token           => 'abcd1234',
      pe_token               => Sensitive('#{orchestrator_client.pe_client.token}'),
      enable_reports         => true,
      manage_routes          => true,
      include_api_collection => true,
    }
  MANIFEST
end

def bad_endpoint_splunk_class
  <<-MANIFEST
    class { 'splunk_hec':
      url                    => 'notanendpoint/nicetry',
      splunk_token           => '',
      record_event           => true,
      pe_username            => 'admin',
      pe_console             => 'localhost',
      pe_password            => Sensitive('pie'),
      include_api_collection => true,
    }
  MANIFEST
end

def missing_parameter_splunk_class
  <<-MANIFEST
    class { 'splunk_hec':
      url                    => 'notanendpoint/nicetry',
      splunk_token           => '',
      record_event           => true,
      include_api_collection => true,
    }
  MANIFEST
end

def service_class
  <<-MANIFEST
    service {'pe-puppetserver':
      ensure     => 'running',
      hasrestart => true,
      restart    => 'service pe-puppetserver reload',
    }
  MANIFEST
end

def default_manifest
  to_manifest(service_class, default_splunk_class)
end

def splunk_token_manifest
  to_manifest(service_class, token_splunk_class)
end

def bad_endpoint_manfest
  to_manifest(service_class, bad_endpoint_splunk_class)
end

def missing_parameter_manifest
  to_manifest(service_class, missing_parameter_splunk_class)
end

# Get the exact cron commandline that would have been run if we were willing to
# wait two minutes for the next cron triggered run. We aren't interested in
# testing cron though, so we just get the command line and execute it, but we
# need to get the exact command it wants to run so we still know if there's
# something wrong with it like a syntax error, that would prevent it from
# running correctly.
def cron_command
  cron_content = master.run_shell('crontab -l').stdout
  collector_line = cron_content.split("\n").select do |line|
    line =~ %r{splunk_hec_collect_api_events.rb}
  end
  collector_line.join.split[-3..-1].join(' ')
end
