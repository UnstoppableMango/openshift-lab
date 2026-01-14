# OpenShift Lab

The repo contains experiments deploying an managing an OpenShift cluster.

## Usage

Create a local cluster using kind.
The kubeconfig will be created at `<repo>/.kube/config`

```shell
$ make up
kind create cluster
```

Deploy a GitLab runner to the local kind cluster.

```shell
$ make gitlab
helm repo add gitlab https://charts.gitlab.io
helm repo update
helm upgrade --install gitlab-runner gitlab/gitlab-runner # ... elided
```

Deploy GitHub Actions Runner Controler + a Runner Scale Set to the local kind cluster.

```shell
$ make github
helm upgrade arc --install oci://ghcr.io/actions/act[...]et-controller # ... elided
helm upgrade arc-runner --install oci://ghrc.io/actions/act[...]le-set # ... elided
```

Uninstall any charts from the local kind cluster.

```shell
make uninstall
```

Tear down the local kind cluster.

```shell
make down
```

## CI/CD

Tasks:

- Image Registry
  - Hosting
    - ghcr.io :heavy_check_mark:
    - gitlab artifacts(?)
    - Nexus
    - in-cluster
- Runners
  - Hosting
    - Self-hosted hub/lab
    - GitHub hosted :heavy_check_mark:
- Actions
  - Build
    - Base image(s)
      - Java :heavy_check_mark:
      - other?
    - Registry Credentials
  - Deploy
    - Method
      - Helm chart
      - Manifests
    - Cluster Credentials
