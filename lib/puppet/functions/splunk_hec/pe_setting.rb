# frozen_string_literal: true

Puppet::Functions.create_function(:"splunk_hec::pe_setting") do
  dispatch :pe_setting do
    param 'Hash', :password_hash
    return_type 'Hash'
  end

  # the function below is called by puppet and and must match
  # the name of the puppet function above. You can set your
  # as defined in the dispatch method.
  def pe_setting(password_hash)
    password_hash
  end
end
