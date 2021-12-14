# @summary Install PE Server
# @api private
#
# Install PE Server
#
# @example
#   pe_event_forwarding::acceptance::pe_server_setup
#
# @param [Optional[String]] version
#   Sets the version of the PE to install
# @param [Optional[Hash]] pe_settings
#   Sets PE settings including password
plan splunk_hec::acceptance::pe_server_setup(
  Optional[String] $version = '2019.8.7',
  Optional[Hash] $pe_settings = {password => 'puppetlabs'}
) {
  # machines are not yet ready at time of installing the puppetserver, so we wait 15s
  $localhost = get_targets('localhost')
  run_command('sleep 15s', $localhost)

  #identify pe server node
  $puppet_server =  get_targets('*').filter |$n| { $n.vars['role'] == 'server' }

  # install pe server
  run_plan(
    'deploy_pe::provision_master',
    $puppet_server,
    'version' => $version,
    'pe_settings' => $pe_settings
  )

  $cmd = @("CMD")
          puppet infra console_password --password=pie
          echo 'pie' | puppet access login --lifetime 1y --username admin
          puppet infrastructure tune | sed "s,\\x1B\\[[0-9;]*[a-zA-Z],,g" > /etc/puppetlabs/code/environments/production/data/common.yaml
          puppet agent -t
          | CMD

  $infra_command_result = run_command($cmd, $puppet_server, '_catch_errors' => true)
  out::message(run_command('puppet facts | grep fips', $puppet_server))
}
