cron { 'collectpeapi':
  ensure  => 'present',
  command => '/etc/puppetlabs/code/environments/production/modules/splunk_hec/scripts/collect_api_events.rb',
  user    => 'root',
  minute  => '*/2',
}
