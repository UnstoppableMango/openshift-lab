HELM ?= helm
KIND ?= kind
K9S  ?= k9s

export KUBECONFIG        ?= ${CURDIR}/.kube/config
export KIND_CLUSTER_NAME ?= fhlb-lab

up:
	$(KIND) create cluster --config cluster.yml || true

down: uninstall
	$(KIND) delete cluster || true

uninstall:
	$(HELM) uninstall gitlab-runner -n gitlab-runner || true
	$(HELM) uninstall arc-runner -n arc-runners || true
	$(HELM) uninstall arc -n arc-system || true

# https://gitlab.com/gitlab-org/charts/gitlab-runner/blob/main/values.yaml
gitlab:
	$(HELM) repo add gitlab https://charts.gitlab.io
	$(HELM) repo update
	$(HELM) upgrade gitlab-runner gitlab/gitlab-runner \
		--install \
		--namespace gitlab-runner \
		--create-namespace \
		--set gitlabUrl=http://todo.example.com,runnerRegistrationToken=your-registration-token

# https://github.com/actions/actions-runner-controller/blob/master/charts/gha-runner-scale-set-controller/values.yaml
# https://github.com/actions/actions-runner-controller/blob/master/charts/gha-runner-scale-set/values.yaml
github:
	$(HELM) upgrade arc oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller \
		--install \
		--namespace arc-system \
		--create-namespace
	$(HELM) upgrade arc-runner oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
		--install \
		--namespace arc-runners \
		--create-namespace \
		--set githubConfigUrl="https://github.com/UnstoppableMango/openshift-lab" \
		--set githubConfigSecret.github_token="${GITHUB_PAT}"

k9s:
	$(K9S) --kubeconfig ${KUBECONFIG}
