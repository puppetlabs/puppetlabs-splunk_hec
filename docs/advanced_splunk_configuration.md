## Advanced Splunk Configuration Options
-----------
The splunk_hec class and data processors support setting individual HEC tokens and URLs for each type of data supported. This is designed so users can specify a different HEC token if they wish their Puppet Reports are stored in a different index than their Facts, etc. Making changes here assumes you know how to use indexs and update the advanced search macros in Splunk so the Report Viewer can load data from those indexes.

- Summary Reports: Corresponds to puppet:summary in the Puppet Report Viewer, use `token_summary` and `url_summary` parameter or value in splunk_hec.yaml
- Fact Data: Corresponds to puppet:facts in the Puppet Report Viewer, use `token_facts` and `url_facts` parameter or value in splunk_hec.yaml
- PE Metrics: Corresponds to puppet:metrics in the Puppet Report Viewer, use `token_metrics` and `url_metrics` parameter or value in splunk_hec.yaml (at this time, collecting PE Metrics is not supported, but the sourcetype exists in the app)

Different URLs only need to be specified if different HEC systems entirely are being used. If one is using one collecter server, but multiple HECs, just provide the `url` setting as before, and specify each sourcetype's corresponding HEC token.
