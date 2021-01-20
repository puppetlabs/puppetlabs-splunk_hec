#!/opt/puppetlabs/puppet/bin/ruby
require 'fileutils'
require 'benchmark'
require 'json'
require 'net/https'
require 'time'
require 'yaml'
require 'find'

STORE_DIR = ENV['STORE_DIR'] || '/etc/puppetlabs/splunk/'

API_JOBS_STORE = "#{STORE_DIR}/splunk-jobs-store".freeze
API_ACTIVITY_STORE = "#{STORE_DIR}/splunk-activity-store".freeze

def load_settings(configfile)
  raise "Failed to load the config file [#{configfile}]" unless File.file?(configfile)
  open(configfile) { |f| YAML.safe_load(f) }
end

def hostname_without_protocol(pe_console)
  pe_console_uri = URI.parse(pe_console)
  # If the hostname parameter is an IP address, use the path instead of the hostname
  pe_console_uri.hostname || pe_console_uri.path
end

def transform(body, pe_console, source_type)
  events = ''
  body.each do |pe_event|
    timestamp = Time.new
    event = {
      'host' => hostname_without_protocol(pe_console),
      'time' => timestamp.to_i,
      'sourcetype' => source_type,
      'event' => pe_event,
    }
    events << "#{event.to_json} "
  end
  events
end

def store_index(index, filepath)
  open(filepath, 'w') { |f| f.puts index }
end

def get_index(filepath)
  # rubocop:disable Style/RescueModifier
  File.open(filepath, &:readline).to_i rescue 0
end

def process_response(body, total, settings, index_file, source_type, splunk_client)
  return false if total.nil? || total.zero?

  events_json = transform(body, settings['pe_console'], source_type)
  store_index(body.empty? ? 0 : total, index_file)

  response = splunk_client.post_request('/services/collector', events_json, { Authorization: "Splunk #{settings['token']}" }, use_raw_body: true)
  raise "Failed to POST to the splunk server [#{response.error!}]" unless response.code == '200'
  true
end

def main(confdir, modulepaths)
  ENV['PATH'] = "#{ENV['PATH']}:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"

  catch :done do
    modulepaths.split(':').each do |modulepath|
      Find.find(modulepath) do |path|
        if path =~ %r{common_events_library.gemspec}
          $LOAD_PATH.unshift("#{File.dirname(path)}/lib")
          throw :done
        end
      end
    end
  end

  require 'common_events_library'

  config_file = ENV['CONFIG_FILE'] || "#{confdir}/splunk_hec.yaml"

  # ensure the config directory is created.
  FileUtils.mkdir_p STORE_DIR

  # load our settings from the config file.
  settings = load_settings(config_file)

  # setup clients
  splunk_uri = URI(settings['url'])

  splunk_client        = CommonEventsHttp.new((splunk_uri.scheme + '://' + splunk_uri.host), port: 8088, ssl_verify: false)
  orchestrator_client  = Orchestrator.new(settings['pe_console'], username: settings['pe_username'], password: settings['pe_password'], token: settings['pe_token'], ssl_verify: false)
  events_client        = Events.new(settings['pe_console'], username: settings['pe_username'], password: settings['pe_password'], token: settings['pe_token'], ssl_verify: false)

  # source and process the orchestrator events
  previous_index = get_index(API_JOBS_STORE)

  # Orchestrator offsets count down from the newest record vs counting up from the oldest.
  # This first request is to determine the total number of jobs that exist.
  jobs = orchestrator_client.get_jobs(limit: 1)

  # New jobs is determined by subtracting total number of jobs from the jobs that already exist in Splunk.
  new_jobs = jobs.total - previous_index

  puts "Sending #{new_jobs} Orchestrator job(s) to Splunk."
  if new_jobs > 0
    jobs = orchestrator_client.get_jobs(limit: new_jobs)
    process_response(jobs.items, jobs.total, settings, API_JOBS_STORE, 'puppet:events_summary', splunk_client)
  end

  # source and process the activity service events
  services = ['classifier', 'rbac'] # 'pe-console', 'code-manager']

  services.each do |service|
    store_file = "#{API_ACTIVITY_STORE}-#{service}"
    previous_index = get_index(store_file)

    # determine the event list size from an initial read
    events = events_client.get_events(service: service, limit: 1)

    # determine the event new_jobs amount
    new_jobs = events.total - previous_index
    puts "Sending #{new_jobs} #{service} events(s) to Splunk."

    next unless new_jobs > 0

    # get the events using the limit
    events = events_client.get_events(service: service, limit: new_jobs)
    result = process_response(events.items, events.total, settings, store_file, 'puppet:activity', splunk_client)
    puts "There were no activity service #{service} events to send to splunk" unless result
    puts "Activity events for #{service} sent to splunk" if result
  end
end

if $PROGRAM_NAME == __FILE__
  main(ARGV[0], ARGV[1])
end
