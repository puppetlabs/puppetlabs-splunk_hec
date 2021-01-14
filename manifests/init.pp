# Simple class to manage your splunk_hec connectivity
# note if you manage enable_reports, it will default to puppetdb,splunk_hec
# if you wish to add other reports, you can do so with the reports param
# note that you can have the module automatically add the splunk_hec reports
# processor by setting reports to '', the empty string.
class splunk_hec (
  String $url,
  String $token,
  Array $collect_facts = ["dmi","disks","partitions","processors","networking"],
  Boolean $enable_reports = false,
  Boolean $record_event = false,
  Boolean $manage_routes = false,
  String $facts_terminus = "puppetdb",
  String $facts_cache_terminus = "splunk_hec",
  Optional[String] $pe_username = undef,
  Optional[Sensitive[String]] $pe_password = undef,
  Optional[String] $pe_console = $settings::report_server,
  Optional[String] $reports = undef,
  Optional[Integer] $timeout = undef,
  Optional[String] $ssl_ca = undef,
  Optional[String] $token_summary = undef,
  Optional[String] $token_facts = undef,
  Optional[String] $token_metrics = undef,
  Optional[String] $url_summary = undef,
  Optional[String] $url_facts = undef,
  Optional[String] $url_metrics = undef,
  Optional[Array] $include_logs_status = undef,
  Optional[Boolean] $include_logs_catalog_failure = false,
  Optional[Boolean] $include_logs_corrective_change = false,
  Optional[Array] $include_resources_status = undef,
  Optional[Boolean] $include_resources_corrective_change = false,
  Optional[Boolean] $include_api_collection = false,
  String $summary_resources_format = 'hash',
) {

  # Account for the differences in Puppet Enterprise and open source
  if $facts['splunk_hec_is_pe'] {
    $ini_setting    = 'pe_ini_setting'
    $ini_subsetting = 'pe_ini_subsetting'
    $service        = 'pe-puppetserver'
    $owner          = 'pe-puppet'
    $group          = 'pe-puppet'
  }
  else {
    $ini_setting    = 'ini_setting'
    $ini_subsetting = 'ini_subsetting'
    $service        = 'puppetserver'
    $owner          = 'puppet'
    $group          = 'puppet'
  }

  if $include_api_collection {
    if ($pe_username == undef) or ($pe_password == undef) or ($pe_console == undef) {
      fail('pe_username, pe_password, and pe_console must all be set to use the api_collection feature.')
    }
    cron { 'collectpeapi':
      ensure  => 'present',
      command => "${settings::confdir}/splunk_hec_collect_api_events.rb",
      user    => 'root',
      minute  => '*/2',
      require => [File["${settings::confdir}/splunk_hec_collect_api_events.rb"]],
    }
    file { "${settings::confdir}/splunk_hec_collect_api_events.rb":
      ensure => file,
      owner  => $owner,
      group  => $group,
      mode   => '0755',
      source => 'puppet:///modules/splunk_hec/splunk_hec_collect_api_events.rb',
    }
  }

  if $enable_reports {
    if $reports != undef  {
      notify { "reports param deprecation warning" :
        message  => "The 'reports' parameter is being deprecated in favor of having the module automatically add the 'splunk_hec' setting \
        to puppet.conf. You can enable this behavior by setting 'reports' to '', the empty string, but please keep in mind that the \
        'reports' parameter will be removed in a future release.",
        loglevel =>  'warning',
      }

      Resource[$ini_setting] {'enable splunk_hec':
        ensure  => present,
        path    => '/etc/puppetlabs/puppet/puppet.conf',
        section => 'master',
        setting => 'reports',
        value   => $reports,
        notify  => Service[$service],
      }
    } else {
      # The subsetting resource automatically adds the 'splunk_hec' report
      # processor to the reports setting if it hasn't yet been added there.
      Resource[$ini_subsetting] { 'enable splunk_hec':
        ensure               => present,
        path                 => '/etc/puppetlabs/puppet/puppet.conf',
        section              => 'master',
        setting              => 'reports',
        subsetting           => 'splunk_hec',
        subsetting_separator => ',',
        notify               => Service[$service],
      }
    }
  }

  if $manage_routes {
    file { '/etc/puppetlabs/puppet/splunk_hec_routes.yaml':
      ensure  => file,
      owner   => $owner,
      group   => $group,
      mode    => '0640',
      content => epp('splunk_hec/splunk_hec_routes.yaml.epp'),
      notify  => Service[$service],
    }
    Resource[$ini_setting] {'enable splunk_hec_routes.yaml':
      ensure  => present,
      path    => '/etc/puppetlabs/puppet/puppet.conf',
      section => 'master',
      setting => 'route_file',
      value   => '/etc/puppetlabs/puppet/splunk_hec_routes.yaml',
      require => File['/etc/puppetlabs/puppet/splunk_hec_routes.yaml'],
      notify  => Service[$service],
    }
  }

  file { "${settings::confdir}/splunk_hec.yaml":
    ensure  => file,
    owner   => $owner,
    group   => $group,
    mode    => '0640',
    content => epp('splunk_hec/splunk_hec.yaml.epp'),
    notify  => Service[$service],
  }
}
