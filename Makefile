KIND ?= kind

export KUBECONFIG        ?= ${CURDIR}/.kube/config
export KIND_CLUSTER_NAME ?= fhlb-lab

up:
	$(KIND) create cluster

down:
	$(KIND) delete cluster
