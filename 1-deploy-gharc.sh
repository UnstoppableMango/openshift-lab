#!/usr/bin/env bash
set -eu

[ -z "${GITHUB_REPOSITORY:-}" ] && echo "Set GITHUB_REPOSITORY to your GitHub repository (e.g., username/repo)" && exit 1
[ -z "${GITHUB_PAT:-}" ] && echo "Set GITHUB_PAT to your GitHub Personal Access Token" && exit 1

NAMESPACE='arc-system'
CONTROLLER_CHART='oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller'
SCALE_SET_CHART='oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set'

helm upgrade gharc "$CONTROLLER_CHART" \
  --install \
  --namespace "$NAMESPACE" \
  --create-namespace

oc rollout status deployment/gharc-gha-rs-controller \
  --namespace "$NAMESPACE"

oc adm policy add-scc-to-user privileged \
  --serviceaccount gharc-gha-rs-controller \
  --namespace "$NAMESPACE"

helm upgrade gharc-runner "$SCALE_SET_CHART" \
  --install \
  --namespace "$NAMESPACE" \
  --set "githubConfigUrl=https://github.com/$GITHUB_REPOSITORY" \
  --set "githubConfigSecret.github_token=$GITHUB_PAT" \
  --set minRunners=1 \
  --set containerMode.type=kubernetes-novolume

oc adm policy add-scc-to-user privileged \
  --serviceaccount gharc-runner-gha-rs-kube-mode \
  --namespace "$NAMESPACE"
