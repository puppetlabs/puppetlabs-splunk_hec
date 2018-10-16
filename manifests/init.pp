class splunk_hec (
  String $server,
  String $token,
  Optional[String] $puppetdb_callback_hostname,
  Optional[Integer] $port,
  Optional[Integer] $timeout,
) {

  file { '/etc/puppetlabs/puppet/splunk_hec.yaml':
    ensure  => file,
    owner   => pe-puppet,
    group   => pe-puppet,
    mode    => '0640',
    content => epp('splunk_hec/splunk_hec.yaml.epp'),
    notify  => Service['pe-puppetserver']
  }

}
