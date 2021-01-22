node default {
  # This is where you can declare classes for all nodes.
  # Example:
  #   class { 'my_class': }

  class { 'splunk_hec':
    url                    => 'http://localhost:8088/services/collector/event',
    splunk_token           => 'abcd1234',
    pe_console             => 'https://localhost',
    record_event           => true,
    pe_username            => 'admin',
    pe_password            => Sensitive('pie'),
    include_api_collection => true,
  }
}
