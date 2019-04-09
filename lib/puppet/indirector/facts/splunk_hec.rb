require 'puppet/indirector/facts/puppetdb'
require 'yaml'
require 'json'
require 'date'
require 'net/https'

# satellite.rb
class Puppet::Node::Facts::Splunk_hec < Puppet::Node::Facts::Puppetdb
  desc "Save facts to Splunk over HEC and PuppetDB.
       It uses PuppetDB to retrieve facts for catalog compilation."


  def save(request)
    begin

      facts = request.instance.dup
      facts.values = facts.values.dup
      facts.values[:trusted] = get_trusted_info(request.node)
      facts.values[:environment] = request.options[:environment] || request.environment.to_s
      facts.values[:producer] = Puppet[:node_name_value]

      facts.values.delete('_puppet_inventory_1')

      splunk_event = {
        "host" => facts.name,
        "sourcetype" => "puppet:facts",
        "event"  => facts.values
      }

      splunk_hec_config = YAML.load_file(Puppet[:confdir] + '/splunk_hec.yaml')

      splunk_server = splunk_hec_config['server']
      splunk_token  = splunk_hec_config['token']
      # optionally set hec port
      splunk_port = splunk_hec_config['port'] || '8088'
      # adds timeout, 2x value because of open and read timeout options
      splunk_timeout = splunk_hec_config['timeout'] || '2'

      splunk_request = Net::HTTP::Post.new("https://#{splunk_server}:#{splunk_port}/services/collector")
      splunk_request.add_field("Authorization", "Splunk #{splunk_token}")
      splunk_request.add_field("Content-Type", "application/json")
      splunk_request.body = splunk_event.to_json

      client = Net::HTTP.new(splunk_server, splunk_port)
      client.open_timeout = splunk_timeout.to_i
      client.read_timeout = splunk_timeout.to_i

      client.use_ssl = true

      client.verify_mode = OpenSSL::SSL::VERIFY_NONE

      Puppet.info "Submitting facts to Splunk at #{splunk_server}"
      response = client.request(splunk_request)

    rescue StandardError => e
      Puppet.err "Could not send facts to Satellite: #{e}\n#{e.backtrace}"
    end

    super(request)
  end
end