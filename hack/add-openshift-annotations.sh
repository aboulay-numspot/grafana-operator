#!/bin/bash

OPENSHIFT_VERSIONS="\"v4.11-v4.16\""

{
    echo ""
    echo "  # OpenShift specific annotations"
    echo "  com.redhat.openshift.versions: $OPENSHIFT_VERSIONS"
} >> bundle/metadata/annotations.yaml

echo "LABEL com.redhat.openshift.versions=$OPENSHIFT_VERSIONS" >> bundle.Dockerfile
