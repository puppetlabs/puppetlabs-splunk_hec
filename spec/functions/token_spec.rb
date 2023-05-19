# frozen_string_literal: true

require 'spec_helper'

describe 'splunk_hec::token' do
  # please note that these tests are examples only
  # you will need to replace the params and return value
  # with your expectations
  it { is_expected.to run.with_params('12345tfdszxc5432w').and_return('12345tfdszxc5432w') }
  it { is_expected.to run.with_params('test').and_return('test') }
  it { is_expected.to run.with_params(nil).and_return(nil) }
end
