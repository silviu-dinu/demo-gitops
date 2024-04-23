# Overview

An example GitOps implementation using GitHub Enterprise Cloud features.

![GitOps Process Diagram](./docs/process.png)

# Steps and implementation

These are the steps executed in order to deploy a specific backend service to `dev`, `uat` and `prod` environments:

01. Engineer calls `service-release.yaml` with parameters: `service`, version.
02. `service-release.yaml` builds and uploads the service to container registry.
03. `service-release.yaml` calls `overlay-update.yaml` with parameters: `overlay=dev`, `service`, `version`.
04. `overlay-update.yaml` raises pull request to update `dev/kustomization.yaml`.
05. `overlay-update.yaml` merges pull request to update `dev/kustomization.yaml` without approvals.
06. `overlay-deploy.yaml` is triggered once `dev/kustomization.yaml` pull request is merged.
07. `overlay-deploy.yaml` deploys the service to `dev` environment.
08. `overlay-deploy.yaml` calls `overlay-update.yaml` with parameters: `overlay=uat`, `service`.
09. `overlay-update.yaml` copies the service version from `dev/kustomization.yaml` to `uat/kustomization.yaml`.
10. `overlay-update.yaml` raises pull request to update `uat/kustomization.yaml`.
11. Reviewer(s) approve and merge pull request to update `uat/kustomization.yaml`.
12. `overlay-deploy.yaml` is triggered once `uat/kustomization.yaml` pull request is merged.
13. `overlay-deploy.yaml` deploys the service to `uat` environment.
14. `overlay-deploy.yaml` calls `overlay-update.yaml` with parameters: `overlay=prod`, `service`.
15. `overlay-update.yaml` copies the service version from `uat/kustomization.yaml` to `prod/kustomization.yaml`.
16. `overlay-update.yaml` raises pull request to update `prod/kustomization.yaml`.
17. Reviewer(s) approve and merge pull request to update `prod/kustomization.yaml`.
18. `overlay-deploy.yaml` is triggered once `prod/kustomization.yaml` pull request is merged.
19. `overlay-deploy.yaml` deploys the service to `prod` environment.

Below is an example implementation in pseudocode of the steps above:

```
onManualDispatch(service, ref) {
  service-release.yaml (service, ref)
    -> calls overlay-update.yaml (overlay=dev, service, ref) # Raises PR: main <- release/<service-name>/dev
}

onPullRequestMerged(branch=release/<service-name>/dev) {
  overlay-deploy.yaml
    -> calls overlay-update.yaml (overlay=uat, service) # Raises PR: main <- release/<service-name>/uat
}

onPullRequestMerged(branch=release/<service-name>/uat) {
  overlay-deploy.yaml
    -> calls overlay-update.yaml (overlay=prod, service) # Raises PR: main <- release/<service-name>/prod
}

onPullRequestMerged(branch=release/<service-name>/prod) {
  overlay-deploy.yaml
}
```

# Repository configuration

- Settings > General > Pull Requests > Automatically delete head branches.
- Settings > Actions > General > Workflow permissions > Read and write permissions.
- Settings > Actions > General > Workflow permissions > Allow GitHub Actions to create and approve pull requests.
- Branch Protections > `main` > Require a pull request before merging.
- Branch Protections > `main` > Require status checks to pass before merging.
- Branch Protections > `main` > Do not allow bypassing the above settings.

# FAQ

- **Why not use GitHub Environment Protections for approvals instead of pull requests?** Environment Protections support only a single approver per environment, while the pull request mechanism does not have this limitation and it is more flexible.
- **How does this implementation scale in terms of adding new environments and services?** The GitHub Actions workflow implementation is reusable across environments and services so scaling requires minimal changes.

# Next steps

- Add `CODEOWNERS` and define which teams can approve pull requests for each overlay.
- Implement code scanning and linting steps in Dockerfile to reduce service coupling with workflow definitions.
- Limit who can call workflow_dispatch.
