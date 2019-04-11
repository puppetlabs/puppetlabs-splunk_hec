require 'puppet'
require 'puppet/util'
require 'net/http'
require 'net/https'
require 'uri'
require 'yaml'
require 'json'

# splunk_hec.rb
module Puppet::Util::Splunk_hec
  def settings
    return @settings if @settings
    $settings_file = Puppet[:confdir] + '/splunk_hec.yaml'

    @settings = YAML.load_file($settings_file)
  end

  def create_http
    @uri = URI.parse(splunk_url)
    timeout = settings['timeout'] || '1'
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.open_timeout = timeout.to_i
    http.read_timeout = timeout.to_i
    http.use_ssl = @uri.scheme == 'https'
    if http.use_ssl?
      if settings['ssl_ca'] && !settings['ssl_ca'].empty?
        Puppet.info "Will verify #{splunk_url} SSL identity"
        ssl_ca = File.join(Puppet[:confdir], "splunk_hec", settings['ssl_ca'])
        http.ca_file = ssl_ca
        raise Puppet::Error, "CA file #{ssl_ca} does not exist" unless File.exist? ssl_ca

        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      else
        Puppet.info "Will NOT verify #{splunk_url} SSL identity"
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    http
  end

  def submit_request(body)
    http = create_http
    token = settings['token'] || raise(Puppet::Error, 'Must provide token parameter to splunk class')
    req = Net::HTTP::Post.new("#{@uri.path}")
    req.add_field("Authorization", "Splunk #{token}")
    req.add_field("Content-Type", "application/json")
    req.content_type = 'application/json'
    req.body = body.to_json
    http.request(req)
  end

  private

  def splunk_url
    settings['url'] || raise(Puppet::Error, 'Must provide url parameter to splunk class')
  end
  
  def puppetdb_callback_hostname
    settings['puppetdb_callback_hostname'] || Puppet[:certname]
  end
end