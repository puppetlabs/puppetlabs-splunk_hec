# @summary Simple class to manage your splunk_hec connectivity
#
# @note If you manage enable_reports, it will default to puppetdb,splunk_hec
#       If you wish to add other reports, you can do so with the reports param
#       That you can have the module automatically add the splunk_hec reports
#       processor by setting reports to '', the empty string.
#
# @example
#   include splunk_hec
#
# @param [String] url
#   The url of the server that PE is running on
# @param [String] token
#   The user token
# @param [Array] collect_facts
#   The list of facts that will be collected in the report
# @param [Boolean] enable_reports
#   Adds splunk_hec to the list of report processors
# @param [Boolean] record_event
#   If set to true, will call store_event and save report as json
# @param [Boolean] disabled
#   Disables the splunk_hec report processor
# @param [Boolean] manage_routes
#   When false, will not automatically send facts to splunk_hec
# @param [String] facts_terminus
#   Ensure that facts get saved to puppetdb
# @param [String] facts_cache_terminus
#   Makes sure that the facts get sent to splunk_hec
# @param [Optional[String]] reports
#   Can specify report processors (other than puppetdb which is default)
#   Deprecated; should not use (will give warning).
# @param [Optional[String]] pe_console
#   The FQDN for the PE console
# @param [Optional[Integer]] timeout
#   Timeout limit for for both open and read sessions
# @param [Optional[String]] ssl_ca
#   The name of the ca certification/bundle for ssl validation of the splunk_hec endpoint
# @param [Optional[Boolean]] ignore_system_cert_store
#   By default, the certificate provided to the ssl_ca parameter is a supplement
#   to the system ca certificate store. If that cert store contains invalid
#   certificates, ssl validation could fail. Set this parameter to true to
#   ignore those certificates and use only the provided file.
# @param [Optional[String]] token_summary
#   Corresponds to puppet:summary in the Puppet Report Viewer
#   When storing summary in a different index than the default token
# @param [Optional[String]] token_facts
#   Corresponds to puppet:facts in the Puppet Report Viewer
#   When storing facts in a different index than the default token
# @param [Optional[String]] token_metrics
#   Corresponds to puppet:metrics in the Puppet Report Viewer
#   When storing metrics in a different index than the default token
# @param [Optional[String]] url_summary
#   Similar to token_summary; used to store summary in a different index than the default url
# @param [Optional[String]] url_facts
#   Similar to token_facts; used to store facts in a different index than the default url
# @param [Optional[String]] url_metrics
#   Similar to token_metrics; used to store metrics in a different index than the default url
# @param [Optional[Array]] include_logs_status
#   Determines if puppet logs should be included based on the return status of the puppet agent run
#   Can be none, one, or any of the following: failed, changed, unchanged
# @param [Optional[Boolean]] include_logs_catalog_failure
#   Include logs if catalog fails to compile
# @param [Optional[Boolean]] include_logs_corrective_change
#   Include logs if there is a corrective change
#   Only a PE feature
# @param [Optional[Array]] include_resources_status
#   Determines if resource events should be included based on return status of puppet agent run
#   Does not include 'unchanged' status reports
#   Allowed values are: failed, changed, unchanged
# @param [Optional[Boolean]] include_resources_corrective_change
#   Include resource events if there is a corrective change
#   Only a PE feature
# @param [String] summary_resources_format
#   If include_resource_corrective_change or include_resources_status is set and thus resource_events
#   are being sent as part of puppet:summary events, then can choose format.
#   Allowed values are: 'hash', 'array'
class splunk_hec (
  String $url,
  String $token,
  Array $collect_facts                                   = ["dmi","disks","partitions","processors","networking"],
  Boolean $enable_reports                                = false,
  Boolean $record_event                                  = false,
  Boolean $disabled                                      = false,
  Boolean $manage_routes                                 = false,
  Boolean $events_reporting_enabled                      = false,
  String $facts_terminus                                 = "puppetdb",
  String $facts_cache_terminus                           = "splunk_hec",
  Optional[String] $reports                              = undef,
  Optional[String] $pe_console                           = $settings::report_server,
  Optional[Integer] $timeout                             = undef,
  Optional[String] $ssl_ca                               = undef,
  Optional[Boolean] $ignore_system_cert_store            = false,
  Optional[String] $token_summary                        = undef,
  Optional[String] $token_facts                          = undef,
  Optional[String] $token_metrics                        = undef,
  Optional[String] $url_summary                          = undef,
  Optional[String] $url_facts                            = undef,
  Optional[String] $url_metrics                          = undef,
  Optional[Array] $include_logs_status                   = undef,
  Optional[Boolean] $include_logs_catalog_failure        = false,
  Optional[Boolean] $include_logs_corrective_change      = false,
  Optional[Array] $include_resources_status              = undef,
  Optional[Boolean] $include_resources_corrective_change = false,
  String $summary_resources_format                       = 'hash',
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

  if $events_reporting_enabled {
    $confdir_base_path = pe_event_forwarding::base_path($settings::confdir, undef)

    file { "${confdir_base_path}/pe_event_forwarding/processors.d/splunk_hec":
      ensure  => directory,
      owner   => $owner,
      group   => $group,
      require => [
        Class['pe_event_forwarding'],
        File["${settings::confdir}/splunk_hec.yaml"]
      ]
    }

    file { "${confdir_base_path}/pe_event_forwarding/processors.d/splunk_hec/util_splunk_hec.rb":
      ensure  => file,
      owner   => $owner,
      group   => $group,
      mode    => '0755',
      content => template('splunk_hec/util_splunk_hec.erb'),
      require => File["${confdir_base_path}/pe_event_forwarding/processors.d/splunk_hec"]
    }

    file { "${confdir_base_path}/pe_event_forwarding/processors.d/splunk_hec.rb":
      ensure  => file,
      owner   => $owner,
      group   => $group,
      mode    => '0755',
      source  => 'puppet:///modules/splunk_hec/splunk_hec.rb',
      require => File["${confdir_base_path}/pe_event_forwarding/processors.d/splunk_hec/util_splunk_hec.rb"]
    }
  }
}
