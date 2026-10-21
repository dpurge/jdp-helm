# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- assistant: the new `assistant` app (a background agent that runs YAML workflows with an LLM, with a task queue, a chat page and an admin interface), as `templates/assistant.yaml`: an ExternalSecret that builds `ASSISTANT_DATABASE_URL` from the OpenBao key `assistant` (the same five `postgres-*` properties as phraseforge, URL-encoded), a ConfigMap `models.yaml` rendered from `assistant.models` in `values.yaml` (Ollama in `jdp-backend`, `gemma4:12b`), a ConfigMap of the workflow files in `files/assistant-workflows/` (`learn-topic`, `hello-live`; copies of `k8s-lab/assistant/workflows`, to be kept equal by hand), a `pre-install,pre-upgrade` migrate Job (`/assistant migrate`), a Deployment (one pod, `Recreate`: the single worker runs one task at a time; a pod restart on a changed models or workflow file), a Service and a Traefik IngressRoute at `assistant.home.arpa`. Before the first install: create the OpenBao key `assistant`, create its database on the production Postgres (the migrate Job creates the tables, not the database), and release the image: the `release-assistant` workflow in `k8s-lab` publishes `ghcr.io/dpurge/assistant:<CalVer>` on a merge to main; `assistant.image` assumes its first tag, `2026.10.0`, so set it to the tag that run produced. The app has no authentication yet, so keep the hostname on the internal network. The tools `memory_search`, `memory_add`, `rag_search` and `web_search` are stubs that return canned data (labelled as such), so `learn-topic` runs but knows nothing yet. Prometheus does not scrape it: `/metrics` exists, and no scrape job was added to `jdp-monitoring`. Rendered with `helm template` and checked with the app's own `models validate` and `workflow validate`; not applied to a cluster.

### Changed

- phraseforge: no change to `values.yaml` is needed for the new navigation (top bar Documents, Tasks, Usage, Config), the Usage section, the Config pages or the recording of the user on model calls; they need only the new image. The pre-upgrade migrate Job (`/phraseforge migrate`, same image as the Deployment) adds the nullable `user_id` columns to `jobs` and `llm_calls` and an index on `llm_calls (user_id, started_at)` (`IF NOT EXISTS`, safe to repeat; it takes brief locks on those two tables, and rows from before show no user). Set `phraseforge.image` to the tag that the `release-phraseforge` workflow in `k8s-lab` publishes for this change: the newest tag when this was written is `2026.10.9`, which does not have it. The image tag is not changed here.
- phraseforge: every purpose now states `maxReplyTokens`, the cap on one reply in tokens (Ollama `num_predict`, 0 = no cap), in `values.yaml` and the ConfigMap template. It is 512 for `vocabularyItem` and `modelsItem` (a normal reply is about 60 tokens) and 0 elsewhere. A vocabulary item reply once ran to 2625 tokens and filled the 4096 window; with the cap it is cut off and retried. Needs the image that reads `maxReplyTokens`; an older image ignores the key.
- phraseforge: the `generateVocabulary`, `vocabularyItem`, `reviewVocabulary` and `reviewModels` prompts are the current defaults of the phraseforge image again: the vocabulary prompts take the dictionary-form rules from the language's snippet (`{{dictionaryPrompt}}`) instead of spelling them out, the extraction prompt asks for grammar tags only where the language has a grammar snippet, and the two reviews check the translation style their generators enforce. Languages without a dictionary snippet (on production `grc`, `heb`, `fas`, `ell`) get only the one language-independent rule until a snippet is added in Admin > Languages. Needs the image that has the dictionary snippet and the review jobs; the image tag is not changed here.
- phraseforge: every purpose is configured explicitly now: `provider`, `model`,
  `numCtx`, `think`, `timeoutSeconds`, `maxAttempts` and `prompt`, in `values.yaml`
  and the ConfigMap template (14 purposes). `checkVocabulary`, `reviewVocabulary`,
  `reviewTranscription` and `reviewTranslation` were missing and ran on the image's
  defaults, the new `reviewModels` is added, `think: false` is stated everywhere, and
  `numCtx: 4096` is stated for `transcription`, `translation`, `vocabularyItem` and
  `modelsItem`, which left it unset (4096 is the window Ollama reports on the
  server). The values are the image's defaults (`ollama`/`gemma4:12b`, `numCtx` 8192
  or 16384 for the two text reviews, 1800 s, 3 attempts, and the prompts of
  prompt-eval's `prompt/phraseforge/default`), so behavior does not change, with
  these consequences: no purpose falls back to another's provider and model any
  more (change all four review purposes to review with another model), a prompt
  change in a new image reaches production only when `values.yaml` is changed too,
  and the vocabulary and models item calls now have the context-overflow check
  (the 361 recent `vocabulary_item` calls used at most 1646 of the 4096 tokens).
  Requires the phraseforge image that no longer has the fallbacks and refuses a
  blank provider or model at startup; an older image ignores `reviewModels`, and
  works with the other values. The image tag is not changed here.
- phraseforge: the `transcription`, `generateVocabulary`, `generateModels`,
  `vocabularyItem` and `modelsItem` prompts are the current defaults of the
  phraseforge image again (the five were behind them). The transcription prompt and
  the `[transcription]` rule of the vocabulary and models prompts no longer name a
  transcription system or a script: the rules for a language come from its snippet
  (Admin > Languages), and the Arabic examples follow the Arabic snippet. The item
  prompts gain the usage, example, new-sense and rewrite parts, and the
  vocabulary prompt returns `| usage` instead of `= translation`. Requires the
  phraseforge image of this release (a vocabulary list is parsed in the new
  format, and an older image would send the new placeholders to the model as text);
  the image tag is not changed here. The migrate Job (a pre-upgrade hook) also
  drops `llm_prompts.prompt` and creates `vocabulary_hidden_phrases` before the new
  pods start; prompt text saved in Admin > LLM is not kept, Admin > LLM stores only
  provider, model, thinking and timeout.
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
