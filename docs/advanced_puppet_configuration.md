## Advanced Puppet Configuration

The `splunk_hec` module also supports customizing the `facts_terminus` and `facts_cache_terminus` names in the custom `splunk_hec_routes.yaml` it deploys. If you are using a different `facts_terminus` (i.e. not PuppetDB), you will want to configure that parameter.

If you are already using a custom `routes.yaml`, these are the equivalent instructions of what the `splunk_hec` module does, the most important setting is configuring `cache: splunk_hec`.

  * Create a custom `splunk_hec_routes.yaml` file to override where facts are cached:

  ```
    ---
    master:
      facts:
        terminus: puppetdb
        cache: splunk_hec
  ```

  * Set this routes file instead of the default one with the following command:
    * `puppet config set route_file /etc/puppetlabs/puppet/splunk_hec_routes.yaml --section master`
