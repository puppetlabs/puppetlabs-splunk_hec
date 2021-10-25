namespace :acceptance do
  require_relative '../spec/support/acceptance/helpers'
  include TargetHelpers

  desc 'Provisions the VMs. This is currently just the puppetserver'
  task :provision_vms do
    if File.exist?('spec/fixtures/litmus_inventory.yaml')
    # Check if a puppetserver VM's already been setup
      begin
        uri = puppetserver.uri
        puts("A puppetserver VM at '#{uri}' has already been set up")
        next
      rescue TargetNotFoundError
      # Pass-thru, this means that we haven't set up the puppetserver VM
      end
    end

    provision_list = ENV['PROVISION_LIST'] || 'acceptance'
    Rake::Task['litmus:provision_list'].invoke(provision_list)
    inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
    begin
      # If a fips node is present, assign the correct roles to the fips node and the splunk node
      fips_node = inventory_hash['groups'].detect {|g| g['name'] == 'ssh_nodes'}['targets'].detect {|t| t['facts']['platform'].match(/fips/)}
      fips_node['vars'] = {'role' => 'server'}
      splunk_node = inventory_hash['groups'].detect {|g| g['name'] == 'ssh_nodes'}['targets'].detect {|t| !t['facts']['platform'].match(/fips/)}
      splunk_node['vars'] = {'role' => 'splunk_node'}
    rescue => exception
      puts 'no fips node found.'
    end

      # Remove bad username and password keys as a result of a provision module bug
      inventory_hash['groups'].detect {|g| g['name'] == 'ssh_nodes'}['targets'].each do |target|
        target['config']['ssh'].delete("password") if target['config']['ssh']['password'].nil?
        target['config']['ssh'].delete("user") if target['config']['ssh']['user'].nil?
      end
      write_to_inventory_file(inventory_hash, 'spec/fixtures/litmus_inventory.yaml')
  end

  desc 'clone puppetlabs-pe_event_forwarding module to test host'
  task :upload_pe_event_forwarding_module do
    puppetserver.bolt_upload_file('./spec/fixtures/modules/pe_event_forwarding', '/etc/puppetlabs/code/environments/production/modules')
  end

  desc 'Sets up PE on the server'
  task :setup_pe do
    include ::BoltSpec::Run
    inventory_hash = inventory_hash_from_inventory_file
    target_nodes = find_targets(inventory_hash, 'ssh_nodes')

    config = { 'modulepath' => File.join(Dir.pwd, 'spec', 'fixtures', 'modules') }

    params = {}

    params.merge(puppet_version: ENV['PUPPET_VERSION']) unless ENV['PUPPET_VERSION'].nil?

    bolt_result = run_plan('splunk_hec::acceptance::server_setup', params, config: config, inventory: inventory_hash.clone)
  end

  desc 'Sets up the Splunk instance'
  task :setup_splunk_instance do
    splunk_setup_target = begin
                            splunk_node
                          rescue TargetNotFoundError
                            puppetserver
                          end
    puts("Starting the Splunk instance at the puppetserver (#{splunk_setup_target.uri})")
    splunk_setup_target.bolt_upload_file('./spec/support/acceptance/splunk', '/tmp/splunk')
    puts splunk_setup_target.bolt_run_script('spec/support/acceptance/start_splunk_instance.sh').stdout.chomp
    # HEC token is hard coded because it will always be the same in the splunk container
    instance, hec_token = "#{splunk_setup_target.uri}:8088", 'abcd1234'

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
      'platform' => 'splunk_hec',
      'provisioner' => 'docker',
      'container_name' => 'splunk_enterprise_1'
    },
      'vars' => {
        'roles' => ['splunk_instance'],
      }
    }]
    write_to_inventory_file(inventory_hash, 'spec/fixtures/litmus_inventory.yaml')
  end

  desc 'Installs the module on the puppetserver'
  task :install_module do
    puppetserver.run_shell("rm -rf '/etc/puppetlabs/puppet/splunk_hec.yaml'")
    Rake::Task['litmus:install_module'].invoke(puppetserver.uri)
    puppetserver.bolt_upload_file('./spec/support/acceptance/splunk_hec.yaml', '/etc/puppetlabs/puppet/splunk_hec.yaml')
  end

  desc 'Runs the tests'
  task :run_tests do
    rspec_command  = 'bundle exec rspec ./spec/acceptance --format documentation'
    rspec_command += ' --format RspecJunitFormatter --out rspec_junit_results.xml' if ENV['CLOUD_CI'] == 'true'
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
      :upload_pe_event_forwarding_module,
    ]

    tasks.each do |task|
      task = "acceptance:#{task}"
      puts("Invoking #{task}")
      Rake::Task[task].invoke
      puts("")
    end
  end

  desc 'Tear down the setup'
  task :tear_down do
    puts("Tearing down the test infrastructure ...\n")
    Rake::Task['litmus:tear_down'].invoke(puppetserver.uri)
    begin
      Rake::Task['litmus:tear_down'].invoke(splunk_node.uri)
    rescue TargetNotFoundError
      # This error means splunk server container was run on the puppetserver node.
    end
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
