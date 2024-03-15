# frozen_string_literal: true

require 'spec_helper'
require 'rspec-puppet-utils'

describe 'splunk_hec' do
  let(:pre_condition) do
    <<-MANIFEST
    # Define the pe-puppetserver service
    Service { 'pe-puppetserver':
    }

    # Define the puppetserver service
    Service { 'puppetserver':
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

    class pe_event_forwarding (
      Optional[String] $confdir = "/tmp",
    ) {}

    class {pe_event_forwarding:}
    MANIFEST
  end

  let(:params) do
    {
      'url'   => 'foo_url',
      'token' => 'foo_token',
    }
  end

  let(:confdir) { '/tmp' }
  let(:event_forwarding_base) { "#{confdir}/pe_event_forwarding/processors.d" }
  let(:facts) do
    {
      splunk_hec_agent_only_node: false
    }
  end

  context 'on a server node' do
    let(:facts) do
      {
        splunk_hec_is_pe: true
      }
    end

    context 'enable_reports is false' do
      let(:params) do
        p = super()
        p['enable_reports'] = false
        p
      end

      it { is_expected.to have_pe_ini_setting_resource_count(0)    }
      it { is_expected.to have_pe_ini_subsetting_resource_count(0) }
      it { is_expected.not_to contain_file("#{event_forwarding_base}/splunk_hec") }
      it { is_expected.not_to contain_file("#{event_forwarding_base}/splunk_hec/util_splunk_hec.rb") }
      it { is_expected.not_to contain_file("#{event_forwarding_base}/splunk_hec.rb") }
    end

    context 'enable_reports is true' do
      let(:params) do
        p = super()
        p['enable_reports'] = true
        p
      end

      context "sets 'reports' setting to 'splunk_hec' (default behavior)" do
        it { is_expected.to contain_pe_ini_subsetting('enable splunk_hec').with_subsetting('splunk_hec') }
        it { is_expected.to have_pe_ini_setting_resource_count(0) }
        it { is_expected.to have_pe_ini_subsetting_resource_count(1) }
      end
    end

    context 'disabled is set to true' do
      let(:params) do
        p = super()
        p['disabled'] = true
        p['enable_reports'] = true
        p['manage_routes'] = true
        p
      end

      it { is_expected.to contain_pe_ini_subsetting('enable splunk_hec').with_setting('reports').with_ensure('absent') }
      it { is_expected.to contain_pe_ini_setting('enable splunk_hec_routes.yaml').with_setting('route_file').with_ensure('absent') }
      it { is_expected.to have_pe_ini_subsetting_resource_count(1) }
      it { is_expected.to have_pe_ini_setting_resource_count(1) }
    end

    context 'events_reporting_enabled' do
      let(:params) do
        p = super()
        p['events_reporting_enabled'] = true
        p
      end

      it {
        is_expected.to contain_file("#{event_forwarding_base}/splunk_hec")
          .with(ensure: 'directory')
      }

      it {
        is_expected.to contain_file("#{event_forwarding_base}/splunk_hec/util_splunk_hec.rb")
          .with(
          ensure: 'file',
          mode: '0755',
        )
      }

      it {
        is_expected.to contain_file("#{event_forwarding_base}/splunk_hec.rb")
          .with(
          ensure: 'file',
          mode: '0755',
        )
      }
    end
  end

  context 'on an agent node' do
    # enable_reports should always be false on an agent node.
    let(:params) do
      p = super()
      p['enable_reports'] = false
      p
    end
    let(:facts) do
      {
        splunk_hec_agent_only_node: true
      }
    end

    context 'events_reporting not enabled' do
      it { is_expected.to have_pe_ini_setting_resource_count(0)    }
      it { is_expected.to have_pe_ini_subsetting_resource_count(0) }
      it { is_expected.not_to contain_file("#{event_forwarding_base}/splunk_hec") }
      it { is_expected.not_to contain_file("#{event_forwarding_base}/splunk_hec/util_splunk_hec.rb") }
      it { is_expected.not_to contain_file("#{event_forwarding_base}/splunk_hec.rb") }
    end

    context 'events_reporting enabled' do
      let(:params) do
        p = super()
        p['events_reporting_enabled'] = true
        p
      end

      it { is_expected.to have_pe_ini_setting_resource_count(0)    }
      it { is_expected.to have_pe_ini_subsetting_resource_count(0) }
      it {
        is_expected.to contain_file("#{confdir}/splunk_hec/settings.yaml")
          .with(
            owner: 'root',
            group: 'root',
          )
      }
      it {
        is_expected.to contain_file("#{confdir}/splunk_hec/hec_secrets.yaml")
          .with(
            owner: 'root',
            group: 'root',
          )
      }
      it { is_expected.to contain_file("#{event_forwarding_base}/splunk_hec") }
      it { is_expected.to contain_file("#{event_forwarding_base}/splunk_hec/util_splunk_hec.rb") }
      it { is_expected.to contain_file("#{event_forwarding_base}/splunk_hec.rb") }
    end
  end
end
