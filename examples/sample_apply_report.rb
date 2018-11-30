{
host => opportunity.corp.puppetlabs.net, 
time => 2018-11-14T14:29:05.154512000+00:00, 
configuration_version => 1542205739, 
transaction_uuid => , 
catalog_uuid => d6e40e2b-6187-4bb1-834d-671830e5e051, 
code_id => , 
cached_catalog_status => not_used, 
report_format => 6, 
puppet_version => 4.10.9, 
kind => apply, 
status => changed, 
noop => false, 
noop_pending => false, 
environment => , 
master_used => , 
logs => [
  {
    level => notice, 
    message => hello, 
    source => Puppet, 
    tags => [notice], 
    time => 2018-11-14T14:29:05.396275000+00:00, 
    file => , 
    line => 
  }, 
  {
    level => notice, 
    message => defined 'message' as 'hello', 
    source => /Stage[main]/Main/Notify[hello]/message, 
    tags => [notice, notify, hello, class], 
    time => 2018-11-14T14:29:05.396400000+00:00, 
    file => /Users/cbarker/.puppetlabs/etc/code/modules/splunk_hec/plans/test.pp, 
    line => 5
  }, 
  {
    level => notice, 
    message => Applied catalog in 0.02 seconds, 
    source => Puppet, 
    tags => [notice], 
    time => 2018-11-14T14:29:05.406170000+00:00, 
    file => , line => 
  }
], 
metrics => {
  resources => {
    name => resources, 
    label => Resources, 
    values => [
      [total, Total, 1], 
      [skipped, Skipped, 0], 
      [failed, Failed, 0], 
      [failed_to_restart, Failed to restart, 0], 
      [restarted, Restarted, 0], 
      [changed, Changed, 1], 
      [out_of_sync, Out of sync, 1], 
      [scheduled, Scheduled, 0], 
      [corrective_change, Corrective change, 0]
    ]
  }, 
  time => {
    name => time, 
    label => Time, 
    values => [
      [notify, Notify, 0.000901],
      [config_retrieval, Config retrieval, 0], 
      [total, Total, 0.000901]
    ]
  },
  changes => {
    name => changes, 
    label => Changes, 
    values => [
      [total, Total, 1]
    ]
  }, 
  events => {
    name => events, 
    label => Events, 
    values => [
      [total, Total, 1], 
      [failure, Failure, 0], 
      [success, Success, 1]
    ]
  }
}, 
resource_statuses => {
  Notify[hello] => {
    title => hello, 
    file => /Users/cbarker/.puppetlabs/etc/code/modules/splunk_hec/plans/test.pp, 
    line => 5, 
    resource => Notify[hello], 
    resource_type => Notify, 
    containment_path => [Stage[main], Main, Notify[hello]], 
    evaluation_time => 0.000901, 
    tags => [notify, hello, class], 
    time => 2018-11-14T14:29:05.395629000+00:00, 
    failed => false, 
    changed => true, 
    out_of_sync => true, 
    skipped => false, 
    change_count => 1, 
    out_of_sync_count => 1, 
    events => [
      {
        audited => false, 
        property => message, 
        previous_value => absent, 
        desired_value => hello, 
        historical_value => , 
        message => defined 'message' as 'hello', 
        name => message_changed, 
        status => success, 
        time => 2018-11-14T14:29:05.396137000+00:00, 
        redacted => , 
        corrective_change => false
      }
    ], 
    corrective_change => false
  }
}, 
corrective_change => false
}
