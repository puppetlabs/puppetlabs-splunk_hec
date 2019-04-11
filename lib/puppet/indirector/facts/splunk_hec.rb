require 'puppet/indirector/facts/puppetdb'
require 'puppet/util/splunk_hec'

# splunk_hec.rb
class Puppet::Node::Facts::Splunk_hec < Puppet::Node::Facts::Puppetdb
  desc "Save facts to Splunk over HEC and PuppetDB.
       It uses PuppetDB to retrieve facts for catalog compilation."

  include Puppet::Util::Splunk_hec

  def save(request)
    # puppetdb goes first
    super(request)

    profile("splunk_facts#save", [:splunk, :facts, :save, request.key]) do
      begin
        host = request.instance.name.dup
        incoming_facts = request.instance.values.dup

        facts = {}

        hardcoded = [
          'os',
          'memory',
          'puppetversion',
          'system_uptime',
          'load_averages',
          'ipaddress',
          'fqdn'
        ]

        # lets ensure user provided fact names are downcased
        users = settings['facts'].map(&:downcase)

        keep = (hardcoded + users).uniq

        facts = incoming_facts.select{ |k,v| keep.include?(k) }

        facts['trusted'] = get_trusted_info(request.node)
        facts['environment'] = request.options[:environment] || request.environment.to_s
        facts['producer'] = Puppet[:node_name_value]

        event = {
          "host" => host,
          "sourcetype" => "puppet:facts",
          "event"  => facts,
        }

        Puppet.info "Submitting facts to Splunk at #{splunk_server}"
        submit_request event

      rescue StandardError => e
        Puppet.err "Could not send facts to Satellite: #{e}\n#{e.backtrace}"
      end
    end

  end
end