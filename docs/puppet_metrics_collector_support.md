## Puppet Metrics Collector Support
-----------

This module can forward metrics collected by the [Puppet Metrics Collector](https://forge.puppet.com/puppetlabs/puppet_metrics_collector) module. To enable this, once reporting is working with this module and the Metrics Collector module is installed, set the `metrics_server_type` parameter in the puppet_metrics_collector to Splunk. For more information refer to the modules [documentation](https://forge.puppet.com/puppetlabs/puppet_metrics_collector#metrics-server-parameters). Version 6.0.0 or greater is required to send metric data to splunk.