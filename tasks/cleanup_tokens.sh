#!/bin/bash

declare -x PUPPET='/opt/puppetlabs/bin/puppet'
declare -x CURL='/bin/curl'

SSLDIR=$($PUPPET config print ssldir --section master)
CERTNAME=$($PUPPET config print certname --section master)

USERNAME="$PT_username"

$CURL -X DELETE "https://$CERTNAME:4433/rbac-api/v2/tokens" \
  --tlsv1 \
  --cacert $SSLDIR/certs/ca.pem \
  --cert $SSLDIR/certs/$CERTNAME.pem \
  --key $SSLDIR/private_keys/$CERTNAME.pem \
  -d "{\"revoke_tokens_by_usernames\": [\"$USERNAME\"]}"