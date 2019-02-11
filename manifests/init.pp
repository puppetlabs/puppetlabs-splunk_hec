# Simple class to manage your splunk_hec report processor
class splunk_hec (
  String $server,
  String $token,
  Optional[String] $puppetdb_callback_hostname = undef,
  Optional[Integer] $port = undef,
  Optional[Integer] $timeout = undef,
  Optional[Boolean] $ssl_verify = False,
  Optional[Boolean] $ssl_download_cert = False,
  Optional[String] $ssl_certificate = undef,
) {

  if $ssl_download_cert {

    if $port {
      $ssl_port = $port
    }
    else {
      $ssl_port = '443'
    }

    $ssl_download_server = "${server}:${ssl_port}"
    $ssl_download_path = "/etc/puppetlabs/puppet/splunk_hec/${ssl_certificate}.pem"

    file { '/etc/puppetlabs/puppet/splunk_hec/':
      ensure => directory,
      owner  => 'pe-puppet',
      group  => 'pe-puppet',
      mode   => '0640',
      before => Exec["Downloading Splunk's ${ssl_certificate}"],
    }

    exec { "Downloading Splunk's ${ssl_certificate}":
      command => "/usr/bin/openssl s_client -showcerts -connect ${ssl_download_server} </dev/null 2>/dev/null | /usr/bin/openssl x509 -outform PEM >${ssl_download_path}",
      creates => $ssl_download_path,
    }
  }

  file { '/etc/puppetlabs/puppet/splunk_hec.yaml':
    ensure  => file,
    owner   => pe-puppet,
    group   => pe-puppet,
    mode    => '0640',
    content => epp('splunk_hec/splunk_hec.yaml.epp'),
    notify  => Service['pe-puppetserver']
  }
}
