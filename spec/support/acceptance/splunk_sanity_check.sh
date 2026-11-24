#!/bin/bash
# Runs on the Splunk node after the container starts. Sends one event over HEC
# and searches for it, so a Splunk that cannot index or search fails the job
# right away rather than failing every search based spec later.
#
# Prints disk usage and the diskUsage settings Splunk is using for context.

echo '--- host disk'
df -h / 2>&1
docker system df 2>&1
echo '--- diskUsage settings as Splunk sees them'
docker exec splunk-enterprise-1 /opt/splunk/bin/splunk btool server list diskUsage --debug 2>&1 | head -10

echo '--- send one event over HEC'
for i in $(seq 1 30); do
  health=$(curl -sk -m 10 https://localhost:8088/services/collector/health)
  echo "$health" | grep -q 'HEC is healthy' && break
  echo "waiting for HEC (attempt $i): $health"
  sleep 10
done
curl -sk -H 'Authorization: Splunk abcd1234' \
  -d '{"event":"sanity","sourcetype":"puppet:summary","host":"sanity-host"}' \
  https://localhost:8088/services/collector/event
echo

echo '--- search for it'
for i in $(seq 1 12); do
  out=$(curl -sk -u admin:piepiepie https://localhost:8089/services/search/v2/jobs/export -d output_mode=json \
    -d search='search index=* sourcetype="puppet:summary" host="sanity-host" earliest=-10m | stats count')
  echo "$out" | grep -q '"count":"1"' && { echo "$out"; echo 'Splunk sanity check passed'; exit 0; }
  echo "attempt $i: $out"
  sleep 10
done
echo 'Splunk sanity check failed' >&2
exit 1
