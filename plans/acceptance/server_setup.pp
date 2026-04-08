# @summary Install PE Server
# @api private
#
# Install Puppet Server
#
# @example
#   splunk_hec::acceptance::server_setup
#
# @param [Optional[String]] puppet_version
#   Sets the version of Puppet Server to install
plan splunk_hec::acceptance::server_setup(
  Optional[String] $puppet_version = '2023.8.5',
  Optional[String] $splunk_url     = undef,
  Optional[String] $splunk_ip      = undef,
) {
  # machines are not yet ready at time of installing the puppetserver, so we wait 15s
  $localhost = get_targets('localhost')
  run_command('sleep 15', $localhost)

  if $puppet_version =~ /-nightly/ {
    run_plan(
      'splunk_hec::acceptance::oss_server_setup',
      'collection'  => $puppet_version,
      'splunk_url'  => $splunk_url,
      'splunk_ip'   => $splunk_ip,
    )
  } else {
    run_plan(
      'splunk_hec::acceptance::pe_server_setup',
      'version'    => $puppet_version,
      'splunk_url' => $splunk_url,
      'splunk_ip'  => $splunk_ip,
    )
  }
}
