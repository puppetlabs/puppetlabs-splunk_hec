# @summary Provisions machines
# @api private
#
# Provisions one PE server and one dedicated Splunk node. The Splunk node runs
# the Splunk container the acceptance tests send events to, so each test matrix
# gets its own Splunk instance.
#
# @example
#   splunk_hec::acceptance::provision_machines
#
# @param [Optional[String]] using
#   provision service
# @param [Optional[String]] image
#   os image for the PE server
# @param [Optional[String]] splunk_image
#   os image for the Splunk node
plan splunk_hec::acceptance::provision_machines(
  Optional[String] $using        = 'abs',
  Optional[String] $image        = 'redhat-9-x86_64',
  Optional[String] $splunk_image = undef,
) {
  $splunk_platform = $splunk_image ? {
    undef   => $using ? {
      'provision_service' => 'rhel-9',
      default             => 'redhat-9-x86_64',
    },
    default => $splunk_image,
  }

  # provision machines, set roles
  run_task("provision::${using}", 'localhost', action => 'provision', platform => $image, vars => 'role: server')
  run_task("provision::${using}", 'localhost', action => 'provision', platform => $splunk_platform, vars => 'role: splunk_node')
}
