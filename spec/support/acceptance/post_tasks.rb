require 'common_events_library'

PE_CONSOLE = ENV['PE_CONSOLE']
NUM_TASKS = ENV['NUM_TASKS'] || 5
USERNAME = ENV['PT_PE_USERNAME'] || 'admin'
PASSWORD = ENV['PT_PE_PASSWORD'] || 'pie'

raise 'usage: PE_CONSOLE=<fqdn> post_tasks.rb' if PE_CONSOLE.nil?

orchestrator = Orchestrator.new(PE_CONSOLE, USERNAME, PASSWORD, ssl_verify: false)

r = 1..NUM_TASKS
puts 'Sending batch tasks to PE'
r.each do |x|
  puts "Injecting task [#{x}]"
  response = orchestrator.run_facts_task([PE_CONSOLE])
  raise "Failed to inject tasks [#{x}]" unless response.code == '202'
end
