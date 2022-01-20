## Fact Terminus Support

The `splunk_hec` module provides a fact terminus that will send a configurable set of facts to the same HEC that the report processor is using, with the `puppet:facts` source type.

  * Set the parameter `splunk_hec::manage_routes` to `true`.
    * In the PE console, this would be done by adding the `manage_routes` parameter in the node group configured with the `splunk_hec` class.
  * Run Puppet on the machines in that node group.
  * The `pe-puppetserver` service will restart once the new routes.yaml is deployed and configured.

To configure which facts to collect add the `collect_facts` parameter to the `splunk_hec` class and modify the array of facts presented.

  * To collect **all facts** available at the time of the Puppet run, add the special value `all.facts` to the `collect_facts` array.
  * When collecting **all facts**, you can configure the optional parameter `facts_blocklist` with an array of facts that should not be collected.

**Note**: The following facts are collected regardless as this data is utilized in a number of the dashboards in the Puppet Report Viewer:

```
'os'
'memory'
'puppetversion'
'system_uptime'
'load_averages
'ipaddress'
'fqdn'
'trusted'
'producer'
'environment'
```
