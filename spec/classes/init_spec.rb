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

    # Ditto for pe_ini_subsetting
    define pe_ini_subsetting (
      Optional[Any] $ensure               = undef,
      Optional[Any] $path                 = undef,
      Optional[Any] $section              = undef,
      Optional[Any] $setting              = undef,
      Optional[Any] $subsetting           = undef,
      Optional[Any] $subsetting_separator = undef,
    ) {
      ini_subsetting { $title:
        ensure               => $ensure,
        path                 => $path,
        section              => $section,
        subsetting           => $subsetting,
        subsetting_separator => $subsetting_separator,
      }
    }

    define cron (
      Optional[Any] $ensure  = undef,
      Optional[Any] $command = undef,
      Optional[Any] $user    = undef,
      Optional[Any] $minute  = undef,
    ) {}
    MANIFEST
  end

  let(:params) do
    {
      url: 'foo_url',
      token: 'foo_token',
    }
  end

  let(:facts) do
    { splunk_hec_is_pe: true }
  end

  context 'enable_reports is false' do
    let(:params) do
      super().merge(enable_reports: false)
    end

    it { is_expected.to have_pe_ini_setting_resource_count(0) }
    it { is_expected.to have_pe_ini_subsetting_resource_count(0) }
  end

  context 'enable_reports is true' do
    let(:params) do
      super().merge(enable_reports: true)
    end

    context "sets 'reports' setting to 'splunk_hec' (default behavior)" do
      it { is_expected.to contain_pe_ini_subsetting('enable splunk_hec').with_subsetting('splunk_hec') }
      it { is_expected.to have_pe_ini_setting_resource_count(0) }
      it { is_expected.to have_pe_ini_subsetting_resource_count(1) }
    end

    context "set 'reports' setting to $reports if $reports != ''" do
      let(:params) do
        p = super()
        p['reports'] = 'foo,bar,baz'
        p
      end

      it { is_expected.to contain_notify('reports param deprecation warning') }
      it { is_expected.to contain_pe_ini_setting('enable splunk_hec').with_value('foo,bar,baz') }
      it { is_expected.to have_pe_ini_subsetting_resource_count(0) }
    end

    context 'handles $include_api_collection correctly' do
      it { is_expected.to contain_cron('collectpeapi') }

      context 'with api collection turned off' do
        let(:params) do
          super().merge(include_api_collection: false)
        end

        it { is_expected.to have_cron_resource_count(0) }
      end
    end
  end
end
