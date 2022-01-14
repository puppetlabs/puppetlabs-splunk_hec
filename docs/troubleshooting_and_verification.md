## Troubleshooting and Verification

### Puppet

Custom report processors and fact terminus indirectors run inside the Puppet Server process. For both Puppet Enterprise (PE) and Open Source Puppet (OSP) the Puppet Server logs are located at `/var/log/puppetlabs/puppetserver/puppetserver.log`.

With versions `0.5.0+` of the `splunk_hec` module configured, a healthy system would log entries like the ones below:

```
# grep -i splunk /var/log/puppetlabs/puppetserver/puppetserver.log
2019-06-17T12:44:47.729Z INFO  [qtp1685349172-4356] [puppetserver] Puppet Submitting facts to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
2019-06-17T12:44:48.322Z INFO  [qtp1685349172-15004] [puppetserver] Puppet Submitting report to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
2019-06-17T12:45:25.913Z INFO  [qtp1685349172-28874] [puppetserver] Puppet Submitting facts to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
```

Versions prior to `0.5.0`, or `0.5.0+` without the fact terminus configured, a healthy system would log entries like the ones below:

```
# grep -i splunk /var/log/puppetlabs/puppetserver/puppetserver.log
2019-06-17T12:48:21.646Z INFO  [qtp1685349172-4354] [puppetserver] Puppet Submitting report to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
2019-06-17T12:48:31.689Z INFO  [qtp1685349172-4354] [puppetserver] Puppet Submitting report to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
2019-06-17T12:49:22.881Z INFO  [qtp1685349172-4356] [puppetserver] Puppet Submitting report to Splunk at https://splunk-dev.c.splunk-217321.internal:8088/services/collector
```

If neither of those entries appears in the log, then the Puppet Server has yet to be configured. Check the `reports` and `route_file` settings in the `puppet.conf` to ensure report processing and fact indirection for `splunk_hec` is properly configured on all of the infrastructure nodes in the installation (e.g. Primary Server, Replica, Compilers). This can be confirmed with the following command.

```
# puppet config print reports route_file --section master
reports = puppetdb,splunk_hec
route_file = /etc/puppetlabs/puppet/splunk_hec_routes.yaml
```

---

### Splunk

To verify that reports and facts from Puppet are properly ingested by Splunk, search all indexes for the source type `puppet:*`.

```
index=* sourcetype=puppet:*
```

The number of events corresponds to the number of Puppet runs, doubled (1 event for the report and 1 event for the facts collected), that have occured during that time period; not the number of hosts. To verify all hosts in an environment have submitted reports and facts, you would need to `dedup` the events by `host` to get an accurate count.

Once Puppet has been sending data to Splunk for ~60 minutes, set the time range picker to the last 60 minutes and use the following search:

```
index=* sourcetype=puppet:summary | dedup host
```

The resulting event count should match the number of nodes listed in the Puppet Enterprise console. If you are utilizing multiple Puppet installations you will need to filter by the `pe_console` value:

```
index=* sourcetype=puppet:summary | pe_console=puppet.company.com | dedup host
```

In the event the above steps have confirmed that the reports/facts are being sent to Splunk and stored appropriately by the correct source types; and you are experiencing issues with detailed reports or display issues in the Splunk Console, please see the documentation for the [Puppet Report Viewer](https://github.com/puppetlabs/ta-puppet-report-viewer).

---