---
title: Update phraseforge to 2026.9.7
kind: feature
status: done
version: 1
updated: 2026-09-25
branch: main
---

> **Superseded in part:** the ConfigMap/Postgres design below (Postgres
> host/port/database in the mounted ConfigMap) was replaced by
> `specs/features/db-config-to-secret.md` after this shipped but failed a
> real deploy. `providers`/`transcription`/`translation` and the image
> bump to `2026.9.7` are unaffected and still current.

## Problem / Motivation

`k8s-lab`'s phraseforge source was refactored today (commit `9860633`, tag
`phraseforge-v2026.9.7`) from all-env-var configuration to a mounted config
file (`CONFIG_FILE`, default `/etc/phraseforge/config.yaml`) for `bindAddr`,
Postgres `host`/`port`/`database`, per-provider (`ollama`/`openrouter`)
`baseURL`, and seven per-purpose LLM blocks (`transcription`, `translation`,
`title`, `processText`, `processDialog`, `generateVocabulary`,
`generateModels`). Only `PGUSER`/`PGPASSWORD`/`SESSION_KEY`/
`OLLAMA_API_KEY`/`OPENROUTER_API_KEY` remain env-sourced (verified in
`phraseforge/internal/config/config.go`'s `Load()`).

`jdp-helm`'s `phraseforge` chart is still on the pre-refactor image
(`2026.9.4`) and the pre-refactor all-env-var template shape
(`jdp-frontend/templates/phraseforge.yaml`, `jdp-frontend/values.yaml`).
Deploying the new image without updating the chart would silently ignore
`PGHOST`/`PGPORT`/`LLM_*` env vars and fall back to the binary's built-in
file defaults (`localhost` Postgres, `http://host.docker.internal:11434`
Ollama) — the migrate Job would fail to reach the real database, and the app
would fail to reach the real Ollama service.

## Acceptance Criteria

- [ ] `jdp-frontend/values.yaml`'s `phraseforge.image` is
  `ghcr.io/dpurge/phraseforge:2026.9.7`.
- [ ] `phraseforge.database`, `phraseforge.providers.ollama.baseUrl`,
  `phraseforge.transcription`, `phraseforge.translation` are set in
  `values.yaml`, matching the shape and model choice in
  `k8s-lab/phraseforge/k8s/configmap.yaml` (provider `ollama`, model
  `gemma4:12b` for both transcription and translation), adapted to this
  chart's in-cluster Ollama service URL. `title`/`processText`/
  `processDialog`/`generateVocabulary`/`generateModels` are left unset,
  matching that same reference file, so the binary's own defaults apply
  (also `ollama`/`gemma4:12b`).
- [ ] A named template in `jdp-frontend/templates/_helpers.tpl` renders the
  shared `postgres:` block once; both ConfigMaps below include it, so
  `host`/`port`/`database` exist in exactly one place in `values.yaml`.
- [ ] A normal (non-hook) ConfigMap (`{{ include "phraseforge.fullname" . }}`)
  carries the full config (`bindAddr`, `postgres`, `providers`, the two
  configured purpose blocks) and is mounted by the Deployment only, via
  `CONFIG_FILE=/etc/phraseforge/config.yaml`.
- [ ] A second, minimal, hook-scoped ConfigMap
  (`{{ include "phraseforge.fullname" . }}-migrate-config`, `postgres` block
  only, same shared template) carries `pre-install,pre-upgrade` / weight
  `-10` / `before-hook-creation` annotations and is mounted by the migrate
  Job instead of the full ConfigMap.
- [ ] `ExternalSecret` exposes an `OLLAMA_API_KEY` Secret key (kept sourced
  from the existing `llm-api-key` remote property, since that's what's
  already provisioned in the secret store); `OPENROUTER_API_KEY` is not
  added (no `openrouter` provider configured in `values.yaml`).
- [ ] Deployment env vars `BIND_ADDR`, `PGHOST`, `PGPORT`, `LLM_PROVIDER`,
  `LLM_BASE_URL`, `LLM_MODEL` are removed (superseded by the mounted file);
  `PGDATABASE` secretKeyRef usage is removed (now file-sourced);
  `PGUSER`/`PGPASSWORD`/`SESSION_KEY` env vars are unchanged;
  `OLLAMA_API_KEY` env var is added.
- [ ] Migrate Job drops its plain `PGHOST`/`PGPORT` env vars (no longer read
  by the binary) and instead mounts the new `-migrate-config` ConfigMap at
  `/etc/phraseforge` with `CONFIG_FILE` set; `PGUSER`/`PGPASSWORD` env vars
  unchanged.
- [ ] `helm lint jdp-frontend` and `helm template jdp-frontend --values
  jdp-frontend/values.yaml` succeed with no errors; rendered output shows
  the expected volumes/env vars on both the Deployment and the migrate Job.
- [ ] The exact `helm upgrade`/`helm install` command (pinned to
  `--kube-context jdpct101`) is handed to the user; it is not run by the
  agent.

## Approach

1. Add a `phraseforge.postgresConfig` named template to
   `jdp-frontend/templates/_helpers.tpl` rendering the `postgres:` YAML
   block from `.Values.phraseforge.database`.
2. Update `jdp-frontend/values.yaml`'s `phraseforge` block: bump `image`;
   replace the old `llm:` block with `providers.ollama.baseUrl`,
   `transcription`, `translation` (per Acceptance Criteria); keep
   `database`/`hostname` as-is (already correct host/port/name).
3. Update `jdp-frontend/templates/phraseforge.yaml`:
   - `ExternalSecret`: rename the `LLM_API_KEY` secret key to
     `OLLAMA_API_KEY` (remote property unchanged).
   - Add the full ConfigMap (no hook annotations), rendering `bindAddr`/the
     shared postgres template/`providers`/the two configured purpose
     blocks.
   - Add the minimal `-migrate-config` ConfigMap (hook annotations, weight
     `-10`), rendering only the shared postgres template.
   - Migrate Job: drop `PGHOST`/`PGPORT` env vars; add a `config` volume
     from the new `-migrate-config` ConfigMap, mount it at
     `/etc/phraseforge`, add `CONFIG_FILE` env; keep
     `PGUSER`/`PGPASSWORD`/hook weight/delete-policy unchanged.
   - Deployment: drop `BIND_ADDR`/`PGHOST`/`PGPORT`/`LLM_PROVIDER`/
     `LLM_BASE_URL`/`LLM_MODEL`/`PGDATABASE` env vars; add a `config` volume
     from the full ConfigMap mounted at `/etc/phraseforge` (readOnly); add
     `CONFIG_FILE` env; add `OLLAMA_API_KEY` env; keep
     `PGUSER`/`PGPASSWORD`/`SESSION_KEY` unchanged.
4. Run `helm lint` and `helm template` against the chart; fix any errors.
5. Present the exact `helm upgrade`/`helm install` command (pinned to
   `--kube-context jdpct101`) for the user to run themselves.

## Affected Areas

- `jdp-frontend/values.yaml`
- `jdp-frontend/templates/phraseforge.yaml`
- `jdp-frontend/templates/_helpers.tpl`

## Out of Scope

- Per-purpose model tuning beyond `transcription`/`translation` (matches
  the upstream reference; `title`/`processText`/`processDialog`/
  `generateVocabulary`/`generateModels` stay on binary defaults).
- Fixing `SESSION_KEY` currently reusing the `PGPASSWORD` secret value
  (pre-existing, unrelated to this schema change).
- The `ExternalSecret`→`Secret` reconciliation race relative to Helm's
  pre-install hooks (pre-existing risk on fresh installs only; unrelated to
  this change).
- Actually running `helm upgrade`/`helm install` against the cluster — the
  user will run it themselves.
- The `knowledge` app's ConfigMap-hook fix — tracked separately as
  `knowledge-configmap-hook-fix`.

## Implementation Notes

- Added `phraseforge.postgresConfig` named template to
  `jdp-frontend/templates/_helpers.tpl`, rendering the `postgres:` block
  from `.database.{host,port,name}`.
- `jdp-frontend/values.yaml`: bumped `phraseforge.image` to
  `ghcr.io/dpurge/phraseforge:2026.9.7`; added `bindAddr`; replaced the old
  `llm:` block with `providers.ollama.baseUrl`, `transcription`
  (`ollama`/`gemma4:12b`), `translation` (`ollama`/`gemma4:12b`), matching
  `k8s-lab/phraseforge/k8s/configmap.yaml`; left
  `title`/`processText`/`processDialog`/`generateVocabulary`/
  `generateModels` unset per that same reference.
- `jdp-frontend/templates/phraseforge.yaml`:
  - `ExternalSecret`: renamed the `LLM_API_KEY` secret key to
    `OLLAMA_API_KEY` (remote property `llm-api-key` unchanged); dropped the
    now-unused `PGDATABASE` secret key (database name is file-sourced now).
  - Added a normal (non-hook) ConfigMap `jdp-frontend-phraseforge`
    (`bindAddr`/postgres/providers/transcription/translation), mounted only
    by the Deployment.
  - Added a hook-scoped ConfigMap `jdp-frontend-phraseforge-migrate-config`
    (postgres only, same shared template, `pre-install,pre-upgrade` /
    weight `-10` / `before-hook-creation`), mounted only by the migrate Job.
  - Migrate Job: dropped `PGHOST`/`PGPORT`/`PGDATABASE` env vars (the
    2026.9.7 binary no longer reads them); added `CONFIG_FILE` env and the
    migrate-config volume mount; kept `PGUSER`/`PGPASSWORD`/hook
    weight/delete-policy unchanged.
  - Deployment: dropped `PGHOST`/`PGPORT`/`PGDATABASE`/`BIND_ADDR`/
    `LLM_PROVIDER`/`LLM_BASE_URL`/`LLM_MODEL`/`LLM_API_KEY` env vars; added
    `CONFIG_FILE` and `OLLAMA_API_KEY` env vars and the full-ConfigMap
    volume mount; kept `PGUSER`/`PGPASSWORD`/`SESSION_KEY` unchanged.

## Validation

- `helm lint jdp-frontend` — pass (only the pre-existing "icon is
  recommended" info notice).
- `helm template jdp-frontend jdp-frontend --values jdp-frontend/values.yaml`
  — exit 0. Manually inspected the rendered output: the full ConfigMap
  contains the expected `bindAddr`/`postgres`/`providers`/`transcription`/
  `translation` block; the migrate-config ConfigMap contains only
  `postgres`; the migrate Job mounts `jdp-frontend-phraseforge-migrate-config`
  and sets `CONFIG_FILE`; the Deployment mounts
  `jdp-frontend-phraseforge` and sets `CONFIG_FILE`/`OLLAMA_API_KEY`; the
  `ExternalSecret` exposes `OLLAMA_API_KEY` from the existing `llm-api-key`
  remote property.
- No automated test suite exists for this chart beyond `helm lint`/`helm
  template`; no pre-existing failures to compare against (baseline render
  before this change also succeeded with exit 0).
- Not run: an actual `helm upgrade`/`helm install` against a live cluster —
  out of scope for this agent session; see the deploy command below.

## Documentation Review

- `README.md` — no phraseforge-specific content (no image tags, no
  per-app config); no drift.
- `jdp-frontend/CHANGELOG.md` — does not exist yet. This is a user-facing
  change (image version bump + config schema), so per the artifacts table
  in `specs/tech-stack.md` it needs an entry under `## [Unreleased]` →
  `Changed`; the file needs to be created with the standard Keep a
  Changelog header.
- Constitution files (`mission.md`, `tech-stack.md`, `roadmap.md`) — no
  drift; this change doesn't alter the project's mission, tech stack, or
  conventions, only an app's config schema.

## Documentation Updates

- Created `jdp-frontend/CHANGELOG.md` with the standard Keep a Changelog
  header and an `## [Unreleased]` → `Changed` entry for this update.
- Removed this feature's `## Now` line from `specs/roadmap.md` (no
  matching `## Next` line existed — it was already promoted directly).
- No constitution changes were needed for this feature.
