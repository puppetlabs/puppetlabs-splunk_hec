# Simple class to manage your splunk_hec report processor
class splunk_hec (
  String $server,
  String $token,
  Optional[String] $puppetdb_callback_hostname = undef,
  Optional[Integer] $port = undef,
  Optional[Integer] $timeout = undef,
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
