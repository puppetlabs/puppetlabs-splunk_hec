# This plan installs open source Puppet adds Puppet to the path variable, and
# adds a puppet hosts entry. It also restarts the Puppet service and starts a
# puppet agent run.
# @summary Installs open source Puppet.
# @api private
#
# @param [Optional[String]] collection
#   puppet version collection name
plan splunk_hec::acceptance::oss_server_setup(
  Optional[String] $collection = 'puppet7'
) {
  # get server
  $server = get_targets('*').filter |$n| { $n.vars['role'] == 'server' }
  $localhost = get_targets('localhost')

  # get facts
  $puppetserver_facts = facts($server[0])
  $platform = $puppetserver_facts['platform']

  # machines are not yet ready at time of installing the puppetserver, so we wait 15s
  run_command('sleep 15', $localhost)

  # install puppetserver and start on master
  run_task(
    'provision::install_puppetserver',
    $server,
    'install and configure server',
    { 'collection' => $collection, 'platform' => $platform }
  )

  $os_name = $puppetserver_facts['provisioner'] ? {
    'docker' => split($puppetserver_facts['platform'], Regexp['[/:-]'])[1],
    'docker_exp' => split($puppetserver_facts['platform'], Regexp['[/:-]'])[1],
    default => split($puppetserver_facts['platform'], Regexp['[/:-]'])[0]
  }

  $os_family = $os_name ? {
    /(^redhat|rhel|centos|scientific|oraclelinux)/ => 'redhat',
    /(^debian|ubuntu)/ => 'debian',
    default => 'unsupported'
  }

  if $os_family == 'unsupported' {
    fail_plan('Not supported platform!')
  }

  if $os_family == 'debian' {
    run_task('provision::fix_secure_path', $server, 'fix secure path')
  }

  run_command('echo "export PATH=$PATH:/opt/puppetlabs/bin" > /etc/environment', $server)
  run_command('echo "127.0.0.1 puppet" >> /etc/hosts', $server)

  $fqdn = run_command('facter fqdn', $server).to_data[0]['value']['stdout']
  run_task('puppet_conf', $server, action => 'set', section => 'main', setting => 'server', value => $fqdn)

  run_command('systemctl start puppetserver', $server, '_catch_errors' => true)
  run_command('systemctl enable puppetserver', $server, '_catch_errors' => true)
  run_command('puppet agent -t', $server, '_catch_errors' => true)
}
