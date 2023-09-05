# @summary Class to remove old configuration files
#
# @api private
#
# Private subclass to remove configurations utilized by v1 of this module
#
# @example
#   include splunk_hec::v2_cleanup
class splunk_hec::v2_cleanup {
  file { "${settings::confdir}/splunk_hec.yaml":
    ensure  => absent,
  }

  file { "${settings::confdir}/splunk_hec_routes.yaml":
    ensure  => absent,
  }
}
