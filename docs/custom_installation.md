## Custom Installation
--------------------

__If you are installing this module using a control-repo, you must have splunk_hec in your production environment's Puppetfile so the puppetserver process can load the libraries it needs properly. You can then create a feature branch to enable them and test the configuration, but the libraries must be in production otherwise the feature branch won't work as expected. If your puppetserver is in a different environment, please add this module to the Puppetfile in that environment as well.__

The steps below will help install and troubleshoot the report processor on a single Puppet Master, including manual steps to configure a puppet-server, and to use the included splunk_hec class. Because one is modifying production machines, these steps allow you to validate your settings before deploying the changes live. See the tl,dr; instructions for 

1. Install the Puppet Report Viewer Addon in Splunk. This will import the needed sourcetypes to configure Splunk's HTTP Endpoint Collector (HEC) and provide a dashboard that will show the reports once they are sent to Splunk.

2. Create a Splunk HEC Token or use an existing one that sends to main index and does not have acknowledgement enabled. Follow the steps provided by Splunk's [Getting Data In Guide](http://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector) if you are new to HTTP Endpoint Collectors.

3. Install this Puppet module in the environment that manages your Puppet Servers are using (probably `production`)

4. Run `puppet plugin download` on your Puppet Server to sync the content. Some users with strict permissions may need to run `umask 022` first

5. Create a `/etc/puppetlabs/puppet/splunk_hec.yaml` (see examples directory for one) adding your Splunk Server URL to the collector (usually something like `https://splunk-dev:8088/services/collector`) & Token from step 1
  - You can add 'timeout' as an optional parameter, default value is 1 second for both open and read sessions, so take value x2 for real world use
  - Provide a `pe_console` value that is the hostname for the Puppet Enterprise Console, which Splunk can use to lookup further information if the installation is a multimaster setup (it is best practice to set this if you're anticipating scaling out more masters in the future).

  ```
---
"url" : "https://splunk-dev.testing.local:8088/services/collector"
"token" : "13311780-EC29-4DD0-A796-9F0CDC56F2AD"
```
(Note: If HA is enabled you will need to ensure these settings exist in each master. This is often done through the PE HA Replica node group.)

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

9. For Inventory support in the Puppet Report Viewer, see the [Fact Terminus Support](fact_terminus_support.md)

### Manual steps:

- Add `splunk_hec` to `/etc/puppetlabs/puppet/puppet.conf` reports line under the master's configuration block

```
[master]
node_terminus = classifier
storeconfigs = true
storeconfigs_backend = puppetdb
reports = puppetdb,splunk_hec
```

- Restart the pe-puppetserver process (puppet-server for Open Source Puppet) for it to reload the configuration and the plugin

- Run `puppet agent -t` on an agent, if you are using the suggested name, use `source="http:puppet-report-summary"` in your Splunk search field to show the reports as they arrive

