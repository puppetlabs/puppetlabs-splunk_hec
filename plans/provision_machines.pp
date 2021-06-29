plan splunk_hec::provision_machines(
  Optional[String] $using = 'abs',
  Optional[String] $image = 'centos-7-x86_64'
) {
  # provision machines, set roles
    run_task("provision::${using}", 'localhost', action => 'provision', platform => $image, vars => "role: server")
}
