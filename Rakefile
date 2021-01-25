require 'puppet_litmus/rake_tasks' if Bundler.rubygems.find_name('puppet_litmus').any?
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-syntax/tasks/puppet-syntax'
require 'puppet_blacksmith/rake_tasks' if Bundler.rubygems.find_name('puppet-blacksmith').any?
require 'github_changelog_generator/task' if Bundler.rubygems.find_name('github_changelog_generator').any?
require 'puppet-strings/tasks' if Bundler.rubygems.find_name('puppet-strings').any?
require 'open3'

def changelog_user
  return unless Rake.application.top_level_tasks.include? "changelog"
  returnVal = nil || JSON.load(File.read('metadata.json'))['author']
  raise "unable to find the changelog_user in .sync.yml, or the author in metadata.json" if returnVal.nil?
  puts "GitHubChangelogGenerator user:#{returnVal}"
  returnVal
end

def changelog_project
  return unless Rake.application.top_level_tasks.include? "changelog"
  returnVal = nil || JSON.load(File.read('metadata.json'))['source'].match(%r{.*/([^/]*)})[1]
  raise "unable to find the changelog_project in .sync.yml or the name in metadata.json" if returnVal.nil?
  puts "GitHubChangelogGenerator project:#{returnVal}"
  returnVal
end

def changelog_future_release
  return unless Rake.application.top_level_tasks.include? "changelog"
  returnVal = "v%s" % JSON.load(File.read('metadata.json'))['version']
  raise "unable to find the future_release (version) in metadata.json" if returnVal.nil?
  puts "GitHubChangelogGenerator future_release:#{returnVal}"
  returnVal
end

PuppetLint.configuration.send('disable_relative')

if Bundler.rubygems.find_name('github_changelog_generator').any?
  GitHubChangelogGenerator::RakeTask.new :changelog do |config|
    raise "Set CHANGELOG_GITHUB_TOKEN environment variable eg 'export CHANGELOG_GITHUB_TOKEN=valid_token_here'" if Rake.application.top_level_tasks.include? "changelog" and ENV['CHANGELOG_GITHUB_TOKEN'].nil?
    config.user = "#{changelog_user}"
    config.project = "#{changelog_project}"
    config.future_release = "#{changelog_future_release}"
    config.exclude_labels = ['maintenance']
    config.header = "# Change log\n\nAll notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/) and this project adheres to [Semantic Versioning](http://semver.org)."
    config.add_pr_wo_labels = true
    config.issues = false
    config.merge_prefix = "### UNCATEGORIZED PRS; GO LABEL THEM"
    config.configure_sections = {
      "Changed" => {
        "prefix" => "### Changed",
        "labels" => ["backwards-incompatible"],
      },
      "Added" => {
        "prefix" => "### Added",
        "labels" => ["feature", "enhancement"],
      },
      "Fixed" => {
        "prefix" => "### Fixed",
        "labels" => ["bugfix"],
      },
    }
  end
else
  desc 'Generate a Changelog from GitHub'
  task :changelog do
    raise <<EOM
The changelog tasks depends on unreleased features of the github_changelog_generator gem.
Please manually add it to your .sync.yml for now, and run `pdk update`:
---
Gemfile:
  optional:
    ':development':
      - gem: 'github_changelog_generator'
        git: 'https://github.com/skywinder/github-changelog-generator'
        ref: '20ee04ba1234e9e83eb2ffb5056e23d641c7a018'
        condition: "Gem::Version.new(RUBY_VERSION.dup) >= Gem::Version.new('2.2.2')"
EOM
  end
end

namespace :launch do
  desc "Start a Splunk instance"
  task :splunk_server do
    system("docker-compose -f spec/support/acceptance/splunk/docker-compose.yml down")
    system("docker-compose -f spec/support/acceptance/splunk/docker-compose.yml up -d --remove-orphans")
    _, stderr, _, _  = Open3.popen3("docker ps -q -f name=splunk_enterprise_1 -f status=running")
    puts "Splunk Server container=#{stderr.gets}"
  end

  task :orch do
    splunk_server = "localhost"
    splunk_port = '8088' 
    splunk_token = 'abcd1234'
    module_path = 'spec/fixtures/modules'
    pe_server = 'unquiet-prank.delivery.puppetlabs.net'
    system("bundle exec bolt task run --modulepath #{module_path} splunk_hec::collect_orchestrator_events --targets localhost pe_console=#{pe_server} splunk_server=#{splunk_server} splunk_port=#{splunk_port} splunk_token=#{splunk_token}")
  end
end

namespace :acceptance do
  require 'puppet_litmus/rake_tasks'
  require_relative './spec/support/acceptance/helpers'
  include TargetHelpers

  desc 'Provisions the VMs. This is currently just the master'
  task :provision_vms do
    if File.exist?('inventory.yaml')
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

  # TODO: This should be refactored to use the https://github.com/puppetlabs/puppetlabs-peadm
  # module for PE setup
  desc 'Sets up PE on the master'
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
      'vars' => {
        'roles' => ['splunk_instance'],
      }
    }]
    write_to_inventory_file(inventory_hash, 'inventory.yaml')
  end

  desc 'Installs the module on the master'
  task :install_module do
    master.run_shell("rm -rf '/etc/puppetlabs/puppet/splunk_hec.yaml'")
    # Ensure that all dependency modules are installed in spec/fixture/modules
    Rake::Task['spec_prep'].invoke
    # This litmus helper installs splunk_hec as well because it's symlinked into fixtures.
    Rake::Task['litmus:install_modules_from_directory'].invoke("#{Dir.pwd}/spec/fixtures/modules",'ssh_nodes')
    master.bolt_upload_file('./spec/support/acceptance/splunk_hec.yaml', '/etc/puppetlabs/puppet/splunk_hec.yaml')
  end

  desc 'Runs the tests'
  task :run_tests do
    # master.bolt_run_script('NUM_TASKS=10 spec/support/acceptance/post_tasks.sh')
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
    FileUtils.rm_f('inventory.yaml')
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

