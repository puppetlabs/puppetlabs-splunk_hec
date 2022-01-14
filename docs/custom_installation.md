## Custom Installation

> **Please Note**: If you are installing this module using a [`control-repo`](https://puppet.com/docs/pe/latest/control_repo.html) you must have `splunk_hec` in your production environment's [`Puppetfile`](https://puppet.com/docs/pe/latest/puppetfile.html) so the Puppet Server process can properly load the required libraries. You can then create a feature branch to enable them and test the configuration, but the libraries **must be** in `production`; otherwise the feature branch won't work as expected. If your Puppet Server is in a different environment, please add this module to the `Puppetfile` in that environment as well.

The steps below will help install and troubleshoot the report processor on a standard Puppet Primary Server; including manual steps to configure compilers (Puppet Servers), and to use the included `splunk_hec` class. Because one is modifying production machines, these steps allow you to validate your settings before deploying the changes live.

1. Install the Puppet Report Viewer app in Splunk. This will import the needed source types to configure Splunk's HTTP Endpoint Collector (HEC) and provide a dashboard that will show the reports once they are sent to Splunk.

2. Create a Splunk HEC Token or use an existing one that sends to `main` index and **does not** have acknowledgement enabled. Follow the steps provided by Splunk's [Getting Data In Guide](http://docs.splunk.com/Documentation/Splunk/latest/Data/UsetheHTTPEventCollector) if you are new to HTTP Endpoint Collectors.

3. [Install this Puppet module](https://puppet.com/docs/puppet/latest/modules_installing.html) in the environment that your Puppet Servers are using (e.g. `production`).

4. Run `puppet plugin download` on your Puppet Servers to sync the content. Some users with strict permissions may need to run `umask 022` first.

  * **Please Note**: If permissions are too restrictive you may see the following error in the Puppet Server logs:

      ```
      Could not find terminus splunk_hec for indirection facts
      ```

5. Create `/etc/puppetlabs/puppet/splunk_hec.yaml` (see the [examples directory](https://github.com/puppetlabs/puppetlabs-splunk_hec/main/examples/splunk_hec.yaml)), adding your Splunk Server URL to the `url` parameter (e.g. `https://splunk-dev:8088/services/collector`) and HEC Token created during step 2 to the `splunk_token` parameter.
  * You can add `timeout` as an optional parameter. The **default value** is `1` second for both open and read sessions, so take value x2 for real world use.
  * **PE Only**: Provide the `pe_console` parameter value. This is the FQDN for the PE console, which Splunk can use to lookup further information if the installation utilizes compilers (it is best practice to set this if you're anticipating scaling the installation in the future).

      ```
      ---
      "url" : "https://splunk-dev.testing.local:8088/services/collector"
      "token" : "13311780-EC29-4DD0-A796-9F0CDC56F2AD"
      ```
      (**Note**: If [Disaster Recovery](https://puppet.com/docs/pe/latest/dr_overview.html) is enabled you will need to ensure these settings exist on the Replica node as well. This is often done through the `PE HA Replica` node group.)

6. Run `puppet apply -e 'notify { "hello world": }' --reports=splunk_hec` from the Puppet Server, this will load the report processor and test your configuration settings without actually modifying your Puppet Server's running configuration. If you are using the Puppet Report Viewer app in Splunk then you will see the page update with new data. If not, perform a search by the `sourcetype` you provided with your HEC configuration.

7. If configured properly the Puppet Report Viewer app in Splunk will show 1 node in the `Overview` tab.

8. Now it is time to roll these settings out to the fleet of Puppet Servers in the installation. For PE users:
  * In the [PE console](https://puppet.com/docs/pe/latest/console_accessing.html), navigate to `Node groups` and expand `PE Infrastructure`.
  * Select `PE Master` and navigate to the `Classes` tab.
  * Click **Refresh** to ensure that the `splunk_hec` class is loaded.
  * Add new class `splunk_hec`.
  * From the `Parameter` drop down list you will need to configure at least `url` and `token`, providing the same values from the testing configuration file.
      * Optionally set `enable_reports` to `true` if there isn't another component managing the servers reports setting. Otherwise manually add `splunk_hec` to the settings as described in the [manual steps](#manual-steps) below.
  * Commit changes and run Puppet. It is best to navigate to the `PE Certificate Authority` node group and run Puppet there first, before running Puppet on the remaining nodes.

9. For Inventory support in the Puppet Report Viewer, see [Fact Terminus Support](https://github.com/puppetlabs/puppetlabs-splunk_hec/blob/main/docs/fact_terminus_support.md).

#### Manual Steps:

  * Add `splunk_hec` to `reports` under the `[master]` configuration block in `/etc/puppetlabs/puppet/puppet.conf`:

    ```
    [master]
    node_terminus = classifier
    storeconfigs = true
    storeconfigs_backend = puppetdb
    reports = puppetdb,splunk_hec
    ```

  * [Restart the `pe-puppetserver`](https://puppet.com/docs/puppetserver/latest/restarting.html) process (`puppet-server` for Open Source Puppet) for it to reload the configuration and the plugin.

  * Run `puppet agent -t` on an agent; if you are using the suggested name, use `source="http:puppet-report-summary"` in your Splunk search field to show the reports as they arrive.
