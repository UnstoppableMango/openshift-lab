#!/usr/bin/env bash
set -eu

[ -z "${GITHUB_REPOSITORY:-}" ] && echo "Set GITHUB_REPOSITORY to your GitHub repository (e.g., username/repo)" && exit 1
[ -z "${GITHUB_PAT:-}" ] && echo "Set GITHUB_PAT to your GitHub Personal Access Token" && exit 1

CONTROLLER_CHART='oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller'
SCALE_SET_CHART='oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set'

helm upgrade gharc "$CONTROLLER_CHART" \
  --install \
  --namespace arc-system \
  --create-namespace

oc rollout status deployment/gharc-gha-rs-controller \
  --namespace arc-system

oc adm policy add-scc-to-user privileged gharc-gha-rs-controller \
  --namespace arc-system

helm upgrade gharc-runner "$SCALE_SET_CHART" \
  --install \
  --namespace arc-runners \
  --create-namespace \
  --set "githubConfigUrl=https://github.com/$GITHUB_REPOSITORY" \
  --set "githubConfigSecret.github_token=$GITHUB_PAT" \
  --set minRunners=1 \
  --set containerMode.type=dind
