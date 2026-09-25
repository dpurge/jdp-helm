---
version: 1
status: approved
updated: 2026-09-25
---

## Problem

jdp-helm packages a personal home-lab Kubernetes deployment as five Helm
charts — `jdp-backend`, `jdp-frontend`, `jdp-data`, `jdp-monitoring`,
`jdp-workflow` — each installed as its own Helm release into a dedicated
namespace, so the set of self-hosted apps and infrastructure services can be
installed and upgraded reproducibly instead of applying raw manifests by
hand.

## Users

The repo's only user is its own maintainer, operating a home Kubernetes
cluster via `helm install`/`helm upgrade` from a local checkout, or via the
published chart repository (the `docs/` directory served over GitHub Pages,
per the README) for `helm repo add`.

## Value proposition

Centralizes chart definitions and per-app values in one repo so upgrading an
app (e.g. bumping an image tag) or adding a new one is a values/template edit
followed by a `helm upgrade`, instead of hand-maintained raw manifests. The
README documents the install/upgrade/uninstall commands for every chart to
keep operations reproducible across sessions.

## Non-goals

Not a multi-tenant or public-facing platform. Deployments here target only
this project's own home-lab cluster.
