# Simple class to manage your splunk_hec connectivity
# note if you manage enable_reports, it will default to puppetdb,splunk_hec
# if you wish to add other reports, you can do so with the reports param
class splunk_hec (
  String $url,
  String $token,
  Array $collect_facts = ["dmi","disks","partitions","processors","networking"],
  Boolean $enable_reports = false,
  Boolean $record_event = false,
  String $reports = "puppetdb,splunk_hec",
  Optional[String] $pe_console = undef,
  Optional[Integer] $timeout = undef,
  Optional[String] $ssl_ca = undef,
) {

  if $enable_reports {
    pe_ini_setting {'enable splunk_hec':
      ensure  => present,
      path    => '/etc/puppetlabs/puppet/puppet.conf',
      section => 'master',
      setting => 'reports',
      value   => $reports,
      notify  => Service['pe-puppetserver'],
    }
  }

  file { '/etc/puppetlabs/puppet/splunk_hec.yaml':
    ensure  => file,
    owner   => pe-puppet,
    group   => pe-puppet,
    mode    => '0640',
    content => epp('splunk_hec/splunk_hec.yaml.epp'),
    notify  => Service['pe-puppetserver'],
  }
}
