## Fact Terminus Support
-----------

The `splunk_hec` module provides a fact terminus that will send a configurable set of facts to the same HEC that the report processor is using, however as a `puppet:facts` sourcetype. This populates the Details and Inventory tabs in the Puppet Report Viewer. 

- Set the parameter `splunk_hec::manage_routes` to `true`. In the PE console, this would be by adding `manage_routes` in the `Classification -> PE Infrastructure -> Master -> Configuration` view under the `splunk_hec`
- Run Puppet on the machines in that node group
- PE PuppetServer will restart once the new routes.yaml is deployed and configured.
- To configure which facts to collect (such as custom facts) add the `collect_facts` parameter in the `splunk_hec` class and modify the array of facts presented. The following facts are collected regardless to ensure the functionality of the Puppet Report Viever:

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