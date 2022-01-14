## Puppet Metrics Collector Support

This module can be utilized in conjunction with the [Puppet Metrics Collector](https://forge.puppet.com/puppetlabs/puppet_metrics_collector) module to populate the dashboards in the Metrics tab of the Puppet Report Viewer app.

To enable this, once reporting is working with this module and the Metrics Collector module installed, set the `puppet_metrics_collector::metrics_server_type` parameter to `splunk_hec`.

---

> In PE **2019.8.7+**, with `splunk_hec` and the Puppet Report Viewer properly configured, you will want to configure the following parameters within the `puppet_enterprise` class in the **PE Infrastructure** node group:

>  * `puppet_enterprise::enable_metrics_collection: true`
>  * `puppet_enterprise::enable_system_metrics_collection: true`

>In your hiera data you will then want to configure the `metrics_server_type` parameter:

>  * `puppet_metrics_collector::metrics_server_type: ‘splunk_hec’`

---

For more information please refer to the metrics collectors [documentation](https://forge.puppet.com/modules/puppetlabs/puppet_metrics_collector#metrics_server_type).