require 'puppet'
require 'puppet/util'
require 'fileutils'
require 'net/http'
require 'uri'
require 'yaml'
require 'json'
require 'time'

# rubocop:disable Style/ClassAndModuleCamelCase
# splunk_hec.rb
module Puppet::Util::Splunk_hec
  def settings
    return @settings if @settings
    @settings_file = Puppet[:confdir] + '/splunk_hec.yaml'

    @settings = YAML.load_file(@settings_file)
  end

  def build_ca_store(cert_store_file_path)
    store = OpenSSL::X509::Store.new
    store.add_file(cert_store_file_path)
    store
  end

  def create_http(source_type)
    splunk_url = get_splunk_url(source_type)
    @uri = URI.parse(splunk_url)
    timeout = settings['timeout'] || '1'
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.open_timeout = timeout.to_i
    http.read_timeout = timeout.to_i
    http.use_ssl = @uri.scheme == 'https'
    if http.use_ssl?
      if settings['ssl_ca'] && !settings['ssl_ca'].empty?
        ssl_ca = File.join(Puppet[:confdir], 'splunk_hec', settings['ssl_ca'])
        raise Puppet::Error, "CA file #{ssl_ca} does not exist" unless File.exist? ssl_ca
        ssl_info_message = "Will verify #{splunk_url} SSL identity"

        if settings['ignore_system_cert_store']
          http.cert_store = build_ca_store(ssl_ca)
          ssl_info_message = "#{ssl_info_message} ignoring system cert store"
        else
          http.ca_file = ssl_ca
        end

        Puppet.info ssl_info_message
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      else
        Puppet.info "Will NOT verify #{splunk_url} SSL identity"
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    http
  end

  def submit_request(body)
    # we want users to be able to provide different tokens per sourcetype if they want
    source_type = body['sourcetype'].split(':')[1]
    token_name = "token_#{source_type}"
    token = settings[token_name] || settings['token'] || raise(Puppet::Error, 'Must provide token parameter to splunk class')
    if settings['fips_enabled']
      splunk_url = URI.parse(get_splunk_url(source_type))
      headers = {
        'Authorization' => "Splunk #{token}",
        'Content-Type'  => 'application/json'
      }

      client = Puppet.runtime[:http]
      client.post(splunk_url, body.to_json, headers: headers)
    else
      require 'net/https'
      http = create_http(source_type)
      req = Net::HTTP::Post.new(@uri.path.to_str)
      req.add_field('Authorization', "Splunk #{token}")
      req.add_field('Content-Type', 'application/json')
      req.content_type = 'application/json'
      req.body = body.to_json
      http.request(req)
    end
  end

  def store_event(event)
    host = event['host']
    epoch = event['time'].to_f

    timestamp = Time.at(epoch).to_datetime

    filename = timestamp.strftime('%F-%H-%M-%S-%L') + '.json'

    dir = File.join(Puppet[:reportdir], host)

    unless Puppet::FileSystem.exist?(dir)
      FileUtils.mkdir_p(dir)
      FileUtils.chmod_R(0o750, dir)
    end

    file = File.join(dir, filename)

    begin
      File.open(file, 'w') do |f|
        f.write(event.to_json)
      end
    rescue => detail
      Puppet.log_exception(detail, "Could not write report for #{host} at #{file}: #{detail}")
    end
  end

  private

  def get_splunk_url(source_type)
    url_name = "url_#{source_type}"
    settings[url_name] || settings['url'] || raise(Puppet::Error, 'Must provide url parameter to splunk class')
  end

  def pe_console
    settings['pe_console'] || Puppet[:certname]
  end

  def record_event
    result = if settings['record_event'] == 'true'
               true
             else
               false
             end
    result
  end

  # standard function to make sure we're using the same time format our sourcetypes are set to parse
  def sourcetypetime(time, duration = 0)
    parsed_time = time.is_a?(String) ? Time.parse(time) : time
    total = Time.parse((parsed_time + duration).iso8601(3))
    '%10.3f' % total.to_f
  end
end
