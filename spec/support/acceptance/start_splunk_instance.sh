#!/bin/bash
function cleanup() {
  # bolt_upload_file isn't idempotent, so remove this directory
  # to ensure that later invocations of the setup_servicenow_instance
  # task _are_ idempotent
  rm -rf /tmp/splunk
}
trap cleanup EXIT

function start_splunk() {
  id=`docker ps -aq -f name=splunk-enterprise-1`

  if [ ! -z "$id" ]
  then
    echo "Removing the existing Splunk container (id = ${id}) ..."
    docker rm --force ${id}
  fi

  docker compose -f /tmp/splunk/docker-compose.yml up -d --remove-orphans

  id=`docker ps -q -f name=splunk-enterprise-1 -f status=running`

  if [ -z "$id" ]
  then
    echo 'Splunk container start failed.'
    exit 1
  fi
  echo 'Splunk container starting...'
}

function yum_install_docker() {
  # Remove packages that conflict with Docker CE on RHEL 8/9
  dnf remove -y docker docker-client docker-client-latest docker-common \
    docker-latest docker-latest-logrotate docker-logrotate docker-engine \
    podman runc 2>/dev/null || true
  dnf install -y yum-utils
  dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
  dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl start docker
}

function apt_install_docker() {
  # Remove packages that conflict with Docker CE on Ubuntu
  for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    apt-get remove -y $pkg 2>/dev/null || true
  done
  mkdir -m 0755 -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get -qq update -y 1>&- 2>&-
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 1>&- 2>&-
}

function compose_starting() {
  docker ps -f name=splunk-enterprise-1 | grep starting
}

function wait_for_compose() {
  r=0
  while [ ! -z "$(compose_starting)" ] && [ $r -lt 10 ]
  do
    sleep 30
    ((r++))
  done
}

function check_ssl_cert() {
  # The cert is uploaded to /tmp/splunk/puppet_hec.pem by setup_splunk_targets
  # before this script runs. docker-compose.yml mounts it as Splunk's default
  # server.pem so HEC uses it without any explicit serverCert configuration.
  # It lives under /tmp/splunk/ so the cleanup trap removes it with everything else.
  if [ ! -f '/tmp/splunk/puppet_hec.pem' ]; then
    echo "ERROR: /tmp/splunk/puppet_hec.pem not found — expected to be uploaded by setup_splunk_targets" >&2
    exit 1
  fi
  chmod 644 /tmp/splunk/puppet_hec.pem
}

YUM=$(cat /etc/*-release | grep 'CentOS\|rhel')

if ! which docker &>/dev/null; then
  if [ -n "$YUM" ]; then
    yum_install_docker
  else
    apt_install_docker
  fi
fi

check_ssl_cert
start_splunk
wait_for_compose
exit 0
