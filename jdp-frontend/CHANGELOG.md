# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed

- phraseforge: the `transcription`, `generateVocabulary` and `generateModels` prompts
  carry the new `{{transcriptionPrompt}}` / `{{grammarPrompt}}` placeholders, which the
  image fills from the source language's snippets (Admin > Languages); the rest of
  each prompt is unchanged. A prompt without a placeholder does not use the
  snippet. Requires a phraseforge image with the Languages tab and snippet
  rendering for every prompt kind (see
  `k8s-lab/specs/features/phraseforge-prompt-snippets.md`); an older image would send
  the placeholders to the model as text.
- phraseforge: new `ingest.maxContentBytes: 204800` (200 KiB; the image's own
  default is 24 KiB) and a `maxAttempts: 3` on every purpose. Long texts and
  dialogs are processed in chunks that fit each purpose's context window,
  one LLM call per chunk, and one long ingest occupies the single job worker
  until it finishes; `maxAttempts` is the total tries per LLM call, shared by
  replies sent back to the model for correction and retries of transient
  failures. Requires a phraseforge image with chunked ingest and the retry
  budget (see `k8s-lab/specs/features/phraseforge-long-text-ingest.md`,
  `phraseforge-item-correction-retry-budget.md` and
  `phraseforge-llm-transient-retry.md`); older images ignore both keys.
- knowledge: config moves to the phraseforge shape — one `providers.ollama`
  entry (`baseUrl`, `firstTokenTimeoutSeconds: 300`, `idleTimeoutSeconds:
  60`) and per-purpose `embeddings`, `chat`, `generateTitle`,
  `generateSummary`, `translate` (each with `provider`, `model`,
  `timeoutSeconds`); the per-section `baseUrl` and the `generate` section
  are gone. Requires a knowledge image with the provider registry (see
  `k8s-lab/specs/features/knowledge-llm-providers-config.md`) — that image
  refuses to start with the old ConfigMap shape.
- phraseforge: new `vocabularyItem` and `modelsItem` purposes (provider,
  model, `timeoutSeconds: 1800`, prompt template) for one structured JSON
  call per vocabulary/models item per site locale, with prompt-eval's
  placeholders. Requires a phraseforge image with structured item
  translation (see
  `k8s-lab/specs/features/phraseforge-structured-item-translation.md`).
- phraseforge: Ollama provider gains `firstTokenTimeoutSeconds: 300` and
  `idleTimeoutSeconds: 60` (streamed calls fail on lack of progress), and
  every purpose's `timeoutSeconds` is raised to `1800` as an overall
  backstop — translations on the CPU-only node take ~300s and were all
  failing at 120s. Requires a phraseforge image with streaming LLM calls
  (see `k8s-lab/specs/features/llm-streaming-progress-timeout.md`); older
  images ignore the two new keys.
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
