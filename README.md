puppet-splunk_hec
==============

Description
-----------

This is a report processor designed to send a report summary of useful information to the [Splunk HTTP Endpoint Collector "HEC"](http://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector) service. These summaries are designed to be informative but also not too verbose to make logging a burden to the enderuser. The summaries are meant to be small but sufficient to determine if a puppet run was successful on a node, and to include metadata such as code-id,  transaction-id, and other details to allow for more detailed actions to be done.

It is best used the Splunk Addon [Puppet Report Viewer](https://splunkbase.splunk.com/app/4413/) which adds sourcetypes to make ingesting this data easier into Splunk (sourcetypes can be associated with specifc HEC tokens to make event viewing/processing easier). The Report Viewer also adds an actionable alert for Puppet Enterprise Users: using the data from a `puppet:summary` event, the Detailed Report Builder actionable alert will create a new event with the type of `puppet:detailed` containing information such as the node in questions facts, the resource_events from the node, and links to relavant reports in the Puppet Enterprise Console.

There are also two tasks included in this module, `splunk_hec:bolt_apply` and `splunk_hec:bolt_result` designed to provide similar data formats to allow for Bolt Plans to be written that submit data to Splunk. Also included are plans showing example useage of the tasks.


Requirements
------------

* Puppet or Puppet Enterprise
* Splunk

This was tested on both Puppet Enterprise 2018.1.4 & Puppet 6, using stock gems of yaml, json, net::https

Report Processor Installation & Usage
--------------------

The steps below will help one install and troubleshoot the report processor on a single Puppet Master, including manual steps to configure a puppet-server, and to use the included splunk_hec class.

1. Install the Puppet Report Viewer Addon in Splunk. This will import the needed sourcetypes that make setting up the HEC easier in the next steps, and also some overview dashboards that make it a lot easier to see if you're getting reports into Splunk.

2. Create a Splunk HEC Token (preferably named `puppet:summary` and using the sourcetype `puppet:summary` from the Report Viewer addon). Follow the steps provided by Splunk's [Getting Data In Guide](http://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector) if you are new to HTTP Endpoint Collectors.

3. Install this module in the environment your Puppet Server's are using (probably `production`)

4. Run `puppet plugin download` on your Puppet Master to sync the new 

(Step 5 and 6 are for testing/troubleshooting your configuration settings. Otherwise you can skip to step 7)

5. Create a `/etc/puppetlabs/puppet/splunk_hec.yaml` (see examples directory for one) adding your Splunk Server & Token from step 1
  - You can add 'timeout' as an optional parameter, default value is 2 for both open and read sessions, so take value x2 for real world use
  - The same is true for port, defaults to 8088 if none provided
  - Provide a 'puppetdb\_callback\_hostname' variable if the hostname that Splunk will use to lookup further information about a report is different than the puppetserver processing the reports (ie, multiple servers, load balancer, external dns name vs internal, etc.) Defaults to the certname of the puppetserver processing the report. This feature is yet to be enabled in the Puppet Report Viewer.

  ```
---
"server" : "splunk-dev.testing.internal"
"token" : "13311780-EC29-4DD0-A796-9F0CDC56F2AD"
```

6. Run `puppet apply -e 'notify { "hello world": }' --reports=splunk_hec` from the puppet server, this will load the report processor and test your configuration settings without actually modifying your puppet servers running configuration. If you are using the Puppet Report Viewer app in Splunk, you will see the page update with new data. If not, you will want to perform a search by the sourcetype you provided with your HEC configuration.

7. Provide the working parameters / values to the splunk_hec class and use it in a profile or add it to the PE Masters subgroup of PE Infrastructure in the classification section of the console. Run puppet on the MoM first (because it is the Puppet Server all the other compile masters are using) before running puppet on the other compile masters. This will restart the puppet-server processor, so stagger the runs to prevent an outage.

### Manual steps:

- Add `splunk_hec` to `/etc/puppetlabs/puppet/puppet.conf` reports line under the master's configuration block
```
[master]
node_terminus = classifier
storeconfigs = true
storeconfigs_backend = puppetdb
reports = puppetdb,splunk_hec
```

- Restart the puppet server process for it to reload the configuration and the plugin

- Run `puppet agent -t` somewhere, if you are using the suggested name, use `source="http:puppet-report-summary"` in your splunk search field to show the reports as they arrive


SSL Support
-----------
Configuring SSL support for this report processor and tasks requires that the Splunk HEC service being used has a [properly configured SSL certificate](https://docs.splunk.com/Documentation/Splunk/latest/Security/AboutsecuringyourSplunkconfigurationwithSSL). Once the HEC service has a valid SSL certificate, the CA will need to be made available to the report processor to load. One could add the CA to Puppet's trust, or just make the CA file available on the puppet-server (/etc/puppetlabs/puppet/splunk\_hec/splunk\_ca.cert works). Either option is supported.

One can update the splunk_hec.yaml file with the below settings


```
"ssl_verify" : "true"
"ssl_certificate" : "/etc/puppetlabs/puppet/splunk_hec/splunk_ca.cert"
```

Or create a profile that copies the splunk_ca.cert as part of invoking the splunk_hec class.

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

Tasks
-----

Two tasks are provided for submitting data from a Bolt plan to Splunk. It is suggested to use a different HEC token to distinguish between events from Puppet runs and those generated by Bolt. The Puppet Report Viewer addon includes a puppet:bolt sourcetype to faciltate this. Currently SSL validation for bolt communications to Splunk is not supported.

`splunk_hec::bolt_apply`: A task that uses the remote task option of Bolt to submit a Bolt Apply report in a similar format to the puppet:summary. Unlike the summary, this includes the facts from a target because those are available to bolt at execution time and added to the report data before submission to Splunk.

`splunk_hec::bolt_result`: A task that sends the result of a function to Splunk. Since the format is freeform and dependent on the individual function/tasks being called, formatting of the data is best done in the plan itself prior to submitting the result hash to the task. 

To setup, one needs to add the splunk_hec endpoint as a remote target in the inventory.yml:

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

See the plans/ directory for working examples of apply and result usage.




Known Issues
------------
* SSL Validation is under active development and behavior may change
* Automated testing could use work


Author
------
Chris Barker <cbarker@puppet.com>
