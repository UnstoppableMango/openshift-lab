# OpenShift Lab

The repo contains experiments deploying an managing an OpenShift cluster.

## CI/CD

Tasks:

- Image Registry
  - Hosting
    - ghcr.io :heavy_check_mark:
    - gitlab artifacts(?)
    - Nexus
    - in-cluster
  - Credentials
- Runners
  - Hosting
    - Self-hosted hub/lab
    - GitHub hosted :heavy_check_mark:
- Actions
  - Build
    - Base image(s)
      - Java :heavy_check_mark:
      - other?
  - Deploy
    - Helm chart
    - Manifests
