---
title: Split knowledge's ConfigMap out of hook lifecycle
kind: bugfix
status: done
version: 1
updated: 2026-09-25
branch: main
---

> **Superseded:** this entire design (a hook-scoped `-migrate-config`
> ConfigMap) failed a real deploy — the migrate Job also needs
> `QDRANT_URL`, which this design didn't carry — and was replaced by
> `specs/features/db-config-to-secret.md` (one ConfigMap, Postgres/Qdrant
> URL moved to the Secret instead).

## Problem / Motivation

The `knowledge` app's ConfigMap (`jdp-frontend/templates/knowledge.yaml`)
carries `pre-install,pre-upgrade` / weight `-10` / `before-hook-creation`
hook annotations so it exists before the `knowledge-migrate` Job hook
(weight `0`) runs and can mount it. This was a working fix for a real
ordering problem: hooks run before this chart's normal resources, the Job
genuinely needs `postgres.host/port/database` (file-only, per
`internal/config/config.go`'s `Load()`), and the app's image is `FROM
scratch` — no shell, so the Job can't write its own config file inline (see
the `[gotcha]` entries added to `specs/memory.md` by the
`phraseforge-2026-9-7` feature, which hit and solved the identical problem).

But it pulls the app's *entire* persistent config (qdrant/embeddings/chat/
generate/translate — none of which the migrate Job touches) into hook
lifecycle: excluded from `helm get manifest`/`helm rollback`/diff tracking,
and deleted+recreated on every install/upgrade even though nothing about it
needs that.

## Acceptance Criteria

- [ ] A named template `knowledge.postgresConfig` in
  `jdp-frontend/templates/_helpers.tpl` renders the `postgres:` block once
  from `.database.{host,port,name}` (mirrors `phraseforge.postgresConfig`,
  added in `phraseforge-2026-9-7`).
- [ ] The existing `knowledge` ConfigMap drops all three hook annotations
  and becomes a normal, Helm-tracked resource; its `postgres:` block is
  rendered via the shared template; it's mounted by the Deployment only
  (unchanged mount).
- [ ] A new, minimal, hook-scoped ConfigMap
  `{{ include "knowledge.fullname" . }}-migrate-config` (postgres block
  only, same shared template) carries the `pre-install,pre-upgrade` /
  weight `-10` / `before-hook-creation` annotations that used to live on
  the full ConfigMap.
- [ ] The migrate Job mounts the new `-migrate-config` ConfigMap instead of
  the full one; its own hook weight (`0`) and delete policy are unchanged.
- [ ] No change to `values.yaml`, image tag, or any of
  qdrant/embeddings/chat/generate/translate config — this is a structural
  fix only, not a version bump.
- [ ] `helm lint jdp-frontend` and `helm template jdp-frontend --values
  jdp-frontend/values.yaml` succeed; rendered output shows the full
  ConfigMap with no hook annotations, the new migrate-config ConfigMap with
  them, and the Job mounting the latter.

## Approach

1. Add `knowledge.postgresConfig` to `_helpers.tpl` (same shape as
   `phraseforge.postgresConfig`).
2. Edit `jdp-frontend/templates/knowledge.yaml`: remove the `annotations:`
   block from the full ConfigMap; replace its literal `postgres:` block
   with `{{- include "knowledge.postgresConfig" .Values.knowledge | nindent 4 }}`;
   add the new hook-scoped `-migrate-config` ConfigMap (postgres only);
   change the migrate Job's volume to reference the new ConfigMap name.
3. Run `helm lint`/`helm template`; inspect rendered output.
4. No values.yaml changes, no image bump.

## Affected Areas

- jdp-frontend/templates/knowledge.yaml
- jdp-frontend/templates/_helpers.tpl

## Out of Scope

- Wiring `EMBEDDINGS_API_KEY`/`CHAT_API_KEY`/`GENERATE_API_KEY`/
  `TRANSLATE_API_KEY` env vars into the Deployment (`config.go` reads them
  via `env()`, but the Deployment doesn't currently set them) —
  pre-existing gap, unrelated to this bugfix.
- Any version bump or config-value change to knowledge.
- The `ExternalSecret`→`Secret` reconciliation race relative to Helm's
  pre-install hooks (same pre-existing risk noted in
  `phraseforge-2026-9-7`, unrelated to this fix).
- Actually running `helm upgrade`/`helm install` — the user will run it
  themselves.

## Implementation Notes

- Added `knowledge.postgresConfig` named template to
  `jdp-frontend/templates/_helpers.tpl` (same shape as
  `phraseforge.postgresConfig`).
- `jdp-frontend/templates/knowledge.yaml`:
  - Removed the `annotations:` block from the full `knowledge` ConfigMap;
    replaced its literal `postgres:` block with
    `{{- include "knowledge.postgresConfig" .Values.knowledge | nindent 4 }}`.
    No other content in that ConfigMap changed.
  - Added a new hook-scoped ConfigMap
    `jdp-frontend-knowledge-migrate-config` (postgres only, same shared
    template, `pre-install,pre-upgrade` / weight `-10` /
    `before-hook-creation` — the exact annotations moved off the full
    ConfigMap).
  - Migrate Job's `config` volume now points at
    `jdp-frontend-knowledge-migrate-config` instead of the full ConfigMap;
    its own hook weight (`0`)/delete-policy and env vars are unchanged.
- No changes to `values.yaml` or the image tag.

## Validation

- `helm lint jdp-frontend` — pass (only the pre-existing "icon is
  recommended" info notice).
- `helm template jdp-frontend jdp-frontend --values jdp-frontend/values.yaml`
  — exit 0. Manually inspected the rendered output: the full `knowledge`
  ConfigMap has no hook annotations and its qdrant/postgres/embeddings/
  chat/generate/translate content is byte-identical to before this change;
  the new `-migrate-config` ConfigMap carries the moved hook annotations
  and only the `postgres` block; the migrate Job mounts
  `jdp-frontend-knowledge-migrate-config`.
- No automated test suite exists for this chart beyond `helm lint`/`helm
  template`; no regressions vs. the pre-change baseline (also exit 0).
- Not run: an actual `helm upgrade`/`helm install` against a live cluster —
  out of scope for this agent session.

## Documentation Review

- `README.md` — no knowledge-specific content (no image tags, no per-app
  config); no drift.
- `jdp-frontend/CHANGELOG.md` — exists (created by `phraseforge-2026-9-7`).
  This changes operator-visible behavior (the ConfigMap is now tracked by
  `helm get manifest`/`helm rollback`/diff, and no longer deleted+recreated
  every release) even though the app's own runtime config is unchanged, so
  it needs an entry under `## [Unreleased]` → `Fixed`.
- Constitution files — no drift; this doesn't change the project's
  mission, tech stack, or conventions (the `-migrate-config` pattern it
  uses was already recorded as a `[convention]` in `specs/memory.md` by
  the `phraseforge-2026-9-7` feature).

## Documentation Updates

- Added a `Fixed` entry to `jdp-frontend/CHANGELOG.md`'s
  `## [Unreleased]` describing the ConfigMap/hook split.
- Removed this feature's `## Now` line from `specs/roadmap.md`.
- No constitution changes were needed for this feature; the
  `-migrate-config` convention it applies was already recorded in
  `specs/memory.md` by `phraseforge-2026-9-7`.
