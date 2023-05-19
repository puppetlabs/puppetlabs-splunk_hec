# frozen_string_literal: true

# https://github.com/puppetlabs/puppet-specifications/blob/master/language/func-api.md#the-4x-api
Puppet::Functions.create_function(:"splunk_hec::token") do
  dispatch :token do
    param 'Any', :str
    return_type 'Any'
  end

  # the function below is called by puppet and and must match
  # the name of the puppet function above. You can set your
  def token(str)
    str
  end
end
