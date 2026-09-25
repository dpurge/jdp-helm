# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- phraseforge: bumped to `2026.9.7`; LLM provider/per-purpose settings
  (transcription/translation) now come from a mounted ConfigMap, matching
  the app's new config schema.
- phraseforge and knowledge: Postgres host/port/database (and, for
  knowledge, the Qdrant URL) now come from the app's Secret as env vars,
  not from a mounted ConfigMap. Each app has exactly one ConfigMap (for
  non-connection settings only), with no hook annotations, and the migrate
  Job no longer mounts any ConfigMap at all — it relies solely on the
  Secret, matching how `PGUSER`/`PGPASSWORD` already worked. Requires a
  matching source change in `k8s-lab` (both apps must read these fields
  from env, not the file) before deploying — see
  `k8s-lab/specs/features/migrate-env-only-connection-config.md`.
- Every `ExternalSecret` in this repo and its required OpenBao keys are
  now documented in the root `README.md`.
