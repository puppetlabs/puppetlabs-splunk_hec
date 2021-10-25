#!/bin/bash
function cleanup() {
  # bolt_upload_file isn't idempotent, so remove this directory
  # to ensure that later invocations of the setup_servicenow_instance
  # task _are_ idempotent
  rm -rf /tmp/splunk
}
trap cleanup EXIT

function start_splunk() {
  id=`docker ps -q -f name=splunk_enterprise_1 -f status=running`

  if [ ! -z "$id" ]
  then
    echo "Killing the current Splunk container (id = ${id}) ..."
    docker rm --force ${id}
  fi

  docker-compose -f /tmp/splunk/docker-compose.yml up -d --remove-orphans

  id=`docker ps -q -f name=splunk_enterprise_1 -f status=running`

  if [ -z "$id" ]
  then
    echo 'Splunk container start failed.'
    exit 1
  fi
  echo 'Splunk container start succeeded.'
}

function yum_install_docker() {
  yum install -y yum-utils
  yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
  yum install docker-ce docker-ce-cli containerd.io -y
  systemctl start docker

  curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  mv /usr/local/bin/docker-compose /usr/bin/docker-compose
  chmod +x /usr/bin/docker-compose
}

function compose_starting() {
  docker ps --all | grep starting
}

function wait_for_compose() {
  while [ 1 ]
  do
    if [ -z "$(compose_starting)" ]
    then
      exit
    fi
  done
}

YUM=$(cat /etc/*-release | grep 'CentOS\|rhel')

nodocker=$(which docker 2>&1 | grep "no docker")
status=$?

if [ ! -z "$nodocker" ]
then
  if [ ! -z "$YUM" ]; then
    yum_install_docker
  fi
else
  apt-get -qq update -y 1>&- 2>&-
  apt-get install -qq docker.io -y 1>&- 2>&-
  apt-get install -qq docker-compose -y 1>&- 2>&-
fi

printenv
docker system info
start_splunk
wait_for_compose
exit 0
