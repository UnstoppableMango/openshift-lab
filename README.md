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
+    - name: Log in to ghcr.io
+      uses: redhat-actions/podman-login@v1
+      with:
+        registry: ghcr.io
+        username: ${{ env.GITHUB_USERNAME }}
+        password: ${{ github.token }}

    - name: Build the container image
      run: podman build . --tag ghcr.io/${{ env.GITHUB_USERNAME }}/nginx:latest
+
+    - name: Push the container image
+      run: podman push ghcr.io/${{ env.GITHUB_USERNAME }}/nginx:latest
```

Commit and push these changes as well.
Now, when our workflow runs it will push the built image to GitHub's container registry!
Once the workflow has completed, navigate to your repository's landing page again and find the "Packages" section.
It is typically located on the right-hand side of the page, below "Releases".

![GitHub Packages](assets/github-packages.png)

If you don't see the section right away, wait a bit and refresh the page.
New packages can be slow to update in the web UI.

Select your image "package" from the list to view metadata such as the URI and published tags.
The commands displayed by GitHub use `docker`, but we can replace it with `podman` for every command run in this tutorial.

We'll pull the image as a quick sanity check.
Run the following command, replacing the image with your custom image name.

```shell
$ podman pull ghcr.io/<your-github-username>/nginx:latest
Trying to pull ghcr.io/<your-github-username>/nginx:latest...
Getting image source signatures
Copying blob sha256:34c42acdc6abce4fb775913eaff45b0ba43e061fa0a0079d18f2242a122cd4b2
Copying blob sha256:d7696ad810223b99a0cd3bafdd896355d8efaf59bc8cffd96d26833f05b84cb0
Copying blob sha256:ea368c811a9e76ca60f51346f41e6cd8dcb00fa9c1b8ad9e151c7309a88f4953
Copying blob sha256:5dd5dbcfe763c67dd6fd39c13b9421fcfa62f425fc0c99ec64cfa669c6c0b4ed
Copying blob sha256:033e6114b40efd338043aa417866810fd96dddcc5394aca79ea402fdc925cb3e
Copying blob sha256:490702eb1db134dfcfb5e7be59d65d25ff0b1fdca9b05e4b3c2e206faa3273c3
Copying blob sha256:0971f88e0caa0faeceaebfda1bf84aee73bdbcd92631119032b827bb05a1a7ab
Copying config sha256:4af177a024eb8a1e43f4fb6c66735bb8260115cb5925a64f51673219bd97c144
Writing manifest to image destination
4af177a024eb8a1e43f4fb6c66735bb8260115cb5925a64f51673219bd97c144
```

Now that we have a container image in a public container registry, we can deploy it to our cluster!

## Create kubernetes manifests

Kubernetes offers many methods of deploying code to a cluster, we'll use [Helm](https://helm.sh/) here because it allows us to create a deployment "package".
In the production environment, this package could conceivably be managed by an infrastructure team and provided to development teams as a paved-path for deployment.
The default helm template also contains all the resources we'll need to quickly get our app running.

Run the following command to create a new Helm chart located at `./charts/nginx-app`:

```shell
$ helm create charts/nginx-app
Creating charts/nginx-app
```

This command will have generated quite a few files, but we'll focus on just a couple of them.

- `charts/nxing-app/Chart.yaml` contains the chart package definition. We don't need to worry about its contents right now, but know that it describes the package so `helm` know how to work with it.
- `charts/nginx-app/values.yaml` contains the [Helm "values"](https://helm.sh/docs/chart_template_guide/values_files/), or the configuration we supply to helm when we're deploying.
- `charts/nginx-app/templates/deployment.yaml` contains the kubernetes "Deployment" resource that represents the deployment of our application on the cluster.

Within `charts/nginx-app/templates/deployment.yaml` pay attention to the line that looks like this:

```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
```

With the template created by `helm` v3.19.1 this is located on line 41.

This is using the [helm template syntax](https://helm.sh/docs/topics/charts#templates-and-values) but we can gloss over that for now.
The important part is that this line specifies the image that the application will use when it is deployed.
We'll need to teach helm where to find our custom image when we run the deployment command in the next section.

## Deploy the application to the cluster

For this section we'll need to diverge from standard CI/CD flows so that we can run the application on our OpenShift local cluster.
We'll add more GitHub actions YAML to see what it looks like, but we'll disable these steps and execute equivalent commands on our local machine.
This keeps the tutorial light and focused, the reasoning is elaborated on in the [section below](#cicd-runners-and-networking).

Add the following YAML to our workflow file:

```diff
# ... elided

    - name: Push the container image
      run: podman push ghcr.io/${{ env.GITHUB_USERNAME }}/nginx:latest

+    - name: Authenticate and set context
+      uses: redhat-actions/oc-login@v1
+      with:
+        openshift_server_url: https://api.crc.testing:6443
+        openshift_token: ${{ secrets.OPENSHIFT_TOKEN }}
+
+    - name: Deploy the application
+      run: |
+        helm upgrade nginx-app --install ./charts/nginx-app \
+          --namespace openshift-lab \
+          --create-namespace \
+          --set image.repository=ghcr.io/<your-github-username>/nginx \
+          --set image.tag=latest
```

First we log in to the cluster.
In production, this would use the credentials of a pre-configured cluster service account with permissions to deploy manifests to a single namespace.
Auth is outside the scope of this tutorial, but we'll cover it heavily elsewhere.

Lets break down what this command is doing.

- `upgrade` tells helm we want to deploy changes
- `nginx-app` is an arbitrary name we give to the helm **release**
- `--install` tells helm to install the release if it doesn't exist yet
- `./charts/nginx-app` points to the chart we want to deploy. This is usually a repository name of the form `repository/chart` or an OCI url of the form `oci://repository/chart` but local file paths work as well.
- `--namespace openshift-lab` tells `helm` which kubernetes namespace we want to deploy to, in this case "openshift-lab"
- `--create-namespace` tells helm to create the namespace if it does not exist
- `--set image.repository=ghcr.io/<your-github-username>/nginx` sets a helm **value**. Here, the value `image.repository` is set to `ghcr.io/<your-github-username>/nginx`. This is how we can define `.Values.image.repository` that we saw earlier in `deployment.yaml`
- `--set image.tag=latest` sets an additional helm **value**. We can provide as many of these as we need to configure our application. Here we are filling in the value for `.Values.image.tag` that we saw earlier in `deployment.yaml`

You can verify the server URL with your local machine by runnning the following command.
This value doesn't matter, since we'll be performing the deployment manually instead of the runner.

```shell
$ oc whoami --show-server
https://api.crc.testing:6443
```

If GitHub Actions were actually running our workflow, we would need to create a secret for `${{ secrets.OPENSHIFT_TOKEN }}`.
We can get this value for our local cluster with the following command:

```shell
$ oc whoami --show-token
sha256~tHi55iSF4k3m-hs3LlOf6X6VrDKIsDdU7kiN2sGtJC4
```

Feel free to discard this token, we won't actually use it.

### Run the deployment manually

We'll perform the deployment steps manually since the GitHub hosted runners can't connect to our machine.
We've already authenticated to our cluster locally, so we don't need to replicate the `oc login` step.
Take the `helm` command from our workflow file and execute it on your machine.

```shell
$ helm upgrade nginx-app --install ./charts/nginx-app --namespace openshift-lab --create-namespace --set image.repository=ghcr.io/<your-github-username>/nginx --set image.tag=latest
Release "nginx-app" does not exist. Installing it now.
NAME: nginx-app
LAST DEPLOYED: Wed Jan 21 13:07:26 2026
NAMESPACE: openshift-lab
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  export POD_NAME=$(kubectl get pods --namespace openshift-lab -l "app.kubernetes.io/name=nginx-app,app.kubernetes.io/instance=nginx-app" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace openshift-lab $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace openshift-lab port-forward $POD_NAME 8080:$CONTAINER_PORT
```

### CI/CD, Runners, and Networking

The machine running our GitHub Actions workflows needs to be able to send network requests to the kubernetes API server in order to perform deployment tasks.
Our OpenShift Local clusters are running locally, likely behind a firewall and one or more layers of NAT, and the GitHub hosted runners we're using are running somewhere else entirely.
We could perform some trickery to poke a hole and allow the runners access to our cluster, but this carries security risks and is outside the scope of this tutorial.

We focus on a "push" based flow in order to more accurately model the production workflow, but alternatively we could use a "pull" based flow.
In this model, the cluster watches for changes to some upstream source, a GitHub repository in our case, and pulls them in automatically when they occur.
Therefore we don't need to configure anything special for the CI/CD runner, it only needs to be able to push to the container registry.
This is usually referred to as "GitOps" and some popular tools that support this are `flux` and `argocd`.
