# This code is in a fact because attempting to get these values and
# compare them using any other method, like just using the $settings variable
# makes unit testing with rspec-puppet extremely difficult. Putting this code
# here makes it easy to choose the value to assign for this fast and therefore
# easier to code different code paths through the init.pp file.
Facter.add(:splunk_hec_agent_only_node) do
  setcode do
    Dir['/lib/systemd/system/*puppetserver.service'].empty?
  end
end
