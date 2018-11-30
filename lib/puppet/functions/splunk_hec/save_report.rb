require 'yaml'
require 'json'
require 'net/https'
require 'date'

Puppet::Functions.create_function(:'splunk_hec::save_report') do
  def save_report(report, facts, guid)

    report_dir = "/users/cbarker/src/pdx/splunk/discovery/reports/#{guid}"
    Dir.mkdir(report_dir) unless File.exists?(report_dir)
    
    time = DateTime.parse("#{report['time']}")
    epoch = time.strftime('%Q').to_str.insert(-4, '.')

    report['facts'] = facts
    report['plan_guid'] = guid

    splunk_event = {
      "host" => facts['clientcert'],
      "time" => epoch,
      "event"  => report
    }

    report_json = File.open("/users/cbarker/src/pdx/splunk/discovery/reports/#{guid}/#{facts['clientcert']}.json", "w")
    report_json.write(splunk_event.to_json)
    report_json.close

  end
end