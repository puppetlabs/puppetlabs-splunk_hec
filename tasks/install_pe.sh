#!/bin/bash
#
# @summary Download and install PE
# @api private
#
# Download and install Puppet Enterprise on a target node.
#
# @example
#   pe_event_forwarding::acceptance::pe_server_setup
#
# @param [Optional[String]] version
#   Sets the version of the PE to install
# @param [Optional[Hash]] pe_settings
#   Sets PE settings including password
# Task parameters:
#   PT_url                - Full HTTPS URL to the PE installer tarball
#   PT_console_password   - PE console admin password
export LANG=en_US.UTF-8

_tmp_stderr="$(mktemp)"
exec 2>>"$_tmp_stderr"

fail() {
  if [[ -s "$_tmp_stderr" ]]; then
    echo "{ \"status\": \"error\", \"message\": \"$1\", \"stderr\": \"$(tr '\n' ' ' <"$_tmp_stderr")\" }"
  else
    echo "{ \"status\": \"error\", \"message\": \"$1\" }"
  fi
  exit "${2:-1}"
}

success() {
  echo "$1"
  exit 0
}

# Unpack PT_* environment variables into plain names
for v in ${!PT_*}; do
  declare "${v#*PT_}"="${!v}"
done

(( EUID == 0 )) || fail "This task must be run as root"

[[ -n "$url" ]]              || fail "url parameter is required"
[[ -n "$console_password" ]] || fail "console_password parameter is required"

_work_dir="$(mktemp -d)"
cd "$_work_dir" || fail "Failed to create working directory"

echo "Downloading PE tarball from: $url"
curl -Lf "$url" -o pe.tar.gz || fail "Failed to download PE tarball from: $url"

echo "Extracting PE tarball..."
tar xf pe.tar.gz || fail "Failed to extract PE tarball"

pe_dir=$(find "$_work_dir" -maxdepth 1 -type d -name 'puppet-enterprise-*' | head -1)
[[ -n "$pe_dir" ]] || fail "Could not find extracted PE directory in $_work_dir"

# Write a minimal pe.conf
cat > "$_work_dir/pe.conf" <<PECONF
{
  "console_admin_password": "${console_password}"
  "puppet_enterprise::puppet_master_host": "%{::trusted.certname}"
  "pe_install::puppet_master_dnsaltnames": ["puppet"]
  "puppet_enterprise::profile::master::check_for_updates": false
  "puppet_enterprise::send_analytics_data": false
}
PECONF

echo "Starting PE installation (this may take several minutes)..."
chmod +x "${pe_dir}/puppet-enterprise-installer"
"${pe_dir}/puppet-enterprise-installer" -y -c "$_work_dir/pe.conf" \
  || fail "PE installation failed"

echo "Running Puppet agent (pass 1 of 2)..."
/opt/puppetlabs/bin/puppet agent -t; true

echo "Running Puppet agent (pass 2 of 2)..."
/opt/puppetlabs/bin/puppet agent -t; true

success '{ "status": "success", "message": "PE installed successfully" }'
