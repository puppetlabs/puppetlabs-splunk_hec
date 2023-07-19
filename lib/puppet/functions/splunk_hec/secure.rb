# Custom function to mark sensitive data utilized by
# this module as Sensitive types in the Puppet language.
# Sensitive data is redacted from Puppet logs and reports.
Puppet::Functions.create_function(:'splunk_hec::secure') do
  dispatch :secure do
    param 'String', :secret
  end

  def secure(secret)
    Puppet::Pops::Types::PSensitiveType::Sensitive.new(secret)
  end
end
