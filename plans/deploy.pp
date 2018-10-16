plan splunk_hec::deploy {

  # query to get CA 'resources[certname] { type = "Class" and title = "Puppet_enterprise::Profile::Certificate_authority"}'
  $result_ca = puppetdb_query('resources[certname] { type = "Class" and title = "Puppet_enterprise::Profile::Certificate_authority"}')
  $ca = $result_ca.map |$r| { $r["certname"] }
  $pcpca = $ca.map |$n| { "pcp://${n}" }

  # query to get other masters 'resources[certname] { type = "Class" and title = "Puppet_enterprise::Profile::Master"}'
  $result_master = puppetdb_query('resources[certname] { type = "Class" and title = "Puppet_enterprise::Profile::Master"}')
  $masters = $result_master.map |$r| { $r["certname"] }
  $pcpmasters = $masters.map |$n| { "pcp://${n}" }

  run_command('/opt/puppetlabs/bin/puppet agent -t', $pcpca)
  run_command('/opt/puppetlabs/bin/puppet agent -t', $pcpmasters)

}
