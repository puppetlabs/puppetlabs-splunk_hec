#!/bin/bash
function cleanup() {
  # bolt_upload_file isn't idempotent, so remove this directory
  # to ensure that later invocations of the setup_servicenow_instance
  # task _are_ idempotent
  rm -rf /tmp/splunk
}
trap cleanup EXIT

function start_splunk() {
  id=`docker ps -q -f name=splunk-enterprise-1 -f status=running`

  if [ ! -z "$id" ]
  then
    echo "Killing the current Splunk container (id = ${id}) ..."
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
  yum install -y yum-utils
  yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
  yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y 
  systemctl start docker
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

function setup_hec_ssl() {
  echo "Setting up HEC SSL..."
  certs=$(puppet config print certdir)
  keys="$(puppet config print privatekeydir)"
  s_cert='/tmp/splunk/puppet_hec.pem'
  s_apps='/opt/splunk/etc/apps'
  s_auth='/opt/splunk/etc/auth'
  /opt/puppetlabs/bin/puppetserver ca generate --certname localhost &>2
  cat "$certs/localhost.pem" "$keys/localhost.pem" "$certs/ca.pem" > $s_cert
  docker cp $s_cert splunk-enterprise-1:$s_auth
  docker exec -u root splunk-enterprise-1 sed -i "/Cert/c\serverCert = $s_auth/puppet_hec.pem" $s_apps/splunk_httpinput/local/inputs.conf
}

function splunk_set_minfreemb() {
  echo "Setting Splunk custom configs..."
  # This is a workaround for issues on Ubuntu where searches fail due to hitting default minfreemb of 5GB.
  docker exec -u root splunk-enterprise-1 /opt/splunk/bin/splunk set minfreemb 500 -auth admin:piepiepie &>2
  # We have to restart Splunk for the changes to get picked up.
  docker exec -u root splunk-enterprise-1 /opt/splunk/bin/splunk restart
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
  # Add Docker repo for Ubuntu
  mkdir -m 0755 -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  # Install Docker and Docker Compose
  apt-get -qq update -y 1>&- 2>&-
  apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y 1>&- 2>&-
fi

printenv
docker system info
start_splunk
wait_for_compose
setup_hec_ssl
splunk_set_minfreemb
exit 0
