#!/bin/bash
# Generates a puppet-signed cert for the Splunk HEC endpoint and outputs the
# combined PEM (server cert + private key + CA cert) to stdout.
#
# Runs on the PE server. The certname argument should be the Splunk node's
# hostname so that SSL hostname verification passes when PE connects to it.
#
# Usage: generate_splunk_cert.sh <certname>

set -e

CERTNAME="$1"
if [ -z "$CERTNAME" ]; then
  echo "Usage: $0 <certname>" >&2
  exit 1
fi

# Generate the cert — idempotent, succeeds even if the cert already exists.
/opt/puppetlabs/bin/puppetserver ca generate --certname "$CERTNAME" >/dev/null 2>&1 || true

CERTDIR=$(puppet config print certdir)
KEYDIR=$(puppet config print privatekeydir)

# Output cert + private key only. Splunk's serverCert does not need the CA cert,
# and including it can cause Splunk's PEM parser to reject the file.
cat "$CERTDIR/$CERTNAME.pem" "$KEYDIR/$CERTNAME.pem"
