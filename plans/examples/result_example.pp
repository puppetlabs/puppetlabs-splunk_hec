# An example of submitting a Task or Functions results to Splunk as a Task.
plan splunk_hec::examples::result_example {

  $result_ca = puppetdb_query('nodes [ certname ]{}')
  $ca = $result_ca.map |$r| { $r["certname"] }
  $pcpca = $ca.map |$n| { "pcp://${n}" }

  $results = run_task('package', $pcpca, action => status, name => 'splunkforwarder')

  $results.each |$result| {
    $node = $result.target.name
    if $result.ok {
      notice("${node} returned a value: ${result.value}")
      notice("sending ${node}'s report to splunk")
      $result_hash = {
        value => $result.value,
        target => $result.target.name,
      }
      run_task('splunk_hec::bolt_result', 'splunk_hec', result => $result_hash)
    } else {
      notice("${node} errored with a message: ${result.error}")
    }
  }
}
