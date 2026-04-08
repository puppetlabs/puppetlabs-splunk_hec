# @summary Install PE Server
# @api private
#
# Install PE Server
#
# @example
#   splunk_hec::acceptance::pe_server_setup
#
# @param [Optional[String]] version
#   Sets the version of the PE to install
# @param [Optional[Hash]] pe_settings
#   Sets PE settings including password
plan splunk_hec::acceptance::pe_server_setup(
  Optional[String] $version     = '2023.8.7',
  Optional[Hash]   $pe_settings = { password => 'puppetlabsPi3!', configure_tuning => false },
  Optional[String] $splunk_url  = undef,
  Optional[String] $splunk_ip   = undef,
) {
  # machines are not yet ready at time of installing the puppetserver, so we wait 15s
  $localhost = get_targets('localhost')
  run_command('sleep 15', $localhost)

  # identify pe server node
  $puppet_server = get_targets('*').filter |$n| { $n.vars['role'] == 'server' }

  # extract pe version from matrix_from_metadata_v3 output (e.g. 2023.8.5-puppet_enterprise -> 2023.8.5)
  $pe_version = regsubst($version, '-puppet_enterprise', '')

  # Set up each server node in parallel. Each may be a different platform so the
  # installer URL is resolved per-target from its inventory facts.
  $futures = $puppet_server.map |$server| {
    background("set up PE on ${server.name}") || {
      $platform = $server.facts['platform']

      $platform_tag = case $platform {
        /rhel-(\d+)/:          { "el-${1}-x86_64" }
        /redhat-(\d+)/:        { "el-${1}-x86_64" }
        /almalinux-(\d+)/:     { "el-${1}-x86_64" }
        /rocky-linux-(\d+)/:   { "el-${1}-x86_64" }
        /ubuntu-(\d\d)(\d\d)/: { "ubuntu-${1}.${2}-amd64" }
        /sles-(\d+)/:          { "sles-${1}-x86_64" }
        default: { fail("Unknown platform for PE install: ${platform}") }
      }

      $installer_url = "https://pm.puppetlabs.com/puppet-enterprise/${pe_version}/puppet-enterprise-${pe_version}-${platform_tag}.tar.gz"

      run_task(
        'splunk_hec::install_pe',
        $server,
        url              => $installer_url,
        console_password => $pe_settings['password'],
      )

      # pin the Splunk hostname in /etc/hosts so cert SAN validation works
      if $splunk_url and $splunk_ip {
        $splunk_host = regsubst($splunk_url, '^https?://', '')
        run_command("echo '${splunk_ip} ${splunk_host}' >> /etc/hosts", $server)
      }

      run_command('puppet agent -t', $server, '_catch_errors' => true)

      # create the RBAC token for integration testing against pe_event_forwarding
      run_command("echo '${pe_settings['password']}' | puppet access login --username admin --lifetime 12h", $server)
    }
  }
  wait($futures)
}
