#!/usr/bin/env bash
set -eu

helm uninstall gharc-runner --namespace arc-runners || true
helm uninstall gharc --namespace arc-system || true

oc delete namespace arc-runners || true
oc delete namespace arc-system || true
