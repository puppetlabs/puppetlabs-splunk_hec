# frozen_string_literal: true

require 'spec_helper'

describe 'splunk_hec' do
  let(:pre_condition) do
    <<-MANIFEST
    # Define the pe-puppetserver service
    Service { 'pe-puppetserver':
    }

    # pe_ini_setting is a PE-only resource. Since PE modules are private, we
    # make the resource a defined type for the unit tests. Note that we still
    # have to use pe_ini_setting instead of ini_setting for backwards compatibility.
    define pe_ini_setting (
      Optional[Any] $ensure  = undef,
      Optional[Any] $path    = undef,
      Optional[Any] $section = undef,
      Optional[Any] $setting = undef,
      Optional[Any] $value   = undef,
    ) {
      ini_setting { $title:
        ensure  => $ensure,
        path    => $path,
        section => $section,
        setting => $setting,
        value   => $value,
      }
    }
    MANIFEST
  end
  let(:params) do
    {
      'url'   => 'foo_url',
      'token' => 'foo_token',
    }
  end

  context 'enable_reports is false' do
    let(:params) do
      p = super()
      p['enable_reports'] = false
      p
    end

    it { is_expected.not_to contain_pe_ini_setting('enable splunk hec') }
  end

  context 'enable_reports is true' do
    let(:params) do
      p = super()
      p['enable_reports'] = true
      p
    end

    context "sets 'reports' setting to 'puppetdb,splunk_hec' (default behavior)" do
      it { is_expected.to contain_pe_ini_setting('enable splunk_hec').with_value('puppetdb,splunk_hec') }
    end

    context "set 'reports' setting to $reports if $reports != ''" do
      let(:params) do
        p = super()
        p['reports'] = 'foo,bar,baz'
        p
      end

      it { is_expected.to contain_notify('reports param deprecation warning') }
      it { is_expected.to contain_pe_ini_setting('enable splunk_hec').with_value('foo,bar,baz') }
    end

    context "dynamically calculates the 'reports' setting if $reports == ''" do
      let(:params) do
        p = super()
        p['reports'] = ''
        p
      end

      # rspec-puppet caches the catalog in each test based on the params/facts.
      # To clear the cache, we have to test each value in its own context block so
      # that we can properly reset the params/facts. Since the params shouldn't
      # change in each test, we'll be resetting the facts instead.
      values = {
        'none'                           => 'splunk_hec',
        'foo'                            => 'foo, splunk_hec',
        'foo, bar, baz'                  => 'foo, bar, baz, splunk_hec',
        '  foo  '                        => 'foo, splunk_hec',
        'foo  , bar  , baz'              => 'foo, bar, baz, splunk_hec',
        'splunk_hec'                     => 'splunk_hec',
        '  splunk_hec  '                 => '  splunk_hec  ',
        'foo, splunk_hec'                => 'foo, splunk_hec',
        '  foo, splunk_hec  '            => '  foo, splunk_hec  ',
        'foo  , bar  , baz,  splunk_hec' => 'foo  , bar  , baz,  splunk_hec',
        'foo, splunk_hec, bar'           => 'foo, splunk_hec, bar',
      }
      values.each do |value, expected_setting_value|
        context "when setting = '#{value}'" do
          let(:facts) do
            # This is enough to reset the facts
            {
              '_report_settings_value' => value,
            }
          end

          it do
            allow(Puppet).to receive(:[]).with(anything).and_call_original
            allow(Puppet).to receive(:[]).with(:reports).and_return(value)
            is_expected.to contain_pe_ini_setting('enable splunk_hec').with_value(expected_setting_value)
          end
        end
      end
    end
  end
end
