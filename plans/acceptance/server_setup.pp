# @summary Install PE Server
# @api private
#
# Install PE Server
#
# @example
#   pe_event_forwarding::acceptance::pe_server
#
# @param [Optional[String]] puppet_version
#   Sets the version of Puppet Server to install
plan splunk_hec::acceptance::server_setup(
  Optional[String] $puppet_version = '2019.8.7',
) {
  # machines are not yet ready at time of installing the puppetserver, so we wait 15s
  $localhost = get_targets('localhost')
  run_command('sleep 15s', $localhost)

  $puppet_server =  get_targets('*').filter |$n| { $n.vars['role'] == 'server' }

  wait_until_available($puppet_server)

  if $puppet_version =~ /puppet/ {
    run_plan(
      'splunk_hec::acceptance::oss_server_setup',
      'collection' => $puppet_version
    )
  } else {
    run_plan(
      'splunk_hec::acceptance::pe_server_setup',
      'version' => $puppet_version
    )
  }
}
