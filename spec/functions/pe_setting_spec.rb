# frozen_string_literal: true

require 'spec_helper'

describe 'splunk_hec::pe_setting' do
  # please note that these tests are examples only
  # you will need to replace the params and return value
  # with your expectations
  it { is_expected.to run.with_params({ 'password' => 'puppetlabspie' }).and_return({ 'password' => 'puppetlabspie' }) }
end
