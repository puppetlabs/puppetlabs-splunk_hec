## Advanced Puppet Configuration
-----------

The splunk_hec module also supports customizing the `facts_terminus` and `facts_cache_terminus` names in the custom routes.yaml it deploys. If you are using a different facts_terminus (ie, not PuppetDB), you will want to set that parameter.

If you are already using a custom routes.yaml, these are the equivalent instructions of what the splunk_hec module does, the most important setting is configuring `cache: splunk_hec`
- Create a custom splunk_routes.yaml file to override where facts are cached 
```yaml
master:
  facts:
    terminus: puppetdb
    cache: splunk_hec
```
- Set this routes file instead of the default one with `puppet config set route_file /etc/puppetlabs/puppet/splunk_routes.yaml --section master`
