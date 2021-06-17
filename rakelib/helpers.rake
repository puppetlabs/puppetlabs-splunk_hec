namespace :acceptance do
  require_relative '../spec/support/acceptance/helpers'
  include TargetHelpers

  desc 'Provisions the VMs. This is currently just the master'
  task :provision_vms do
    if File.exist?('spec/fixtures/litmus_inventory.yaml')
    # Check if a master VM's already been setup
      begin
        uri = master.uri
        puts("A master VM at '#{uri}' has already been set up")
        next
      rescue TargetNotFoundError
      # Pass-thru, this means that we haven't set up the master VM
      end
    end

    provision_list = ENV['PROVISION_LIST'] || 'acceptance'
    Rake::Task['litmus:provision_list'].invoke(provision_list)
  end

  desc 'Sets up PE on master'
  task :setup_pe do
    master.bolt_run_script('spec/support/acceptance/install_pe.sh')
  end

  desc 'Sets up the Splunk instance'
  task :setup_splunk_instance do
    puts("Starting the Splunk instance at the master (#{master.uri})")
    master.bolt_upload_file('./spec/support/acceptance/splunk', '/tmp/splunk')
    master.bolt_run_script('spec/support/acceptance/start_splunk_instance.sh')
    # HEC token is hard coded because it will always be the same in the splunk container
    instance, hec_token = "#{master.uri}:8088", 'abcd1234'

    # Update the inventory file
    puts('Updating the inventory.yaml file with the Splunk HEC credentials')
    inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
    splunk_group = inventory_hash['groups'].find { |g| g['name'] =~ %r{splunk} }
    unless splunk_group
      splunk_group = { 'name' => 'splunk_nodes' }
      inventory_hash['groups'].push(splunk_group)
    end
    splunk_group['targets'] = [{
      'uri' => instance,
      'config' => {
        'transport' => 'remote',
        'remote' => {
          'hec_token' => hec_token,
        }
      },
    'facts' => {
      'platform' => 'splunk_hec'
    },
      'vars' => {
        'roles' => ['splunk_instance'],
      }
    }]
    write_to_inventory_file(inventory_hash, 'spec/fixtures/litmus_inventory.yaml')
  end

  desc 'Installs the module on the master'
  task :install_module do
    master.run_shell("rm -rf '/etc/puppetlabs/puppet/splunk_hec.yaml'")
    Rake::Task['litmus:install_module'].invoke(master.uri)
    master.bolt_upload_file('./spec/support/acceptance/splunk_hec.yaml', '/etc/puppetlabs/puppet/splunk_hec.yaml')
  end

  desc 'Runs the tests'
  task :run_tests do
    rspec_command  = 'bundle exec rspec ./spec/acceptance --format documentation'
    rspec_command += ' --format RspecJunitFormatter --out rspec_junit_results.xml' if ENV['CI'] == 'true'
    puts("Running the tests ...\n")
    unless system(rspec_command)
      # system returned false which means rspec failed. So exit 1 here
      exit 1
    end
  end

  desc 'Set up the test infrastructure'
  task :setup do
    tasks = [
      :provision_vms,
      :setup_pe,
      :setup_splunk_instance,
      :install_module,
    ]

    tasks.each do |task|
      task = "acceptance:#{task}"
      puts("Invoking #{task}")
      Rake::Task[task].invoke
      puts("")
    end
  end

  desc 'Teardown the setup'
  task :tear_down do
    puts("Tearing down the test infrastructure ...\n")
    Rake::Task['litmus:tear_down'].invoke(master.uri)
    FileUtils.rm_f('spec/fixtures/litmus_inventory.yaml')
  end

  desc 'Task for CI'
  task :ci_run_tests do
    begin
      Rake::Task['acceptance:setup'].invoke
      Rake::Task['acceptance:run_tests'].invoke
    ensure
      Rake::Task['acceptance:tear_down'].invoke
    end
  end
end
