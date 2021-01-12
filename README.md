puppet-splunk_hec
==============

#### Table of Contents

1. [Description](#description)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Tasks](#tasks)
5. [Events](#events)
6. [Advanced Topics](#advanced-topics)
7. [Known Issues](#known-issues)
8. [Breaking Changes](#breaking-changes)
9. [Release Process](#release-process)

## Description
-----------

This is a report processor & fact terminus for Puppet to submit data to Splunk's logging system using Splunk's [HTTP Event Collector](https://docs.splunk.com/Documentation/Splunk/8.0.1/Data/UsetheHTTPEventCollector) service. There is a complimentary app in SplunkBase called [Puppet Report Viewer](https://splunkbase.splunk.com/app/4413/) that generates useful dashboards and makes searching this data easier. The Puppet Report Viewer app should be installed in Splunk before configuring this module.

It is possible to only include data in reports based on specific conditions (Puppet Agent Run failure, compilation failure, change, etc.) See Customized-Reporting in the [Advanced Topics](#advanced-topics) section for details on using that.

To enable this module:
  - Classify your Puppet Servers with the splunk_hec class
  - Set the `url` parameter which refers to your Splunk url along with the token provided by Splunk
  - Set the `token` parameter which will be the HEC token you create in Splunk.
  - Set the `enable_reports` to true

This module sends data to Splunk by modifying your report processor settings and indirector routes.yaml.

To send Orchestrator jobs and Event activity to Splunk, follow the instructions in the [Events](#events) Section.

There are two Tasks included in this module, `splunk_hec:bolt_apply` and `splunk_hec:bolt_result`, that provide a pre-packaged way to compose Bolt Plans that submit data to Splunk every time they are run. Example plans are included which demonstrate task usage.

## Requirements
------------

* Puppet Enterprise or Open Source Puppet
* Splunk

This was tested on both Puppet Enterprise 2019.5.0 & Puppet 6, using stock gems of yaml, json, net::https

## Installation
--------------------

Instructions assume you are using Puppet Enterprise. For Open Source Puppet installations please see the Custom Installation page located in the [Advanced Topics](#advanced-topics) section.

1. Install the [Puppet Report Viewer](https://splunkbase.splunk.com/app/4413/) app in Splunk if not already installed
    * Please see [Splunk Installation](https://docs.splunk.com/Documentation/Splunk/8.0.3/SearchTutorial/InstallSplunk) if you need to install splunk
    * Alternatively you can install splunk via Bolt [Bolt Splunk Installation](https://forge.puppet.com/configuration-management/puppetlabs/deploy-splunk-enterprise-in-minutes)
2. Create an HEC token in Splunk
    1. Navigate to `Settings` > `Data Input` in your Splunk console
    2. Add a new `HTTP Event Collector` with a name of your choice
    3. Ensure `indexer acknowledgement` is not enabled
    4. Click Next and set the source type to Automatic.
    5. Ensure the `App Context` is set to `Puppet Report Viewer`
    6. Add the `main` index
    7. Set the Default Index to `main`
    8. Click Review and then Submit\
When complete the hec token should look something like this\
![hec_token](https://raw.githubusercontent.com/puppetlabs/puppetlabs-splunk_hec/v0.8.1/docs/images/hec_token.png)
3. Add the class `splunk_hec` to the PE Infrastructure -> PE Masters node group under Classification
    1. Install the `splunk_hec` module on your Puppet master
        * `puppet module install puppetlabs-splunk_hec --version 0.7.1`
    1. Navigate to `Classification` and expand the `PE Infrastructure` group in the PE console
    2. Select `PE Master` and then `Configuration`
    3. Add the `splunk_hec` class
    4. Enable these parameters:
        ```
        enable_reports = true
        manage_routes = true
        token = something like F5129FC8-7272-442B-983C-203F013C1948
        url = something like https://splunk-8.splunk.internal:8088/services/collector
        include_api_collection = true
        ```
    5. Hit save
    6. Run Puppet on the node group, this will cause a restart of the Puppet-Server service
4. Configure the Splunk Puppet Report Viewer with your HEC token like so\
![Puppet Report Viewer config](https://raw.githubusercontent.com/puppetlabs/puppetlabs-splunk_hec/v0.8.1/docs/images/puppet_report_viewer_config.png)
5. Log into the Splunk Console, search `index=* sourcetype=puppet:summary` and if everything was done properly, you should see the reports (and soon facts) from the systems in your Puppet environment

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

##### summary_resources_format

String: If `include_resources_corrective_change` or `include_resources_status` is set and therefore `resource_events` are being sent as part of `puppet:summary` events, we can choose what format they should be sent in. Depending on your usage within Splunk, different format may be preferable, the possible values are (`hash`, `array`). Default: `hash`. Here is an example of the data that will be forwarded to splunk in each instance:

`hash`

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

`array`

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

Events
-----------

The splunk_hec module allows the posting of PE orchestrator and activity service events to splunk.

#### Prerequisites

- To utilize the API collector, a user with the correct RBAC priviledges will
  need to be created. The User must have read access to the Orchestrator and Activity Service API's in Puppet Enterprise.
- The common events module will need to be installed. The instructions are below.

#### Configuration

1. From your PE console, set the `include_api_collection` parameter in the splunk_hec class to true.
2. Set the `pe_console` parameter to the url of the pe console you want to use.
3. Set the `pe_username` parameter to a pe user with read access to the Orchestrator and Activity Service API's in Puppet Enterprise.
4. Set the `pe_password` parameter to the password for the user above.

#### Installation

1. Ensure you have the latest version of the Puppet Report Viewer installed (Version 3.0.2 or higher) in your Splunk installation.
   - Here is the link: https://splunkbase.splunk.com/app/4413/
   - This will ensure that you have the needed source types to apply to your data in Splunk.
2. Configure the Splunk_hec class as described above.
3. Install the Common Events module.
   - Specify this module in your Puppetfile.
      ```
      mod 'common_events',
          :git => 'https://github.com/puppetlabs/puppetlabs-common_events'
      ```
4. Run `puppet agent -t`

The events now will be collected and posted to your Splunk Server. These events will appear in the Splunk UI.

There are two source types

```bash
puppet:events_summary
puppet:activity
```

#### Viewing the events

Use `source="puppet:events_summary"` in your Splunk search field to show the orchestrator events.

Use `source="puppet:activity"` in your Splunk search field to show the activity service events.


Advanced Settings
-----------

The splunk_hec module also supports customizing the `fact_terminus` and `facts_cache_terminus` names in the custom routes.yaml it deploys. If you are using a different facts_terminus (ie, not PuppetDB), you will want to set that parameter.

If you are already using a custom routes.yaml, these are the equivalent instructions of what the splunk_hec module does. The most important setting is configuring `cache: splunk_hec`
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

## Advanced Topics
------------
* [Custom Installation](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/custom_installation.md)
* [Advanced Puppet Configuration](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/advanced_puppet_configuration.md)
* [Advanced Splunk Configuration](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/advanced_splunk_configuration.md)
* [Customized Reporting](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/customized_reporting.md)
* [Fact Terminus Support](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/fact_terminus_support.md)
* [Puppet Metrics Collection](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/puppet_metrics_collector_support.md)
* [SSL Support](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/ssl_support.md)
* [Troublshooting and Verification](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/troubleshooting_and_verification.md)
* [Running the Tests](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/running_the_tests.md)

## Known Issues
------------
* Integration with puppet_metrics_collection only works on version >= 6.0.0
* SSL Validation is under active development and behavior may change
* Automated testing could use work

## Breaking Changes
-----------
- 0.5.0 splunk_hec::url parameter now expects a full URI of https://servername:8088/services/collector
- 0.5.0 -> 0.6.0 Switches to the fact terminus cache setting via routes.yaml to ensure compatibility with CD4PE, see Fact Terminus Support for guides on how to change it. Prior to deploying this module, remove the setting `facts_terminus` from the `puppet_enterprise::profile::master` class in the `PE Master` node group in your environment if you set it in previous revisions of this module (olders than 0.6.0). It will prevent PE from operating normally if left on.

## Release Process
------------
This module is hooked up with an automatic release process using github actions. To provoke a release simply check the module out locally, tag with the new release version, then github will promote the build to the forge.

Full process to prepare for a release:

Update metadata.json to reflect new module release version (0.8.1)
Run `bundle exec rake changelog` to update the CHANGELOG automatically
Submit PR for changes

Create Tag on target version:
```
git tag -a v0.8.1 -m "0.8.1 Feature Release"
git push upstream --tags
```

Authors
------

P.I.E. Team

P. uppet\
I. ntegrations\
E. ngineering

Chris Barker <cbarker@puppet.com>\
Helen Campbell <helen@puppet.com>\
Greg Hardy <greg.hardy@puppet.com>\
Bryan Jen <bryan.jen@puppet.com>\
Greg Sparks <greg.sparks@puppet.com>
