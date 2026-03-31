namespace :acceptance do
  require_relative '../spec/support/acceptance/helpers'
  include TargetHelpers

  desc 'Provisions the PE server VMs and a matching set of dedicated Splunk nodes'
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

    # Provision a matching set of dedicated Splunk nodes if a splunk list exists
    # for this provision list (e.g. acceptance_splunk for acceptance).
    splunk_provision_list = "#{provision_list}_splunk"
    if YAML.safe_load(File.read('provision.yaml')).key?(splunk_provision_list)
      Rake::Task['litmus:provision_list'].reenable
      Rake::Task['litmus:provision_list'].invoke(splunk_provision_list)
    end

    inventory_hash = inventory_hash_from_inventory_file
    begin
      # If a fips node is present, assign the correct roles to the fips node and the splunk node
      fips_node = inventory_hash['groups'].detect {|g| g['name'] == 'ssh_nodes'}['targets'].detect {|t| t['facts']['platform'].match(/fips/)}
      fips_node['vars'] = {'role' => 'server'}
      splunk_node = inventory_hash['groups'].detect {|g| g['name'] == 'ssh_nodes'}['targets'].detect {|t| !t['facts']['platform'].match(/fips/)}
      splunk_node['vars'] = {'role' => 'splunk_node'}
    rescue StandardError
      puts 'no fips node found.'
    end

    # Pair each PE server with its dedicated Splunk node by index and store the
    # pairing in the PE server's vars so tasks and tests can look it up later.
    ssh_nodes = inventory_hash['groups'].detect { |g| g['name'] == 'ssh_nodes' }['targets']
    pe_servers  = ssh_nodes.select { |t| t.dig('vars', 'role') == 'server' }
    splunk_nodes = ssh_nodes.select { |t| t.dig('vars', 'role') == 'splunk_node' }
    pe_servers.zip(splunk_nodes).each do |pe, splunk|
      next if splunk.nil?
      pe['vars']['splunk_target'] = splunk['uri']
    end

    # Remove bad username and password keys as a result of a provision module bug
    ssh_nodes.each do |target|
      target['config']['ssh'].delete("password") if target['config']['ssh']['password'].nil?
      target['config']['ssh'].delete("user") if target['config']['ssh']['user'].nil?
    end
    write_to_inventory_file(inventory_hash, 'spec/fixtures/litmus_inventory.yaml')
    Rake::Task['acceptance:configure_inventory'].invoke
  end

  desc 'Post-process the inventory file with settings required for all bolt operations'
  task :configure_inventory do
    inventory_hash = inventory_hash_from_inventory_file
    # Pin SSH encryption algorithms at the group level so all bolt operations use
    # a known-good set. The system SSH config may specify OpenSSH cipher modifiers
    # (e.g. ^aes128-gcm) that net-ssh does not understand, producing an empty
    # client cipher list and causing algorithm negotiation to fail.
    inventory_hash['groups'].each do |group|
      group['config'] ||= {}
      group['config']['ssh'] ||= {}
      group['config']['ssh']['encryption-algorithms'] = %w[aes256-ctr aes192-ctr aes128-ctr]
    end
    write_to_inventory_file(inventory_hash, 'spec/fixtures/litmus_inventory.yaml')
  end

  desc 'clone puppetlabs-pe_event_forwarding module to test host'
  task :upload_pe_event_forwarding_module do
    # Uploads run in parallel so spinner output from multiple threads will interleave
    # in the terminal. This is cosmetic only.
    threads = puppetserver.map do |target|
      Thread.new do
        message = "Installing puppetlabs-pe_event_forwarding module on #{target.uri} !"
        spinner = start_spinner(message)
        target.run_shell('[[ -d /etc/puppetlabs/code/environments/production/modules/pe_event_forwarding ]] && rm /etc/puppetlabs/code/environments/production/modules/pe_event_forwarding -rf', expect_failures: true)
        target.run_shell('rm -rf /etc/puppetlabs/code/environments/production/modules/pe_event_forwarding', expect_failures: true)
        target.bolt_upload_file('./spec/fixtures/modules/pe_event_forwarding', '/etc/puppetlabs/code/environments/production/modules')
        stop_spinner(spinner)
      end
    end
    threads.each(&:join)
  end

  desc 'Sets up PE on the server'
  task :setup_pe do
    include ::BoltSpec::Run
    inventory_hash = inventory_hash_from_inventory_file
    target_nodes = find_targets(inventory_hash, 'ssh_nodes')

    config = { 'modulepath' => File.join(Dir.pwd, 'spec', 'fixtures', 'modules') }
    params = {}
    params.merge!(puppet_version: ENV['PUPPET_VERSION']) unless ENV['PUPPET_VERSION'].nil?

    message = "Installing Puppet Enterprise on targets in litmus_inventory.yaml !"
    install_spinner = start_spinner(message)
    bolt_result = run_plan('splunk_hec::acceptance::server_setup', params, config: config, inventory: inventory_hash.clone)
    stop_spinner(install_spinner)
    puts bolt_result['status']
    raise "setup_pe failed:\n#{JSON.pretty_generate(bolt_result)}" if bolt_result['status'] == 'failure'
  end

  desc 'Sets up the Splunk instance'
  task :setup_splunk_targets do
    if ENV['SPLUNK_CI_URL']
      puts 'Using persistent Splunk CI instance, skipping local setup'
      next
    end

    inventory_hash = LitmusHelpers.inventory_hash_from_inventory_file
    ssh_nodes = inventory_hash['groups'].detect { |g| g['name'] == 'ssh_nodes' }['targets']
    pe_server_nodes = ssh_nodes.select { |t| t.dig('vars', 'role') == 'server' }

    pe_server_nodes.each_with_index do |pe_node, i|
      splunk_uri = pe_node.dig('vars', 'splunk_target')
      unless splunk_uri
        puts "No splunk_target paired with #{pe_node['uri']}, skipping"
        next
      end

      pe_target     = Target.new(pe_node['uri'])
      splunk_target = Target.new(splunk_uri)
      splunk_hostname = splunk_uri.split(':').first

      puts "Setting up Splunk Enterprise on #{splunk_uri} for PE server #{pe_node['uri']}"
      splunk_target.bolt_upload_file('./spec/support/acceptance/splunk', '/tmp/splunk')

      # Generate a puppet-signed cert on the PE server for the Splunk node's hostname
      # and upload it before running the start script, so setup_hec_ssl can configure
      # the container without needing puppetserver installed on the Splunk node.
      puts "Generating puppet-signed cert for #{splunk_hostname} on #{pe_node['uri']}"
      cert_pem = pe_target.bolt_run_script(
        'spec/support/acceptance/generate_splunk_cert.sh',
        arguments: splunk_hostname,
      ).stdout
      require 'tempfile'
      Tempfile.create(['puppet_hec', '.pem']) do |f|
        f.write(cert_pem)
        f.flush
        splunk_target.bolt_upload_file(f.path, '/tmp/splunk/puppet_hec.pem')
      end

      puts "Starting Splunk on #{splunk_uri}"
      result = splunk_target.bolt_run_script('spec/support/acceptance/start_splunk_instance.sh').stdout.chomp
      puts result

      # HEC token is hard coded because it will always be the same in the splunk container
      instance  = "#{splunk_hostname}:8088"
      hec_token = 'abcd1234'

      puts "Updating inventory with Splunk HEC credentials for #{splunk_uri}"
      splunk_group = inventory_hash['groups'].find { |g| g['name'] =~ %r{splunk} }
      unless splunk_group
        splunk_group = { 'name' => 'splunk_nodes' }
        inventory_hash['groups'].push(splunk_group)
        splunk_group['targets'] = []
      end
      splunk_group['targets'][i] = {
        'uri' => instance,
        'config' => {
          'transport' => 'remote',
          'remote' => { 'hec_token' => hec_token },
        },
        'facts' => {
          'platform' => 'splunk_hec',
          'provisioner' => 'docker',
          'container_name' => 'splunk_enterprise_1',
        },
        'vars' => { 'role' => ['splunk_instance'] },
      }
    end
    write_to_inventory_file(inventory_hash, 'spec/fixtures/litmus_inventory.yaml')
  end

  desc 'Installs the module on the puppetserver'
  task :install_module do
    include ::BoltSpec::Run
    include PuppetLitmus::RakeHelper
    inventory_hash = inventory_hash_from_inventory_file
    module_tar = Dir.glob('pkg/*.tar.gz').max_by { |f| File.mtime(f) }
    raise "Unable to find package in 'pkg/*.tar.gz'" if module_tar.nil?

    threads = puppetserver.map do |target|
      Thread.new do
        install_module(inventory_hash, [target.uri], module_tar)
      end
    end
    threads.each(&:join)
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
      :setup_splunk_targets,
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
    Rake::Task['litmus:tear_down'].invoke
    FileUtils.rm_f('spec/fixtures/litmus_inventory.yaml')
  end

  desc 'Task to run rspec tests against multiple targets'
  task :ci_run_tests do
    include ::BoltSpec::Run

    # Run the tests
    config = { 'modulepath' => File.join(Dir.pwd, 'spec', 'fixtures', 'modules') }
    puppetserver.each do |server|
      message = "Running rspec tests against #{server.uri} !"
      spec_spinner = start_spinner(message)
      params = { 'sut' => server.uri, 'format' => 'documentation' }
      bolt_result = run_task('provision::run_tests', 'localhost', params, config: config)
      stop_spinner(spec_spinner)
      puts "Finished running rspec tests against #{server.uri} !\n"
      if bolt_result[0]['value'].has_key?('_error')
        test_result = bolt_result[0]['value']['_error']['msg'].to_json
        puts JSON.parse(test_result)
        exit 1
      else
        test_result = bolt_result[0]['value']['result'].to_json
        puts JSON.parse(test_result)
      end
    end
  end

  desc 'Task for CI'
  task :ci_tests do
    begin
      Rake::Task['acceptance:setup'].invoke
      Rake::Task['acceptance:ci_run_tests'].invoke
    ensure
      Rake::Task['acceptance:tear_down'].invoke
    end
  end
end
