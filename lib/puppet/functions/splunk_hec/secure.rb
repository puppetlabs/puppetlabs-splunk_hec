# Custom function to mark sensitive data utilized by
# this module as Sensitive types in the Puppet language.
# Sensitive data is redacted from Puppet logs and reports.
Puppet::Functions.create_function(:'splunk_hec::secure') do
  dispatch :secure do
    param 'Hash', :secrets
  end

  def secure(secrets)
    secrets.each do |key, value|
      unless value.nil?
        secrets[key] = Puppet::Pops::Types::PSensitiveType::Sensitive.new(value)
      end
    end
    secrets
  end
end
