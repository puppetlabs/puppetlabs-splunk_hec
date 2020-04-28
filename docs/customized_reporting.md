## Customized Reporting
----------
As of 0.8.0 and later the report processor can be configured to include Logs and Resource Events along with the existing summary data. Because this data varies between runs and agents in Puppet, it is difficult to predict how much data one will use in Splunk as a result. However this removes the need for configuring the Detailed Report Generation alerts in Splunk to retrieve that information, which is useful for large installations that need to retrieve a large amount of data. You can now just send the information from Puppet directly.

Add one or more of these parameters based on the desired outcome, these apply to the state of the puppet runs, one cannot filter by facts on which nodes these are in effect for. So one can get `logs when a puppet run fails`, but not `logs when a windows server puppet run fails`. By default none of these are enabled.

##### include_logs_status

Array: Determines if [logs](https://puppet.com/docs/puppet/latest/format_report.html#puppet::util::log) should be included based on the return status of the puppet agent run. The can be none, one, or any of the following: `failed changed unchanged`

##### include_logs_catalog_failure

Boolean: Include logs if a catalog fails to compile. This is a more specific type of failure that indicates a serverside issue. Values: `true false`

##### include_logs_corrective_change

Boolean: Include logs if a there is a corrective change (a PE only feature) - indicating drift was detected from the last time puppet ran on the system. Values: `true false`

##### include_resources_status

Array: Determines if [resource events](https://puppet.com/docs/puppet/latest/format_report.html#puppet::resource::status) should be included based on the return status of the puppet agent run. Note: this only includes resources whose status is not `unchanged` - not the entire catalog. The can be none, one, or any of the following: `failed changed unchanged`

##### include_resources_corrective_change

Boolean: Include resource events if a there is a corrective change (a PE only feature) - indicating drift was detected from the last time puppet ran on the system. Values: `true false`