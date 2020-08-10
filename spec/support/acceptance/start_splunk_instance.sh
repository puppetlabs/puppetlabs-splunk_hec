#!/bin/bash

function cleanup() {
  # bolt_upload_file isn't idempotent, so remove this directory
  # to ensure that later invocations of the setup_servicenow_instance
  # task _are_ idempotent
  rm -rf /tmp/splunk
}
trap cleanup EXIT

rep=$(curl -s --unix-socket /var/run/docker.sock http://ping > /dev/null)
status=$?

if [ "$status" == "7" ]; then
    apt-get -qq update -y 1>&- 2>&-
    apt-get install -qq docker.io -y 1>&- 2>&-
    apt-get install -qq docker-compose -y 1>&- 2>&-
fi

set -e

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
exit 0
