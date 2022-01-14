## Customized Reporting

As of `0.8.0` and later the report processor can be configured to include [**Logs**](https://puppet.com/docs/puppet/latest/format_report.html#puppet::util::log) and [**Resource Events**](https://puppet.com/docs/puppet/latest/format_report.html#puppet::resource::status) along with the existing summary data. Because this data varies between runs and agents in Puppet, it is difficult to predict how much data you will use in Splunk as a result. However, this removes the need for configuring the **Detailed Report Generation** alerts in Splunk to retrieve that information; which may be useful for large installations that need to retrieve a large amount of data. You can now just send the information from Puppet directly.

Add one or more of these parameters based on the desired outcome, these apply to the state of the puppet runs. You cannot filter by facts on which nodes these are in effect for. As such, you can get ***logs when a puppet run fails***, but not *logs when a `windows` server puppet run fails*.

By default this type of reporting is not enabled.

**Parameters**:

##### event_types (Requires `puppetlabs-pe_event_forwarding` module)

`Array`: Determines which event types should be forwarded to Splunk. Default value includes all event types. This can be one, or any of the following:

  * `classifier`
  * `code-manager`
  * `orchestrator`
  * `pe-console`
  * `rbac`

##### include_logs_status

`Array`: Determines if [logs](https://puppet.com/docs/puppet/latest/format_report.html#puppet::util::log) should be included based on the return status of the puppet agent run. This can be none, one, or any of the following:

  * `failed`
  * `changed`
  * `unchanged`

##### include_logs_catalog_failure

`Boolean`: Include logs if a [catalog](https://puppet.com/docs/puppet/latest/subsystem_catalog_compilation.html) fails to compile. This is a more specific type of failure that indicates a server-side issue.

  * `true`
  * `false`

##### include_logs_corrective_change

`Boolean`: Include logs if a there is a [corrective change](https://puppet.com/docs/pe/latest/analyze_changes_across_runs.html) (a PE only feature) - indicating drift was detected from the last time puppet ran on the system.

  * `true`
  * `false`

##### include_resources_status

`Array`: Determines if [resource events](https://puppet.com/docs/puppet/latest/format_report.html#puppet::resource::status) should be included based on the return status of the puppet agent run. **Note**: This only includes resources whose status is not `unchanged` - not the entire catalog. The can be none, one, or any of the following:

  * `failed`
  * `changed`
  * `unchanged`

##### include_resources_corrective_change

`Boolean`: Include resource events if a there is a corrective change (a **PE only** feature) - indicating drift was detected from the last time puppet ran on the system.

  * `true`
  * `false`

##### summary_resources_format

`String`: If `include_resources_corrective_change` or `include_resources_status` is set and therefore `resource_events` are being sent as part of `puppet:summary` events, we can choose what format they should be sent in. Depending on your usage within Splunk, different formats may be preferable. The possible values are:

  * `hash` :: **Default Value**
  * `array`

Here is an example of the data that will be forwarded to Splunk in each instance:

**`hash`**:

```json
{
  "resource_events": {
    "File[/etc/something.conf]": {
      "resource": "File[/etc/something.conf]",
      "failed": false,
      "out_of_sync": true
    }
  }
}
```

**`array`**:

```json
{
  "resource_events": [
    {
      "resource": "File[/etc/something.conf]",
      "failed": false,
      "out_of_sync": true
    }
  ]
}
```
