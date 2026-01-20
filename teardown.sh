#!/usr/bin/env bash
set -eu

helm uninstall gharc-runner --namespace arc-system || true
kubectl wait --for=delete autoscalingrunnerset/gharc-runner --timeout=30s --namespace arc-system

helm uninstall gharc --namespace arc-system || true
kubectl wait --for=delete deployment/gharc-gha-rs-controller --timeout=30s --namespace arc-system

oc delete namespace arc-system || true
