# OpenShift Lab

The repo contains experiments deploying and managing an OpenShift cluster.

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

## CI/CD Tasks

### Container Image Hosting

- Decide on a hosting solution
  - GitLab container registry to start
  - GitHub container registry when it is available
- Ensure cluster can pull images
  - Private registry credentials
  - Networking restrictions

### Container Image Building

- Decide on the build tool
  - `podman` stays within the ecosystem
  - `docker` is a popular default
- Ensure runners have the build tool installed
  - GitLab
    - Build job image: `quay.io/podman/stable`
  - GitHub
    - RedHat action: `redhat-actions/podman-install`
- Ensure runners can build container images
  - Dockerfile -> Docker image
  - Dockerfile -> OCI image
  - Containerfile -> OCI image
- Ensure runners can push images
  - Credential storage
  - Networking restrictions
- Provide a paved path for developers to build their applications
  - GitLab
    - `include` shared yaml
    - CI/CD componentss
    - Parent-Child/Multi-Project pipelines
  - GitHub
    - Custom action `openshift-actions/build-image`
  - Base image for applications
    - Java
    - Other?

### Application Deployment

- Ensure runners can connect to the cluster
- Ensure runners can access deployment manifests
  - git repo
  - Helm chart registry
- Ensure runners have permissions to deploy manifests
  - Scoping
    - Auth token can only deploy to single namespace
    - Auth token can deploy to entire cluster
- Ensure runners have the correct tools installed
  - oc
  - kubectl
  - helm
  - kustomize
- Provide a paved path for developers to deploy their applications
  - GitLab
    - `include` shared yaml
    - CI/CD components
    - Parent-Child/Multi-Project pipelines
  - GitHub
    - Custom action `openshift-actions/deploy-image`
  - Helm chart
