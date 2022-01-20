## SSL Configuration

Configuring SSL support for this report processor and tasks requires that the Splunk HEC service being used has a [properly configured SSL certificate](https://docs.splunk.com/Documentation/Splunk/latest/Security/AboutsecuringyourSplunkconfigurationwithSSL). Once the HEC service has a valid SSL certificate, the CA will need to be made available to the report processor to load. The supported path is to install a copy of the Splunk CA to a directory called `/etc/puppetlabs/puppet/splunk_hec/` and provide the file name to `splunk_hec` class.

You can manually update the `splunk_hec.yaml` file with these settings:

```
"ssl_ca" : "splunk_ca.cert"
```

Alternatively, you can create a [profile class](https://puppet.com/docs/pe/latest/osp/the_roles_and_profiles_method.html) that copies the `splunk_ca.cert` as part of invoking the splunk_hec class:

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

The certificate provided to the `ssl_ca` parameter is a supplement to the system ca certificates store. By default, the Ruby classes that perform certificate validation will attempt to use the system certificates first, and then if the certificate cannot be validated there, it will load the ca file in `ssl_ca`. Occasionally, the system cert store will cause validation errors prior to checking the file at `ssl_ca`. To avoid this you can set `ignore_system_cert_store` to `true`. This will allow the code to use ONLY the file at `ssl_ca` to perform certificate validation.
