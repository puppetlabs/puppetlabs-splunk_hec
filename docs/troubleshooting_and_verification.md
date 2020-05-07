## Troubleshooting and verification
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

To verify the reports are in Splunk properly, search all indexes for the source type 'puppet:summary' for reports, 'puppet:facts' for facts:
`index=* sourcetype=puppet:summary` and `index=* sourcetype=puppet:facts`

The number of events corresponds to the number of Puppet runs that have occured during that time period, not number of hosts. To verify all hosts in an environment have submitted facts/reports, one will need to dedup the events by host to get an accurate count, this is only worth doing after the module has been deployed for atleast an hour (or longer, depending on the Puppet run interval set in the environment). In the Splunk search view, set the time window to the last 60 minutes and use the following search, the resulting Event Count will match the number of nodes in the Puppet Enterprise console:
`index=* sourcetype=puppet:summary | dedup host`

If you are using multiple PE consoles (ie, multiple Puppet Enterprise installations), you will need to add an additional filter by pe_console value:
`index=* sourcetype=puppet:summary | pe_console=puppet.company.com | dedup host`

For troubleshooting detailed reports and display issues in the Splunk Console, please see the documentation for the [Puppet Report Viewer](https://github.com/puppetlabs/ta-puppet-report-viewer) if the above steps have demonstrated that the Reports and Facts are being sent to Splunk and stored appropriately in the right sourcetypes.