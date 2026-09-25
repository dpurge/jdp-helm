---
version: 1
status: approved
updated: 2026-09-25
---

## Languages & runtimes

Go templates (Helm templating) and YAML. No application source code lives
in this repo — the apps deployed here (e.g. phraseforge, knowledge) are
built elsewhere and consumed as prebuilt container images pinned in each
chart's `values.yaml`.

## Frameworks & libraries

Helm 3 chart format (`apiVersion: v2`). Kubernetes CRDs consumed by
templates: Traefik `IngressRoute` (`traefik.io/v1alpha1`), External Secrets
Operator `ExternalSecret`/`ClusterSecretStore` (`external-secrets.io/v1`),
sealed-secrets (via `kubeseal`), Argo Workflows/Events.

## Infrastructure & tooling

Deployment target: a home Kubernetes cluster reached via its own dedicated
kube context. Chart packaging/publishing: `helm package` followed by
`helm repo index docs --url https://dpurge.github.io/jdp-helm`, served as a
chart repository via GitHub Pages (`docs/index.yaml`). No CI pipeline is
currently defined in this repo — installation and upgrade are manual, per
the README.

### Artifacts

| Artifact | Root | Changelog | Versioning |
| --- | --- | --- | --- |
| jdp-backend | jdp-backend/ | jdp-backend/CHANGELOG.md | none |
| jdp-frontend | jdp-frontend/ | jdp-frontend/CHANGELOG.md | none |
| jdp-data | jdp-data/ | jdp-data/CHANGELOG.md | none |
| jdp-monitoring | jdp-monitoring/ | jdp-monitoring/CHANGELOG.md | none |
| jdp-workflow | jdp-workflow/ | jdp-workflow/CHANGELOG.md | none |

## Key conventions

- Each chart's `values.yaml` pins app image tags directly (e.g.
  `phraseforge.image: ghcr.io/dpurge/phraseforge:2026.9.4`); a chart's own
  `Chart.yaml` `version`/`appVersion` stay static and don't track these.
- Non-credential app config (hostnames, database names, service URLs, model
  names) is passed via `values.yaml` into template env vars or a mounted
  ConfigMap; credentials always come from an `ExternalSecret`-sourced
  Kubernetes Secret, never from a ConfigMap.
- Migration Jobs run as Helm `pre-install,pre-upgrade` hooks with a
  `before-hook-creation` delete policy, since a Job's `spec.template` is
  immutable and each release needs a fresh Job.
- App hostnames use the `*.home.arpa` home-network TLD, routed via a
  Traefik `IngressRoute`.
