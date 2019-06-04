require 'puppet'
require 'puppet/util'
require 'fileutils'
require 'net/http'
require 'net/https'
require 'uri'
require 'yaml'
require 'json'
require 'time'

# splunk_hec.rb
module Puppet::Util::Splunk_hec
  def settings
    return @settings if @settings
    $settings_file = Puppet[:confdir] + '/splunk_hec.yaml'

    @settings = YAML.load_file($settings_file)
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
        Puppet.info "Will verify #{splunk_url} SSL identity"
        ssl_ca = File.join(Puppet[:confdir], 'splunk_hec', settings['ssl_ca'])
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
    # we want users to be able to provide different tokens per sourcetype if they want
    source_type = body['sourcetype'].split(':')[1]
    token_name = "token_#{source_type}"
    http = create_http(source_type)
    token = settings[token_name] || settings['token'] || raise(Puppet::Error, 'Must provide token parameter to splunk class')
    req = Net::HTTP::Post.new(@uri.path.to_str)
    req.add_field('Authorization', "Splunk #{token}")
    req.add_field('Content-Type', 'application/json')
    req.content_type = 'application/json'
    req.body = body.to_json
    http.request(req)
  end

  def store_event(event)
    host = event['host']
    epoch = event['time'].to_f

    timestamp = Time.at(epoch).to_datetime

    filename = timestamp.strftime("%F-%H-%M-%S-%L") + '.json'

    dir = File.join(Puppet[:reportdir], host)

    if ! Puppet::FileSystem.exist?(dir)
      FileUtils.mkdir_p(dir)
      FileUtils.chmod_R(0750, dir)
    end

    file = File.join(dir, filename)

    begin
      File.open(file,"w") do |f|
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
    if settings['record_event'] == 'true'
      result = true
    else
      result = false
    end
    result
  end

  # standard function to make sure we're using the same time format our sourcetypes are set to parse
  def sourcetypetime(timestamp)
    time = Time.parse(timestamp)
    "%10.3f" % time.to_f
  end
end
