puppet-splunk_hec
==============

Description
-----------

This is a report processor designed to send a report summary of useful information to the [Splunk HEC](http://docs.splunk.com/Documentation/Splunk/7.1.3/Data/UsetheHTTPEventCollector) service.

This creates a single event for the hostname where the report originated from (ie, the agent in question) and the body of the event is structured like the example below:

```json
{
    "cached_catalog_status": "not_used",
    "catalog_uuid": "5c9eda91-c652-4cf9-8ea3-ab14e3c0a3e7",
    "code_id": "urn:puppet:code-id:1:f57e361d8de53fcf0b8f5ebcee42083a81b71ec6;production",
    "configuration_version": "puppet-production-9f5fd3d7e6d",
    "corrective_change": false,
    "environment": "production",
    "job_id": null,
    "noop": false,
    "noop_pending": false,
    "puppet_version": "5.5.6",
    "report_format": 10,
    "status": "unchanged",
    "time": "2018-09-26 22:47:16 UTC",
    "transaction_uuid": "e9a8b3be-b0ce-49fc-a5ea-4d715533ad28"
}
```

Once this exists as an event in Splunk, you can do a lot with it. The indexed size of the above example is 485 bytes. This size will remain consistent over every Puppet agent run, regardless of complexity of catalog or resources being managed. This makes calculating the impact of sending report summaries easy: given a 30 minute report interval, it is around 12 megabytes/year per agent reporting in you fleet. Depending on your archival needs, you can probably throw away the status: unchange events to reduce the footprint even more.

Why is this useful? Because if you are using Puppet Enterprise, you can create a Custom Alert Action to retrieve more information about particular events, such as retrieving all the resource events from PuppetDB when a report summary shows up with a Corrective Change present. A curl request doing the equivalent is:

```shell
curl -s -X POST http://localhost:8080/pdb/query/v4/reports \
-H 'Content-Type:application/json' \
-d '{"query":["extract",["hash","certname","transaction_uuid","start_time","code_id","configuration_version","resource_events"],["=","transaction_uuid","6471334d-1f2b-46f3-a16c-2f6116abe057"]]}' | \
python -m json.tool
```

Output:
```json
[
    {
        "certname": "splunk.c.splunk-217321.internal",
        "code_id": "urn:puppet:code-id:1:f57e361d8de53fcf0b8f5ebcee42083a81b71ec6;production",
        "configuration_version": "puppet-production-9f5fd3d7e6d",
        "hash": "f53ef654072f7fd6b06fa7779a7dc08218221948",
        "resource_events": {
            "data": [
                {
                    "containing_class": "Ntp::Config",
                    "containment_path": [
                        "Stage[main]",
                        "Ntp::Config",
                        "File[/etc/ntp.conf]"
                    ],
                    "corrective_change": true,
                    "file": "/etc/puppetlabs/code/environments/production/modules/ntp/manifests/config.pp",
                    "line": 51,
                    "message": "content changed '{md5}f9b570d3fe7da9e0234d52cbc0c2b94a' to '{md5}d51b2e5ec0a9f463047efb49555f65fe'",
                    "new_value": "{md5}d51b2e5ec0a9f463047efb49555f65fe",
                    "old_value": "{md5}f9b570d3fe7da9e0234d52cbc0c2b94a",
                    "property": "content",
                    "resource_title": "/etc/ntp.conf",
                    "resource_type": "File",
                    "status": "success",
                    "timestamp": "2018-09-26T21:50:14.144+00:00"
                }
            ],
            "href": "/pdb/query/v4/reports/f53ef654072f7fd6b06fa7779a7dc08218221948/events"
        },
        "start_time": "2018-09-26T21:50:09.924Z",
        "transaction_uuid": "6471334d-1f2b-46f3-a16c-2f6116abe057"
    }
]
```

The result includes things like the hash, which can be used to create a link back to the Puppet Enterprise console, following the same format as: https://puppet.company.com/#/inspect/report/$reporthash/events

Or just create another event in Splunk with the result, and create another Alert Action to open a ticket or run something in Phantom, or what have you.

Requirements
------------

* Puppet or Puppet Enterprise
* Splunk

This was tested on both Puppet Enterprise 2018.1.4 & Puppet 6, using stock gems of yaml, json, net::https

Installation & Usage
--------------------

1. Create a Splunk HEC Token (preferably named `puppet-report-summary`)

2. Install this module in the environment your Puppet Server's are using (problaby `production`)

3. Run `puppet agent -t` or `puppet plugin download` if you wish to grab the processor without a full puppet agent run

4. Create a `/etc/puppetlabs/puppet/splunk_hec.yaml` (see examples directory for one) adding your Splunk Server & Token from step 1
  - You can add 'timeout' as an optional parameter, default value is 2 for both open and read sessions, so take value x2 for real world use
  - The same is true for port, defaults to 8088 if none provided
  - Provide a 'puppetdb_callback_hostname' variable if the hostname that Splunk will use to lookup further information about a report is different than the puppetserver processing the reports (ie, multiple servers, load balancer, external dns name vs internal, etc.) Defaults to the certname of the puppetserver processing the report.

5. Add `splunk_hec` to `/etc/puppetlabs/puppet/puppet.conf` reports line under the master's configuration block
```
[master]
node_terminus = classifier
storeconfigs = true
storeconfigs_backend = puppetdb
reports = puppetdb,splunk_hec
```

6. Restart the puppet server process for it to reload the configuration and the plugin

7. Run `puppet agent -t` somewhere, if you are using the suggested name, use `source="http:puppet-report-summary"` in your splunk search field to show the reports as they arrive

Known Issues
------------
* No tests
* Should probably have a module that just installs this


Author
------
Chris Barker <cbarker@puppet.com>
