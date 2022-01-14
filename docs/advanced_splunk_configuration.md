## Advanced Splunk Configuration Options

The `splunk_hec` class and data processors support setting individual HEC tokens and URLs for the following data types:

  * **Summary Reports**: Corresponds to the `puppet:summary` source type in the Puppet Report Viewer. Use the `token_summary` and `url_summary` parameters to configure them in the `splunk_hec.yaml` file.
  * **Fact Data**: Corresponds to the `puppet:facts` source type in the Puppet Report Viewer. Use the `token_facts` and `url_facts` parameters to configure them in the `splunk_hec.yaml` file.
  * **PE Metrics**: Corresponds to the `puppet:metrics` source type in the Puppet Report Viewer. Use the `token_metrics` and `url_metrics` parameters to configure them in the `splunk_hec.yaml` file.

Different URLs only need to be specified if different HEC systems entirely are being used. If one is using one collecter server, but multiple HECs, just use the single `url` parameter as before, and specify each source type's corresponding HEC token.

**Note**: Making these changes here assumes that you know how to properly use indexes and update the advanced search macros in Splunk to ensure that the Report Viewer can load data from those indexes.
