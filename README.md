puppet-splunk_hec
==============

Description
-----------

This is a report processor & fact terminus for Puppet to submit data to Splunk's logging system using Splunk's [HTTP Event Collector](https://docs.splunk.com/Documentation/Splunk/8.0.1/Data/UsetheHTTPEventCollector) service. There is a complimentary app in SplunkBase called [Puppet Report Viewer](https://splunkbase.splunk.com/app/4413/) that generates useful dashboards and makes searching this data easier. That app should be installed before configuring this module.

Previous versions of this module required that Splunk connect back to Puppet to retrieve information such as logs or resource events, because this module could only send a small amount of data. It is now possible to include that data in reports based on specific conditions (Puppet Agent Run failure, compilation failure, change, etc.) See [Customized Reporting](#customized-reporting) for details on using that.

Enabling this module is as simple as classifying your Puppet Server's with it and setting the Splunk HEC URL along with the token provided by Splunk. This module sends data to Splunk by modifying your report processor settings and indirector routes.yaml see the [tl,dr;](#installation-short-version) if that doesn't scare you. If it does, read the [longer instructions](#installation-long-version).

There are two Tasks included in this module, `splunk_hec:bolt_apply` and `splunk_hec:bolt_result` that provide similar data for Bolt Plans to submit data to Splunk. Also included are Plans showing example useage of the Tasks.


Requirements
------------

* Puppet or Puppet Enterprise
* Splunk

This was tested on both Puppet Enterprise 2018.1.4 & Puppet 6, using stock gems of yaml, json, net::https

Installation Short Version
--------------------

This assumes you are using Puppet Enterprise

1. Create an HEC token in Splunk, using the `puppet:summary` sourcetype, do not enable `indexer acknowledgement`
2. Add the class `splunk_hec` to the PE Infrastructure -> PE Masters node group under Classification
3. Enable these parameters:
```
enable_reports = true
manage_routes = true
token = something like F5129FC8-7272-442B-983C-203F013C1948
url = something like https://splunk-8.splunk.internal:8088/services/collector
```
4. Hit save
5. Run Puppet on the node group, this will cause a restart of the Puppet-Server service
6. Log into the Splunk Console, search `index=* sourcetype=puppet:summary` and if everything was done properly, you should see the reports (and soon facts) from the systems in your Puppet environment

Installation Long Version
--------------------

__If you are installing this module using a control-repo, you must have splunk_hec in your production environment's Puppetfile so the puppetserver process can load the libraries it needs properly. You can then create a feature branch to enable them and test the configuration, but the libraries must be in production otherwise the feature branch wont work as expected.__

The steps below will help install and troubleshoot the report processor on a single Puppet Master, including manual steps to configure a puppet-server, and to use the included splunk_hec class. Because one is modifying production machines, these steps allow you to validate your settings before deploying the changes live. See the tl,dr; instructions for 

1. Install the Puppet Report Viewer Addon in Splunk. This will import the needed sourcetypes to configure Splunk's HTTP Endpoint Collector (HEC) and provide a dashboard that will show the reports once they are sent to Splunk.

2. Create a Splunk HEC Token or use an existing one that sends to main index and does not have acknowledgement enabled. Follow the steps provided by Splunk's [Getting Data In Guide](http://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector) if you are new to HTTP Endpoint Collectors.

3. Install this Puppet module in the environment that manages your Puppet Servers are using (probably `production`)

4. Run `puppet plugin download` on your Puppet Server to sync the content

5. Create a `/etc/puppetlabs/puppet/splunk_hec.yaml` (see examples directory for one) adding your Splunk Server URL to the collector (usually something like `https://splunk-dev:8088/services/collector`) & Token from step 1
  - You can add 'timeout' as an optional parameter, default value is 1 second for both open and read sessions, so take value x2 for real world use
  - Provide a `pe_console` value that is the hostname for the Puppet Enterprise Console, which Splunk can use to lookup further information if the installation is a multimaster setup (it is best practice to set this if you're anticipating scaling out more masters in the future).

  ```
---
"url" : "https://splunk-dev.testing.local:8088/services/collector"
"token" : "13311780-EC29-4DD0-A796-9F0CDC56F2AD"
```

6. Run `puppet apply -e 'notify { "hello world": }' --reports=splunk_hec` from the Puppet Server, this will load the report processor and test your configuration settings without actually modifying your Puppet Server's running configuration. If you are using the Puppet Report Viewer app in Splunk then you will see the page update with new data. If not, perform a search by the sourcetype you provided with your HEC configuration.

7. If configured properly the Puppet Report Viewer app in Splunk will show 1 node in the Overview tab.

8. Now it is time to roll these settings out to the fleet of to the Puppet Masters in the installation. For Puppet Enterprise users: 
	- Navigate to Classification -> PE Infrastructure -> PE Master
	- Select Configuration
	- Press Refresh to ensure the splunk_hec class is loaded
	- Add new class `splunk_hec`
	- From the `Parameter name` select atleast `url` and `token` and provide the same attributes from the testing configuration file
	- Optionally set `enable_reports` to `true` if there isn't another component managing the servers reports setting, otherwise manually add `splunk_hec` to the settings as described in the manual steps
	- Commit changes and run Puppet. It is best to navigate to the PE Certificate Authority Classification gorup and run Puppet there first, before running Puppet on the remaining machines

9. For Inventory support in the Puppet Report Viewer, see the [Fact Terminus Support](#fact-terminus-support)

### Manual steps:

- Add `splunk_hec` to `/etc/puppetlabs/puppet/puppet.conf` reports line under the master's configuration block

```
[master]
node_terminus = classifier
storeconfigs = true
storeconfigs_backend = puppetdb
reports = puppetdb,splunk_hec
```

- Restart the puppet-server process for it to reload the configuration and the plugin

- Run `puppet agent -t` somewhere, if you are using the suggested name, use `source="http:puppet-report-summary"` in your Splunk search field to show the reports as they arrive


SSL Support
-----------
Configuring SSL support for this report processor and tasks requires that the Splunk HEC service being used has a [properly configured SSL certificate](https://docs.splunk.com/Documentation/Splunk/latest/Security/AboutsecuringyourSplunkconfigurationwithSSL). Once the HEC service has a valid SSL certificate, the CA will need to be made available to the report processor to load. The supported path is to install a copy of the Splunk CA to a directory called `/etc/puppetlabs/puppet/splunk_hec/` and provide the file name to `splunk_hec` class.

One can update the splunk_hec.yaml file with these settings:

```
"ssl_ca" : "splunk_ca.cert"
```

Or create a profile that copies the `splunk_ca.cert` as part of invoking the splunk_hec class:

```
class profile::splunk_hec {
  file { '/etc/puppetlabs/puppet/splunk_hec':
    ensure => directory,
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => 0644,
  }
  file { '/etc/puppetlabs/puppet/splunk_hec/splunk_ca.cert':
    ensure => file,
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0644',
    source => 'puppet:///modules/profile/splunk_hec/splunk_ca.cert',
  }
}
```

Customized Reporting
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

Fact Terminus Support
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

Puppet Metrics Collector Support
-----------

This module can forward metrics collected by the [Puppet Metrics Collector](https://forge.puppet.com/puppetlabs/puppet_metrics_collector) module. To enable this, once reporting is working with this module and the Metrics Collector module is installed, set the `metrics_server_type` parameter in the puppet_metrics_collector to Splunk. For more information refer to the modules [documentation](https://forge.puppet.com/puppetlabs/puppet_metrics_collector#metrics-server-parameters). As of this writing, there is a breaking change in 5.3.0, so splunk_hec requires 5.2.0 if one wants to send metric data to Splunk.

Advanced Settings:
-----------

The splunk_hec module also supports customizing the `fact_terminus` and `facts_cache_terminus` names in the custom routes.yaml it deploys. If you are using a different facts_terminus (ie, not PuppetDB), you will want to set that parameter.

If you are already using a custom routes.yaml, these are the equivalent instructions of what the splunk_hec module does, the most important setting is configuring `cache: splunk_hec`
- Create a custom splunk_routes.yaml file to override where facts are cached 
```yaml
master:
  facts:
    terminus: puppetdb
    cache: splunk_hec
```
- Set this routes file instead of the default one with `puppet config set route_file /etc/puppetlabs/puppet/splunk_routes.yaml --section master`


Tasks
-----

Two tasks are provided for submitting data from a Bolt plan to Splunk. For clarity, we recommend using a different HEC token to distinguish between events from Puppet runs and those generated by Bolt. The Puppet Report Viewer addon includes a puppet:bolt sourcetype to faciltate this. Currently SSL validation for Bolt communications to Splunk is not supported.

`splunk_hec::bolt_apply`: A task that uses the remote task option to submit a Bolt Apply report in a similar format to the puppet:summary. Unlike the summary, this includes the facts from a target because those are available to bolt at execution time and added to the report data before submission to Splunk.

`splunk_hec::bolt_result`: A task that sends the result of a function to Splunk. Since the format is freeform and dependent on the individual function/tasks being called, formatting of the data is best done in the plan itself prior to submitting the result hash to the task. 

To setup, add the splunk_hec endpoint as a remote target in `inventory.yml`:

```
---
nodes:
  - name: splunk_bolt_hec
    config:
      transport: remote
      remote:
        hostname: <hostname>
        token: <token>
        port: 8088
```

See the `plans/` directory for working examples of apply and result usage.


Advanced Splunk Configuration Options
-----------
The splunk_hec class and data processors support setting individual HEC tokens and URLs for each type of data supported. This is designed so users can specify a different HEC token if they wish their Puppet Reports are stored in a different index than their Facts, etc. Making changes here assumes you know how to use indexs and update the advanced search macros in Splunk so the Report Viewer can load data from those indexes.

- Summary Reports: Corresponds to puppet:summary in the Puppet Report Viewer, use `token_summary` and `url_summary` parameter or value in splunk_hec.yaml
- Fact Data: Corresponds to puppet:facts in the Puppet Report Viewer, use `token_facts` and `url_facts` parameter or value in splunk_hec.yaml
- PE Metrics: Corresponds to puppet:metrics in the Puppet Report Viewer, use `token_metrics` and `url_metrics` parameter or value in splunk_hec.yaml (at this time, collecting PE Metrics is not supported, but the sourcetype exists in the app)

Different URLs only need to be specified if different HEC systems entirely are being used. If one is using one collecter server, but multiple HECs, just provide the `url` setting as before, and specify each sourcetype's corresponding HEC token.


Troubleshooting and verification
-----------
Report processors and fact termini (what this module adds) run inside the Puppet Server process so that is where to look for logs. In a healthy system running 0.5.0 or later of this module, one will see something like this:
```
[cbarker@puppet ~]$ sudo tail -n 60 /var/log/puppetlabs/puppetserver/puppetserver.log | grep Splunk
2019-06-17T12:44:47.729Z INFO  [qtp1685349172-4356] [puppetserver] Puppet Submitting facts to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
2019-06-17T12:44:48.322Z INFO  [qtp1685349172-15004] [puppetserver] Puppet Submitting report to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
2019-06-17T12:45:25.913Z INFO  [qtp1685349172-28874] [puppetserver] Puppet Submitting facts to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
```

For older versions (splunk_hec older than 0.5.0) or if the fact terminus is not configured one would see:
```
[cbarker@puppet ~]$ sudo tail -n 60 /var/log/puppetlabs/puppetserver/puppetserver.log | grep Splunk
2019-06-17T12:48:21.646Z INFO  [qtp1685349172-4354] [puppetserver] Puppet Submitting report to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
2019-06-17T12:48:31.689Z INFO  [qtp1685349172-4354] [puppetserver] Puppet Submitting report to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
2019-06-17T12:49:22.881Z INFO  [qtp1685349172-4356] [puppetserver] Puppet Submitting report to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
```

If neither appear in the logs, then the puppetserver has yet to be configured, check the reports and routes settings for report processor and fact submission support respectively, this has to be checked on all puppet servers, including the Master of Masters, to ensure every puppet run is logged:
Reports enabled properly using the module:
```
[cbarker@puppet ~]$ sudo /opt/puppetlabs/bin/puppet config print reports --section master
puppetdb,splunk_hec
```
Facts enabled properly using the module:
```
[cbarker@puppet ~]$ sudo /opt/puppetlabs/bin/puppet config print route_file --section master
/etc/puppetlabs/puppet/splunk_hec_routes.yaml
```

To valid the reports are in Splunk properly, search all indexes for the source type 'puppet:summary' for reports, 'puppet:facts' for facts:
`index=* sourcetype=puppet:summary` and `index=* sourcetype=puppet:facts`

The number of events corresponds to the number of Puppet runs that have occured during that time period, not number of hosts. To verify all hosts in an environment have submitted facts/reports, one will need to dedup the events by host to get an accurate count, this is only worth doing after the module has been deployed for atleast an hour (or longer, depending on the Puppet run interval set in the environment). In the Splunk search view, set the time window to the last 60 minutes and use the following search, the resulting Event Count will match the number of nodes in the Puppet Enterprise console:
`index=* sourcetype=puppet:summary | dedup host`

If you are using multiple PE consoles (ie, multiple Puppet Enterprise installations), you will need to add an additional filter by pe_console value:
`index=* sourcetype=puppet:summary | pe_console=puppet.company.com | dedup host`

For troubleshooting detailed reports and display issues in the Splunk Console, please see the documentation for the [Puppet Report Viewer](https://github.com/puppetlabs/ta-puppet-report-viewer) if the above steps have demonstrated that the Reports and Facts are being sent to Splunk and stored appropriately in the right sourcetypes.

Known Issues
------------
* Integration with puppet_metrics_collection only works on version 5.2.0 currently, waiting on 5.4.0 release
* SSL Validation is under active development and behavior may change
* Automated testing could use work

Breaking Changes
-----------
- 0.5.0 splunk_hec::url parameter now expects a full URI of https://servername:8088/services/collector
- 0.5.0 -> 0.6.0 Switches to the fact terminus cache setting via routes.yaml to ensure compatibility with CD4PE, see Fact Terminus Support for guides on how to change it. Prior to deploying this module, remove the setting `facts_terminus` from the `puppet_enterprise::profile::master` class in the `PE Master` node group in your environment if you set it in previous revisions of this module (olders than 0.6.0). It will prevent PE from operating normally if left on.



Release Process
------------
This module is hooked up with an automatic release process using travis. To provoke a release simply check the module out locally, tag with the new release version, then travis will promote the build to the forge.

Full process to prepare for a release:

Update metadata.json to reflect new module release version (0.7.0)
Run `bundle exec rake changelog` to update the CHANGELOG automatically
Submit PR for changes

Create Tag on target version:
```
git tag -a v0.7.0 -m "0.7.0 Feature Release"
git push upstream --tags
```

Authors
------
P.uppet I.ntegrations E.ngineering Team

Chris Barker <cbarker@puppet.com>
Helen Campbell <helen@puppet.com>
Greg Hardy <greg.hardy@puppet.com>
Bryan Jen <bryan.jen@puppet.com>
