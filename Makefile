HELM ?= helm
KIND ?= kind

export KUBECONFIG        ?= ${CURDIR}/.kube/config
export KIND_CLUSTER_NAME ?= fhlb-lab

up:
	$(KIND) create cluster

down: uninstall
	$(KIND) delete cluster

uninstall:
	$(HELM) uninstall gitlab-runner || true

gitlab:
	$(HELM) repo add gitlab https://charts.gitlab.io
	$(HELM) repo update
	$(HELM) upgrade gitlab-runner gitlab/gitlab-runner \
		--install \
		--namespace gitlab-runner \
		--create-namespace \
		--values ${CURDIR}/apps/gitlab/values.yml

github: # TODO: Currently AI generated, needs review
	$(HELM) repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
	$(HELM) repo update
	$(HELM) upgrade actions-runner-controller actions-runner-controller/actions-runner-controller \
		--install \
		--namespace actions-runner-system \
		--create-namespace \
		--values ${CURDIR}/apps/github/values.yml
