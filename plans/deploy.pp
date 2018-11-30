plan splunk_hec::deploy {

  # Lets find the CA's first
  $result_ca = puppetdb_query('resources[certname] { type = "Class" and title = "Puppet_enterprise::Profile::Certificate_authority"}')
  $ca = $result_ca.map |$r| { $r["certname"] }
  $pcpca = $ca.map |$n| { "pcp://${n}" }

  # Now we find the compile masters
  $result_master = puppetdb_query('resources[certname] { (type = "Class" and title = "Puppet_enterprise::Profile::Master") and !(type = "Class" and title = "Puppet_enterprise::Profile::Certificate_authority")}')
  $masters = $result_master.map |$r| { $r["certname"] }
  $pcpmasters = $masters.map |$n| { "pcp://${n}" }

  run_command('/opt/puppetlabs/bin/puppet agent --onetime --no-usecacheonfailure --no-daemonize --no-splay', $pcpca, '_concurrency' => '1')
  run_command('/opt/puppetlabs/bin/puppet agent --onetime --no-usecacheonfailure --no-daemonize --no-splay', $pcpmasters, '_concurrency' => '1')

}
