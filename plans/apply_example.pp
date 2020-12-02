plan splunk_hec::apply_example (
  Optional[String[1]] $plan_guid,
  Optional[String[1]] $plan_name,
) {

  # Example of submitting the report from a bolt apply block to Splunk
  # users PE for pcp/hosts

  $result_ca = puppetdb_query('nodes [ certname ]{}')
  $ca = $result_ca.map |$r| { $r["certname"] }
  $pcpca = $ca.map |$n| { "pcp://${n}" }

  apply_prep ($pcpca)

  $results = apply ($pcpca) {
    include ntp
    notify {'hello config test':}

  }

  $results.each |$result| {
    $node = $result.target.name
    if $result.ok {
      #notice("${node} returned a value: ${result.report}")
      notice("sending ${node}'s report to splunk")
      # this will use facts[clientcert] because we don't pass host
      run_task('splunk_hec::bolt_apply', 'splunk_hec',
        report    => $result.report,
        facts     => $result.target.facts,
        plan_guid => $plan_guid,
        plan_name => $plan_name
      )
      # this will set host to $node value - note: this will include the URI of pcp://$name vs $name as result from $clientcert value
      # run_task("splunk_hec::bolt_apply", 'splunk_bolt_apply', report => $result.report, facts => $result.target.facts, host => $node)
    } else {
      notice("${node} errored with a message: ${result.error}")
    }
  }


}
