# frozen_string_literal: true

Facter.add(:splunk_hec_agent_only_node) do
  setcode do
    if Facter.value(:os)['family'].eql?('RedHat') || Facter.value(:os)['family'].eql?('Suse')
      Dir['/etc/sysconfig/*puppetserver'].empty?
    else
      Dir['/etc/default/*puppetserver'].empty?
    end
  end
end
