## Running the tests
-----------
### Linter
`bundle exec rubocop`

### Puppet class tests
`bundle exec rspec spec/classes`

### Acceptance tests
The acceptance tests use puppet-litmus in a multi-node fashion. The nodes consist of a 'master' node representing the PE master (and agent), and a Splunk node that runs the Splunk docker container. All nodes are stored in a generated `inventory.yaml` file (relative to the project root) so that they can be used with Bolt.

To setup the test infrastructure, use `bundle exec rake acceptance:setup`. This will:

* **Provision the master VM**
* **Setup PE on the VM**
* **Setup the Splunk instance.** This is just a Docker container on the master VM that runs splunk enterprise. Its code is contained in `spec/support/acceptance/splunk`.
* **Install the module on the master**

Each setup step is its own task; `acceptance:setup`'s implementation consists of calling these tasks. Also, all setup tasks are idempotent. That means its safe to run them (and hence `acceptance:setup`) multiple times.

To run the tests after setup, you can do `bundle exec rspec spec/acceptance`. To teardown the infrastructure, do `bundle exec rake acceptance:tear_down`.

Below is an example acceptance test workflow:

```
bundle exec rake acceptance:setup
bundle exec rspec spec/acceptance
bundle exec rake acceptance:tear_down
```

**Note:** Remember to run `bundle exec rake acceptance:install_module` whenever you make updates to the module code. This ensures that the tests run against the latest version of the module.

#### Debugging the acceptance tests
Since the high-level setup is separate from the tests, you should be able to re-run a failed test multiple times via `bundle exec rspec spec/acceptance/path/to/test.rb`.

**Note:** Sometimes, the modules in `spec/fixtures/modules` could be out-of-sync. If you see a weird error related to one of those modules, try running `bundle exec rake spec_prep` to make sure they're updated.
