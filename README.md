# splunk_hec

##### Table of Contents

1. [Overview](#overview)
2. [Requirements](#requirements)
3. [Installation](#installation)
4. [Custom Installation](#custom-installation)
5. [SSL Configuration](#ssl-configuration)
6. [Customized Reporting](#customized-reporting)
7. [Events](#events)
8. [Tasks](#tasks)
9. [Advanced Settings](#advanced-settings)
10. [Advanced Topics](#advanced-topics)
11. [Known Issues](#known-issues)
12. [Breaking Changes](#breaking-changes)
13. [Release Process](#release-process)

## Overview

This is a report processor & fact terminus for Puppet to submit data to Splunk's logging system using Splunk's [HTTP Event Collector](https://docs.splunk.com/Documentation/Splunk/8.0.1/Data/UsetheHTTPEventCollector) service. There is a complimentary app in SplunkBase called [Puppet Report Viewer](https://splunkbase.splunk.com/app/4413/) that generates useful dashboards and makes searching this data easier. Please note that the Puppet Report Viewer app should be installed in Splunk before configuring this module.

There is also the [Puppet Alert Actions](https://splunkbase.splunk.com/app/4928/) app, which contains the alert actions that were previously shipped in the Puppet Report Viewer:

> The Puppet Alert Actions app allows you to run custom Tasks in Puppet Enterprise or retrieve detailed Report information about a particular Puppet Event that would be sent to the Puppet Report Viewer. For additional information on configuring Puppet Alert Actions, please see our documentation located [here](https://github.com/puppetlabs/TA-puppet-alert-actions).

It is possible to only include data in reports based on specific conditions (Puppet Agent Run failure, compilation failure, change, etc.) See the [Customized Reporting](#customized-reporting) section for details on using that.

To enable this module:

  * Classify your Puppet Servers with the `splunk_hec` class.
  * Set the `url` parameter which refers to your Splunk url.
  * Set the `splunk_token` parameter which will be the HEC token you create in Splunk.
  * Set the `enable_reports` parameter to **true**.

This module sends data to Splunk by modifying your report processor settings and indirector `routes.yaml`.

To send Orchestrator jobs and Event activity to Splunk, follow the instructions in the [Events](#events) Section.

There are two Tasks included in this module, `splunk_hec:bolt_apply` and `splunk_hec:bolt_result`, that provide a pre-packaged way to compose Bolt Plans that submit data to Splunk every time they are run. Example plans are included which demonstrate task usage.

## Requirements

* Puppet Enterprise (PE) or Open Source Puppet
* Splunk

This was tested on both PE 2019.8.1 & Puppet 6, using stock gems of `yaml`, `json`, and `net::https`.

## Installation

Instructions assume you are using Puppet Enterprise. For Open Source Puppet installations please see the [Custom Installation](#custom-installation) section.

1. Install the [Puppet Report Viewer](https://splunkbase.splunk.com/app/4413/) app in Splunk if not already installed.
    * Please see [Splunk Installation](https://docs.splunk.com/Documentation/Splunk/8.0.3/SearchTutorial/InstallSplunk) if you need to install Splunk.
    * Alternatively you can [install Splunk via Bolt](https://forge.puppet.com/configuration-management/puppetlabs/deploy-splunk-enterprise-in-minutes).
2. Create an HEC token in Splunk:
  * Navigate to `Settings` > `Data Input` in your Splunk console.
  * Add a new `HTTP Event Collector` with a name of your choice.
  * Ensure `indexer acknowledgement` is not enabled.
  * Click Next and set the source type to Automatic.
  * Ensure the `App Context` is set to `Puppet Report Viewer`.
  * Add the `main` index
  * Set the **Default Index** to `main`.
  * Click **Review** and then **Submit**.
  * When complete the HEC token should look something like this:

  ![hec_token](https://raw.githubusercontent.com/puppetlabs/puppetlabs-splunk_hec/v0.8.1/docs/images/hec_token.png)

3. Install the module and add the `splunk_hec` class to the **PE Master** node group.
  * Install the `splunk_hec` module on your Puppet Primary Server.
      * `puppet module install puppetlabs-splunk_hec`
  * In the PE console, navigate to `Node groups` and expand `PE Infrastructure`.
  * Select `PE Master` and navigate to the `Classes` tab.
  * Add the `splunk_hec` class.
  * Configure the following parameters:

      ```
      enable_reports = true
      manage_routes = true
      splunk_token = <TOKEN GENERATED IN STEP 2>
      url = something like https://splunk-8.splunk.internal:8088/services/collector
      include_api_collection = true
      ```
      
  * Commit the changes.
  * Run Puppet on the node group; this will cause a restart of the `pe-puppetserver` service.

4. Log into the Splunk console and search `index=* sourcetype=puppet:summary`, if everything was done properly you should see the reports (and soon facts) from the systems in your Puppet environment.

## Custom Installation

> **Please Note**: If you are installing this module using a `control-repo`, you must have `splunk_hec` in your production environment's `Puppetfile` so the Puppet Server process can properly load the required libraries. You can then create a feature branch to enable them and test the configuration, but the libraries **must be** in `production`; otherwise the feature branch won't work as expected. If your Puppet Server is in a different environment, please add this module to the `Puppetfile` in that environment as well.

The steps below will help install and troubleshoot the report processor on a standard Puppet Primary Server; including manual steps to configure compilers (Puppet Servers), and to use the included `splunk_hec` class. Because one is modifying production machines, these steps allow you to validate your settings before deploying the changes live. 

1. Install the Puppet Report Viewer app in Splunk. This will import the needed source types to configure Splunk's HTTP Endpoint Collector (HEC) and provide a dashboard that will show the reports once they are sent to Splunk.

2. Create a Splunk HEC Token or use an existing one that sends to `main` index and **does not** have acknowledgement enabled. Follow the steps provided by Splunk's [Getting Data In Guide](http://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector) if you are new to HTTP Endpoint Collectors.

3. Install this Puppet module in the environment that your Puppet Servers are using (e.g. `production`).

4. Run `puppet plugin download` on your Puppet Servers to sync the content. Some users with strict permissions may need to run `umask 022` first.

  * **Please Note**: If permissions are too restrictive you may see the following error in the Puppet Server logs:

      ```
      Could not find terminus splunk_hec for indirection facts
      ```

5. Create `/etc/puppetlabs/puppet/splunk_hec.yaml` (see the [examples directory](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/examples/splunk_hec.yaml)), adding your Splunk Server URL to the `url` parameter (e.g. `https://splunk-dev:8088/services/collector`) and HEC Token created during step 2 to the `splunk_token` parameter.
  * You can add `timeout` as an optional parameter. The **default value** is `1` second for both open and read sessions, so take value x2 for real world use.
  * **PE Only**: Provide the `pe_console` parameter value. This is the FQDN for the PE console, which Splunk can use to lookup further information if the installation utilizes compilers (it is best practice to set this if you're anticipating scaling the installation in the future).

      ```
      ---
      "url" : "https://splunk-dev.testing.local:8088/services/collector"
      "splunk_token" : "13311780-EC29-4DD0-A796-9F0CDC56F2AD"
      ```
      (**Note**: If [Disaster Recovery](https://puppet.com/docs/pe/latest/dr_overview.html) is enabled you will need to ensure these settings exist on the Replica node as well. This is often done through the `PE HA Replica` node group.)

6. Run `puppet apply -e 'notify { "hello world": }' --reports=splunk_hec` from the Puppet Server, this will load the report processor and test your configuration settings without actually modifying your Puppet Server's running configuration. If you are using the Puppet Report Viewer app in Splunk then you will see the page update with new data. If not, perform a search by the `sourcetype` you provided with your HEC configuration.

7. If configured properly the Puppet Report Viewer app in Splunk will show 1 node in the `Overview` tab.

8. Now it is time to roll these settings out to the fleet of Puppet Servers in the installation. For PE users:
  * In the PE console, navigate to `Node groups` and expand `PE Infrastructure`.
  * Select `PE Master` and navigate to the `Classes` tab.
  * Click **Refresh** to ensure that the `splunk_hec` class is loaded.
  * Add new class `splunk_hec`.
  * From the `Parameter` drop down list you will need to configure at least `url` and `splunk_token`, providing the same values from the testing configuration file.  
      * Optionally set `enable_reports` to `true` if there isn't another component managing the servers reports setting. Otherwise manually add `splunk_hec` to the settings as described in the [manual steps](#manual-steps) below.
  * Commit changes and run Puppet. It is best to navigate to the `PE Certificate Authority` node group and run Puppet there first, before running Puppet on the remaining nodes.

9. For Inventory support in the Puppet Report Viewer, see [Fact Terminus Support](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/fact_terminus_support.md).

#### Manual Steps:

  * Add `splunk_hec` to `reports` under the `[master]` configuration block in `/etc/puppetlabs/puppet/puppet.conf`:
        
    ```
    [master]
    node_terminus = classifier
    storeconfigs = true
    storeconfigs_backend = puppetdb
    reports = puppetdb,splunk_hec
    ```
        
  * Restart the `pe-puppetserver` process (`puppet-server` for Open Source Puppet) for it to reload the configuration and the plugin.

  * Run `puppet agent -t` on an agent; if you are using the suggested name, use `source="http:puppet-report-summary"` in your Splunk search field to show the reports as they arrive.

## SSL Configuration

Configuring SSL support for this report processor and tasks requires that the Splunk HEC service being used has a [properly configured SSL certificate](https://docs.splunk.com/Documentation/Splunk/latest/Security/AboutsecuringyourSplunkconfigurationwithSSL). Once the HEC service has a valid SSL certificate, the CA will need to be made available to the report processor to load. The supported path is to install a copy of the Splunk CA to a directory called `/etc/puppetlabs/puppet/splunk_hec/` and provide the file name to `splunk_hec` class.

You can manually update the `splunk_hec.yaml` file with these settings:

```
"ssl_ca" : "splunk_ca.cert"
```

Alternatively, you can create a profile class that copies the `splunk_ca.cert` as part of invoking the splunk_hec class:

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

## Customized Reporting

As of `0.8.0` and later the report processor can be configured to include **Logs** and **Resource Events** along with the existing summary data. Because this data varies between runs and agents in Puppet, it is difficult to predict how much data you will use in Splunk as a result. However, this removes the need for configuring the **Detailed Report Generation** alerts in Splunk to retrieve that information; which may be useful for large installations that need to retrieve a large amount of data. You can now just send the information from Puppet directly.

Add one or more of these parameters based on the desired outcome, these apply to the state of the puppet runs. You cannot filter by facts on which nodes these are in effect for. As such, you can get ***logs when a puppet run fails***, but not *logs when a `windows` server puppet run fails*.

By default this type of reporting is not enabled.

**Parameters**:

##### include_logs_status

`Array`: Determines if [logs](https://puppet.com/docs/puppet/latest/format_report.html#puppet::util::log) should be included based on the return status of the puppet agent run. This can be none, one, or any of the following:

  * `failed`
  * `changed`
  * `unchanged`

##### include_logs_catalog_failure

`Boolean`: Include logs if a catalog fails to compile. This is a more specific type of failure that indicates a server-side issue.

  * `true`
  * `false`

##### include_logs_corrective_change

`Boolean`: Include logs if a there is a corrective change (a PE only feature) - indicating drift was detected from the last time puppet ran on the system.

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

## Events

The `splunk_hec` module allows the posting of PE orchestrator and activity service events to Splunk.

#### Prerequisites

* To utilize the API collector, a user with the correct RBAC privileges will
  need to be created. The user must have read access to the **Orchestrator** and **Activity Service** API's in PE.
* The common events module will need to be installed. The instructions are below.

#### Configuration

1. From the PE console, set the `include_api_collection` parameter in the `splunk_hec` class to **true**.
2. Set up API Authentication.
  * Username / Password Auth:
      * Set the `pe_username` parameter to a pe user with read access to the Orchestrator and Activity Service API's in PE.
      * Set the `pe_password` parameter to the password for the user above.
  * Token Auth:
      * Set the `pe_token` parameter for a user with read access to the Orchestrator and Activity Service API's in PE.
3. Optionally set the `pe_console` parameter if the PE console is not hosted on the same node that this module is installed on.
  * This should be the FQDN of the node that is hosting the PE console. Omit the `https` protocol.

#### Installation

1. Ensure you have the latest version of the **Puppet Report Viewer** installed (>= 3.0.2) in your Splunk installation.
  * Here is the link: https://splunkbase.splunk.com/app/4413/
  * This will ensure that you have the needed source types to apply to your data in Splunk.
2. Configure the `splunk_hec` class as described above.
3. Install the `common_events` module.
  * Specify this module in your Puppetfile:
      
      ```
      mod 'common_events',
          :git => 'https://github.com/puppetlabs/puppetlabs-common_events'
      ```
      
4. Run `puppet agent -t`

The events now will be collected and posted to your Splunk Server. These events will appear in the Splunk UI.

There are three possible source types:

```
puppet:jobs
puppet:activities_classifier
puppet:activities_rbac
```

#### Viewing the events

Use `source="puppet:jobs"` in your Splunk search field to show the orchestrator jobs. Orchestrator jobs includes Puppet agent runs kicked off from the `Run Puppet` button in the console, and it includes Tasks and Plans run from the console using the `Run task` and `Run plan` buttons.

Use `source="puppet:activities_classifier"` in your Splunk search field to show Classifier events coming from the Activity Service API. These events will include things like creating new classifier node groups, changing node group classification rules, etc.

Use `source="puppet:activities_rbac` in your Splunk search field to show RBAC events coming from the Activity Service API. These events will include things like creating new local users, updating user metadata, etc.

## Tasks

Two tasks are provided for submitting data from a Bolt plan to Splunk. For clarity, we recommend using a different HEC token to distinguish between events from Puppet runs and those generated by Bolt. The Puppet Report Viewer app includes a `puppet:bolt` sourcetype to faciltate this. Currently SSL validation for Bolt communications to Splunk is not supported.

  * `splunk_hec::bolt_apply`: A task that uses the remote task option to submit a Bolt Apply report in a similar format to the `puppet:summary`. Unlike the summary, this includes the facts from a target because those are available to bolt at execution time and added to the report data before submission to Splunk.

  * `splunk_hec::bolt_result`: A task that sends the result of a function to Splunk. Since the format is freeform and dependent on the individual function/tasks being called, formatting of the data is best done in the plan itself prior to submitting the result hash to the task.

To setup, add the `splunk_hec` endpoint as a remote target in your `inventory.yaml` file:

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

See the [`plans`](https://github.com/puppetlabs/puppetlabs-splunk_hec/tree/main/plans) directory for working examples of apply and result usage.

## Advanced Settings

The `splunk_hec` module also supports customizing the `fact_terminus` and `facts_cache_terminus` names in the custom `splunk_routes.yaml` it deploys. If you are using a different `facts_terminus` (i.e. not PuppetDB), you will want to set that parameter.

If you are already using a custom `splunk_routes.yaml`, these are the equivalent instructions of what the `splunk_hec` module does. The most important setting is configuring `cache: splunk_hec`.

  * Create a custom `splunk_routes.yaml` file to override where facts are cached:

  ```
  ---
  master:
    facts:
      terminus: puppetdb
      cache: splunk_hec
  ```
  
  * Set this routes file instead of the default one by running the following commmand:

  ```
  puppet config set route_file /etc/puppetlabs/puppet/splunk_routes.yaml --section master
  ```

## Advanced Topics

* [Advanced Puppet Configuration](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/advanced_puppet_configuration.md)
* [Advanced Splunk Configuration](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/advanced_splunk_configuration.md)
* [Fact Terminus Support](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/fact_terminus_support.md)
* [Puppet Metrics Collection](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/puppet_metrics_collector_support.md)
* [Troublshooting and Verification](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/troubleshooting_and_verification.md)

## Known Issues

  * Integration with the `puppet_metrics_collection` requires version `>= 6.0.0`.
  * SSL Validation is under active development and behavior may change.
  * Automated testing could use work.

## Breaking Changes

  * `>= 0.5.0` The `splunk_hec::url` parameter now expects a full URI of **https://servername:8088/services/collector**.
  * `0.5.0` -> `0.6.0` Switches to the fact terminus cache setting via `splunk_routes.yaml` to ensure compatibility with CD4PE. See [Fact Terminus Support](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/v0.8.1/docs/fact_terminus_support.md) for guides on how to change it. Prior to deploying this module, remove the setting `facts_terminus` from the `puppet_enterprise::profile::master` class in the `PE Master` node group in your environment if you set it in previous versions of this module (`0.6.0 <`). It will prevent PE from operating normally if left on.

## Release Process

This module is hooked up with an automatic release process using Github actions. To provoke a release simply check the module out locally, tag with the new release version, then github will promote the build to the forge.

Full process to prepare for a release:

Update `metadata.json` to reflect new module release version (0.8.1).
Run `bundle exec rake changelog` to update the `CHANGELOG` automatically.
Submit PR for changes.

Create Tag on target version:

```
git tag -a v0.8.1 -m "0.8.1 Feature Release"
git push upstream --tags
```

## Authors

P.I.E. Team

P. uppet\
I. ntegrations\
E. ngineering

Chris Barker <cbarker@puppet.com>\
Helen Campbell <helen@puppet.com>\
Greg Hardy <greg.hardy@puppet.com>\
Bryan Jen <bryan.jen@puppet.com>\
Greg Sparks <greg.sparks@puppet.com>

---
