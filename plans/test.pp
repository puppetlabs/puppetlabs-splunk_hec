# 
plan splunk_hec::test {

  $results = apply ('localhost') {
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
