namespace :acceptance do
  require_relative '../spec/support/acceptance/helpers'
  include TargetHelpers

  def get_fips_node(inventory)
    pre_prepped_node = inventory['groups'].detect {|g| g['name'] == 'ssh_nodes'}['targets'].detect {|t| t['facts']['platform'].match(/fips/)}
    first_node = if inventory['groups'].detect {|g| g['name'] == 'ssh_nodes'}['targets'].count == 2
                   inventory['groups'].detect {|g| g['name'] == 'ssh_nodes'}['targets'][0]
                 end
    pre_prepped_node || first_node
  end

  def get_splunk_node(inventory)
    inventory['groups'].detect {|g| g['name'] == 'ssh_nodes'}['targets'][1]
  end

  desc 'Add node roles and fix username/pass bug'
  task :fix_inventory_file do
    inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
    begin
      # If there is more than one node in the inventory, we will assume that one is going ot fips and one will run the container
      if fips_node = get_fips_node(inventory_hash)
        fips_node['vars'] = {'role' => 'server'}
        splunk_node = get_splunk_node(inventory_hash)
        splunk_node['vars'] = {'role' => 'splunk_node'}
      end
    end

    # Remove bad username and password keys as a result of a provision module bug unless your in CLOUD_CI
    unless ENV['CLOUD_CI']
      inventory_hash['groups'].detect {|g| g['name'] == 'ssh_nodes'}['targets'].each do |target|
        target['config']['ssh'].delete("password") if target['config']['ssh']['password'].nil?
        target['config']['ssh'].delete("user") if target['config']['ssh']['user'].nil?
      end
    end

    write_to_inventory_file(inventory_hash, 'spec/fixtures/litmus_inventory.yaml')
  end

  desc 'Fips prep a centos machine'
  task :fips_prep do
    inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
    if fips_node = get_fips_node(inventory_hash)
      output = puppetserver.bolt_run_script('spec/support/acceptance/enable-fips.sh', arguments: [ENV['CLOUD_CI']])
      puts "stdout:\n#{output.stdout}\n\nstderr:\n#{output.stderr}"

      # begin
      #   shutdown = puppetserver.run_shell('shutdown -r now')
      # rescue Exception => ex
      #   # After the enable fips script, we need to restart the server node, but this will always result
      #   # in an error. We put this in it's own command because we're going to swallow this error and
      #   # we don't want to swallow any other errors along with it.
      #   puts 'Gulp'
      # end
      # sleep 30
      puts "fips_enabled: #{puppetserver.run_shell('cat /proc/sys/crypto/fips_enabled').stdout}"
      puts "Centos-release: #{puppetserver.run_shell('cat /etc/centos-release').stdout}"
    end
  end

  desc 'Provisions the VMs. This is currently just the puppetserver'
  task :provision_vms do
    if File.exist?('spec/fixtures/litmus_inventory.yaml')
    # Check if a puppetserver VM's already been setup
      begin
        uri = puppetserver.uri
        puts("A puppetserver VM at '#{uri}' has already been set up")
        raise 'oopsie'
        next
      rescue TargetNotFoundError
      # Pass-thru, this means that we haven't set up the puppetserver VM
      end
    end
    provision_list = ENV['PROVISION_LIST'] || 'acceptance'
    Rake::Task['litmus:provision_list'].invoke(provision_list)
    Rake::Task['acceptance:fix_inventory_file'].invoke
    Rake::Task['acceptance:fips_prep'].invoke
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
    puts puppetserver.run_shell('cat /etc/profile.d/puppet-agent.sh').stdout
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
