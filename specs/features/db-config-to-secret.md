---
title: Move Postgres/Qdrant connection config from ConfigMap to Secret
kind: bugfix
status: documenting
version: 1
updated: 2026-09-25
branch: main
---

## Problem / Motivation

`phraseforge-2026-9-7` and `knowledge-configmap-hook-fix` (both `done`)
worked around the migrate Job's need for Postgres connection config by
giving it its own small hook-scoped ConfigMap, separate from each app's
main ConfigMap. This was validated by `helm lint`/`helm template` but
failed on an actual `helm upgrade --install` against `jdpct101`: adopting
`jdp-frontend-knowledge`'s pre-existing ConfigMap as a normal resource was
rejected (missing Helm ownership metadata, since it previously existed
only as a hook resource), and after fixing that, the `knowledge-migrate`
Job itself failed — `knowledge`'s `main.go` eagerly constructs a Qdrant
client and calls `EnsureCollection` before checking the subcommand, so
`migrate` also needs `QDRANT_URL`, which the migrate-only ConfigMap didn't
carry (confirmed via the pod's own log: `dial tcp [::1]:6333: connection
refused`, i.e. the unconfigured default).

Direction from the user: **one ConfigMap per app**, and Postgres
connection details (plus, for knowledge, the Qdrant URL) belong in the
app's Secret, alongside the credentials already there — not in any
ConfigMap. This is both simpler (no ConfigMap-hook-ordering problem at
all, since the migrate Job stops needing any ConfigMap) and consistent
with how `PGUSER`/`PGPASSWORD` already work correctly today via
`secretKeyRef`.

This requires a matching change to the app source in `k8s-lab` (both
binaries currently read Postgres host/port/database, and knowledge's
Qdrant URL, only from the mounted config file, never env vars) — tracked
in that repo as `specs/features/migrate-env-only-connection-config.md`,
not here. This spec covers only the `jdp-helm` chart side.

## Acceptance Criteria

- [x] `jdp-frontend/templates/phraseforge.yaml`: `ExternalSecret` gains
  `PGHOST`/`PGPORT` (property `postgres-host`/`postgres-port` — new
  OpenBao properties; `postgres-database`/`postgres-username`/
  `postgres-password`/`llm-api-key` already existed, confirmed by reading
  the live Secret's keys in the `frontend` namespace before this change).
  Exactly one ConfigMap (no hook annotations, no `postgres:` block). No
  `-migrate-config` ConfigMap. Migrate Job has no ConfigMap mount; its env
  is `PGHOST`/`PGPORT`/`PGDATABASE`/`PGUSER`/`PGPASSWORD`, all
  `secretKeyRef`. Deployment gets the same four Postgres env vars added,
  keeps its ConfigMap mount for `bindAddr`/`providers`/`transcription`/
  `translation`.
- [x] `jdp-frontend/templates/knowledge.yaml`: same shape, plus `QDRANT_URL`
  (new property `qdrant-url`) on the `ExternalSecret`, the migrate Job, and
  the Deployment. ConfigMap drops `postgres:` and `qdrant.url`; keeps
  `qdrant.collection`/`searchMinScore`/embeddings/chat/generate/translate.
- [x] `jdp-frontend/templates/_helpers.tpl`: the `phraseforge.postgresConfig`/
  `knowledge.postgresConfig` named templates added by the two superseded
  specs are removed (no longer used by anything).
- [x] `jdp-frontend/values.yaml`: `phraseforge.database`/`knowledge.database`/
  `knowledge.qdrant.url` are removed (dead — no template references them
  anymore; the values now live only in OpenBao).
- [x] Image tags are **not** changed by this spec.
- [x] `helm lint jdp-frontend` and `helm template jdp-frontend --values
  jdp-frontend/values.yaml` succeed; rendered output has exactly one
  ConfigMap per app, no hook annotations on any ConfigMap, and both
  migrate Jobs have zero `volumes`/`volumeMounts`.
- [ ] Deploying `helm upgrade --install jdp-frontend ... --kube-context
  jdpct101` succeeds end-to-end — blocked until the OpenBao secrets are
  updated with the new properties (see README) and the `k8s-lab` source
  change ships with a matching image build.

## Approach

1. Rewrite `phraseforge.yaml` and `knowledge.yaml`: drop the split
   ConfigMap design entirely; add the new Secret keys; move
   Postgres/Qdrant-URL env vars from ConfigMap-file to `secretKeyRef` on
   both the Deployment and the migrate Job.
2. Remove the now-dead `_helpers.tpl` templates and `values.yaml` fields.
3. Document every `ExternalSecret` in the repo and its required OpenBao
   properties in the root `README.md` (verified against each template,
   not guessed — `pgadmin`/`planka` cross-checked against what their
   Deployment/`ExternalSecret` template actually consumes; `jdp-workflow`'s
   `workflows` key flagged as unverified since nothing in that chart
   references specific property names).
4. Validate with `helm lint`/`helm template` only — no cluster commands.
5. Write `k8s-lab/specs/features/migrate-env-only-connection-config.md`
   describing the required app-source change (separate repo, separate
   session).

## Affected Areas

- `jdp-frontend/templates/phraseforge.yaml`
- `jdp-frontend/templates/knowledge.yaml`
- `jdp-frontend/templates/_helpers.tpl`
- `jdp-frontend/values.yaml`
- `README.md`
- (informational only, not edited) `specs/features/phraseforge-2026-9-7.md`,
  `specs/features/knowledge-configmap-hook-fix.md` — both note they're
  superseded by this spec.

## Out of Scope

- Any change to `k8s-lab` source code (spec only, tracked there).
- Any live cluster command — the user runs `helm upgrade`/`kubectl`
  themselves.
- Bumping `phraseforge`/`knowledge` image tags — the user updates these
  manually once new images are built from the `k8s-lab` change.
- Creating/updating the actual OpenBao secret values — the user does this
  against the live OpenBao instance; this spec only documents which
  properties are required.

## Implementation Notes

- `jdp-frontend/templates/phraseforge.yaml` and `knowledge.yaml` rewritten
  per Acceptance Criteria above.
- `_helpers.tpl`: removed the two `postgresConfig` named templates added
  by the superseded specs — file is back to its pre-`phraseforge-2026-9-7`
  content.
- `values.yaml`: removed `phraseforge.database`, `knowledge.database`,
  `knowledge.qdrant.url`.
- `README.md`: added an "OpenBao secret keys" table covering every
  `ExternalSecret` in the repo (`phraseforge`, `knowledge`, `pgadmin`,
  `planka`, `workflows`), sourced from reading each template directly —
  `phraseforge`/`knowledge` are exact (explicit `data:` lists);
  `pgadmin`/`planka` list only the properties actually consumed
  downstream; `workflows` is flagged as unverified since its chart has no
  explicit property consumer to check against.
- `k8s-lab/specs/features/migrate-env-only-connection-config.md` written,
  `status: draft` — describes the app-source change, not implemented here.

## Validation

- `helm lint jdp-frontend` — pass (only the pre-existing "icon is
  recommended" info notice).
- `helm template jdp-frontend jdp-frontend --values jdp-frontend/values.yaml`
  — exit 0. Verified: exactly 4 ConfigMaps total in the render (pgadmin,
  phraseforge, planka, knowledge — one each), zero `migrate-config`
  matches, both migrate Jobs have no `volumes`/`volumeMounts` and get
  Postgres (+ Qdrant URL for knowledge) via `secretKeyRef`, image tags
  unchanged (`phraseforge:2026.9.7`, `knowledge:2026.9.5` — the former was
  already bumped by the superseded spec, not by this one).
- Not run: an actual deploy. The prior real attempt on `jdpct101` failed
  twice (ownership-metadata rejection, then the Qdrant-URL migrate
  failure) before this redesign — see Problem/Motivation. This redesign
  has **not** been re-tested against the live cluster, and can't succeed
  yet regardless, since the `k8s-lab` source change and OpenBao property
  updates are still pending.

## Documentation Review

- `jdp-frontend/CHANGELOG.md` — already has entries from the superseded
  specs describing the old (two-ConfigMap) design; corrected in place to
  describe this design instead, since the old entries were never released
  (still `## [Unreleased]`) and would otherwise document something that
  never shipped.
- `specs/roadmap.md` — no `## Now`/`## Next` line existed for this work
  (it wasn't planned in advance; it emerged from a failed live deploy of
  already-`done` work), so nothing to remove there.
- `specs/memory.md` — the `[convention]` entry from
  `knowledge-configmap-hook-fix` describing the migrate-only-ConfigMap
  pattern is now wrong; superseded with a corrected entry (memory is
  normally append-only/purged only at a maintenance pass, but leaving a
  now-false convention in place would actively mislead the next session,
  so it was corrected immediately).
- `specs/features/phraseforge-2026-9-7.md` and
  `specs/features/knowledge-configmap-hook-fix.md` — both remain `status:
  done` (that work did happen and was superseded, not rejected outright),
  but a pointer to this spec should be added so a reader doesn't mistake
  their Approach/Implementation Notes for the current design.

## Documentation Updates

- Corrected `jdp-frontend/CHANGELOG.md`'s `## [Unreleased]` entries (see
  Documentation Review).
- Added the OpenBao secret-keys table to `README.md`.
- Appended a corrected `[convention]` entry to `specs/memory.md`.
