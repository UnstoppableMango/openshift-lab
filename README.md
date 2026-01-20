# OpenShift CI/CD Test

This repo contains an example of how to configure application builds and deployments against an OpenShift cluster.
The example is intended to be run locally using OpenShift Local.

GitHub Actions is the primary CI/CD tool in use, but parallels will be drawn with GitLab Pipelines.

## Configuring the Cluster

The following subsections explain...

1. How to build container images using `podman`
2. How to deploy a containerized application using `helm`
3. How to write a simple (composite) GitHub action
4. How to configure and deploy GitHub Actions Runner Controller

### Prerequisites

It's recommended to start with a freshly-installed OpenShift Local cluster.

If you already have an OpenShift Local cluster running, you can delete the existing cluster and create a new one with the following commands.

```shell
crc delete
crc start
```

Also, make sure you're currently logged in with the `kubeadmin` account.

```shell
oc login -u kubeadmin https://api.ctc.testing:6443
```

In order to follow the GitHub Actions track of this tutorial, prepare an empty respository.

Using the GitHub CLI (`gh`) this could be done with the following command.

```shell
gh repo create openshift-cicd-test --public
```

Using the GitHub web UI, prepare a Personal Access Token (PAT) for later use.
The token will need the `repo` scope.

> [!TIP]
> [direnv](https://direnv.net/) can be used to store this secret locally while working.
> Add `export GITHUB_PAT='<your-token-here>'` to a file named `.envrc` and run `direnv allow`.

## Build a container image

Our goal in this tutorial is to automate deploying an application to the cluster.
We'll use `nginx` as a lightweight, stateless, web application for now.

To practice building containers, we'll "extend" the official `nginx` image for our application.
Copy the following contents into `Dockerfile`.

```dockerfile
FROM docker.io/nginx:latest
```

To build the image, run the following command.

```shell
$ podman build .
STEP 1/1: FROM docker.io/nginx:latest
Trying to pull docker.io/library/nginx:latest...
Getting image source signatures
Copying blob sha256:57f0dd1befe210f3a7186fe46ad1552d4bc8864701c8cec580676144bc37d425
Copying blob sha256:700146c8ad64762607eb0076d9fe376bed85c65f27650a4f3b76fc66f72e9846
Copying blob sha256:119d43eec815e5f9a47da3a7d59454581b1e204b0c34db86f171b7ceb3336533
Copying blob sha256:10b68cfefee1d8726f1f754e9f566b73bd4df2531476315e6ac55b4fe18e1717
Copying blob sha256:500799c304244b0545f8f1d54d86d3a17512c219cd0edd3d5f5b60f68f5c6f93
Copying blob sha256:d989100b8a84afca8cb4b5bcc62beec741cb69e181fe7815d79e4aa04c36ca59
Copying blob sha256:eaf8753feae0b5aaadb86ac2cb972ff57cff12f877ad50c548fde8092e85e7fb
Copying config sha256:4af177a024eb8a1e43f4fb6c66735bb8260115cb5925a64f51673219bd97c144
Writing manifest to image destination
COMMIT
--> 4af177a024eb
4af177a024eb8a1e43f4fb6c66735bb8260115cb5925a64f51673219bd97c144
```

Now that we've verified we can build a container on our local machine, we'll configure a GitHub workflow to automate the process.

## Create a GitHub Actions workflow

Within your new, empty, git repository, create a new YAML file at `.github/workflows`.
This file can have any name, as long as it is located within `.github/workflows`.
We'll use the name `ci.yml` for this example.

```shell
mkdir -p .github/workflows
touch .github/workflows/ci.yml
```

> [!NOTE]
> In GitLab, this would be the `.gitlab-ci.yml` file

First, we'll add some boilerplate to satisfy the minimum requirements of a workflow.
Copy the following YAML into the new workflow file.
If you are working on a branch other than `main`, use that branch instead.

```yaml
name: CI
on:
  # Trigger this workflow when code is pushed
  push:
    branches:
      # Use whatever branch name you are working off of
      - main

permissions:
  # Allow the workflow to read the repository contents
  contents: read
  # Allow the workflow to push our container image to `ghcr.io`
  packages: write
```

Now we have a valid GitHub workflow to build on.
Next we'll create a job that will build a container image, and push it to `ghcr.io`.

Copy the following YAML below the boilerplate we just added.
Make sure to replace `change_me` with the lower-cased version of your GitHub username!

```diff
# ... elided

permissions:
  contents: read
  packages: write

+ env:
+   # Replace with your GitHub username, lower-cased
+   GITHUB_USERNAME: change_me
+
+ jobs:
+   build:
+     runs-on: ubuntu-latest
+     steps:
+     - uses: actions/checkout@v5
+
+     - name: Install Podman
+       uses: redhat-actions/podman-install@main
+
+     - name: Build the container image
+       run: podman build . --tag ghcr.io/${{ env.GITHUB_USERNAME }}/nginx:latest
```

Commit everything we've created up to this point.
We should have two new files, `.github/workflows/ci.yml` and `Dockerfile`.
Push the commit to GitHub, using the same remote branch you used in the workflow `push` trigger.

If everything has been set up correctly, a new workflow run should have been automatically queued in GitHub.
Log in the GitHub web UI, navigate to your repository, and select the "Actions" tab.
You should see a workflow run performing the steps we just defined in our YAML file.

Now, we've automated building our application's container image!
Next, we'll modify the workflow to push to an image registry so that our cluster can pull the new image.

## Push a container image in GitHub Actions

Modify `.github/workflows/ci.yml` to add the following YAML.

```diff
# ... elided

    - name: Install Podman
      uses: redhat-actions/podman-install@main
+
+     - name: Log in to ghcr.io
+       uses: redhat-actions/podman-login@v1
+       with:
+         registry: ghcr.io
+         username: ${{ env.GITHUB_USERNAME }}
+         password: ${{ github.token }}

    - name: Build the container image
      run: podman build . --tag ghcr.io/${{ env.GITHUB_USERNAME }}/nginx:latest

+     - name: Push the container image
+       run: podman push ghcr.io/${{ env.GITHUB_USERNAME }}/nginx:latest
```

## Deploy GitHub Actions Runner Controller

In order to deploy our custom `nginx` image to a cluster, the compute running our workflows needs access to the cluster's API server.
Typically, hosted compute will work fine barring any special network security requirements.
Since our cluster is running on our local machine, the GitHub hosted runners will not be able to connect to it.

To facilitate running this tutorial in our OpenShift Local cluster, we'll deploy the GitHub Actions Runner Controller (GHARC).
GHARC is a cloud-native tool to orchestrate GitHub Actions runners on a kubernetes cluster.
We'll use it to quickly grant the CI/CD runner access to our local cluster's kubernetes API server.

Run the following script to deploy GHARC to the cluster.
Replace `GITHUB_REPOSITORY` with your repository name in the format `username/repository`.
Replace `GITHUB_PAT` with the personal access token you created earlier.

```shell
$ GITHUB_REPOSITORY='your/repository' GITHUB_PAT='gh_yourPatHere' ./1-deploy-gharc.sh
Release "gharc" does not exist. Installing it now.
Pulled: ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller:0.13.1
Digest: sha256:3a7becceb2c8f5e400a6b828390f43d782bb8e9f58aaeade536c899570bcc572
NAME: gharc
LAST DEPLOYED: Tue Jan 20 13:00:36 2026
NAMESPACE: arc-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Thank you for installing gha-runner-scale-set-controller.

Your release is named gharc.
Waiting for deployment "gharc-gha-rs-controller" rollout to finish: 0 of 1 updated replicas are available...
deployment "gharc-gha-rs-controller" successfully rolled out
clusterrole.rbac.authorization.k8s.io/system:openshift:scc:privileged added: "gharc-gha-rs-controller"
Release "gharc-runner" does not exist. Installing it now.
Pulled: ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set:0.13.1
Digest: sha256:39f9b61ee7e2865d7b8dd0e4e28b7c1a065765fc2ce5bf90874dd8e8be8ee2b2
NAME: gharc-runner
LAST DEPLOYED: Tue Jan 20 13:00:39 2026
NAMESPACE: arc-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Thank you for installing gha-runner-scale-set.

Your release is named gharc-runner.
```

A few resources will have just been created, but we only need to worry about the runner pod right now.
If everything has been successful up to this point, we should have a pod running in the `arc-system` namespace with a name that looks something like `gharc-runner-fxz9g-runner-nn5fw`.

To verify this, we can run:

```shell
$ kubectl get pods --namespace arc-system
NAME                                      READY   STATUS    RESTARTS   AGE
gharc-gha-rs-controller-8c7d7786b-g7k72   1/1     Running   0          43m
gharc-runner-6b79c7d4-listener            1/1     Running   0          13m
gharc-runner-fxz9g-runner-nn5fw           1/1     Running   0          8m4s
```

This is where our GitHub workflow will be executed.
Since its running on our local cluster, it will be able to send requests to the API server!
