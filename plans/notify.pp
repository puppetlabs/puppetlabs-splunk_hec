plan splunk_hec::notify {
  
  # run a notify across the fleet via apply block

  $result_ca = puppetdb_query('nodes [ certname ]{}')
  $ca = $result_ca.map |$r| { $r["certname"] }
  $pcpca = $ca.map |$n| { "pcp://${n}" }

  apply_prep ($pcpca)

  $results = apply ($pcpca) {
    notify {"hello":}

  }

  $results.each |$result| {
    $node = $result.target.name
    if $result.ok {
      notice("${node} returned a value: ${result.report}")
      notice("sending ${node}'s report to splunk")
      splunk_hec::submit_report($result.report, $result.target.facts)
    } else {
      notice("${node} errored with a message: ${result.error}")
    }
  }


}
