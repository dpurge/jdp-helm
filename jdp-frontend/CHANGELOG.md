# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

- assistant: the new `assistant` app (a background agent that runs YAML workflows with an LLM, with a task queue, a chat page and an admin interface), as `templates/assistant.yaml`: an ExternalSecret that builds `ASSISTANT_DATABASE_URL` from the OpenBao key `assistant` (the same five `postgres-*` properties as phraseforge, URL-encoded), a ConfigMap `models.yaml` rendered from `assistant.models` in `values.yaml` (Ollama in `jdp-backend`, `gemma4:12b`), a ConfigMap of the workflow files in `files/assistant-workflows/` (`learn-topic`, `hello-live`; copies of `k8s-lab/assistant/workflows`, to be kept equal by hand), a `pre-install,pre-upgrade` migrate Job (`/assistant migrate`), a Deployment (one pod, `Recreate`: the single worker runs one task at a time; a pod restart on a changed models or workflow file), a Service and a Traefik IngressRoute at `assistant.home.arpa`. Before the first install: create the OpenBao key `assistant`, create its database on the production Postgres (the migrate Job creates the tables, not the database), and release the image: the `release-assistant` workflow in `k8s-lab` publishes `ghcr.io/dpurge/assistant:<CalVer>` on a merge to main; `assistant.image` assumes its first tag, `2026.10.0`, so set it to the tag that run produced. The app has no authentication yet, so keep the hostname on the internal network. The tools `memory_search`, `memory_add`, `rag_search` and `web_search` are stubs that return canned data (labelled as such), so `learn-topic` runs but knows nothing yet. Prometheus does not scrape it: `/metrics` exists, and no scrape job was added to `jdp-monitoring`. Rendered with `helm template` and checked with the app's own `models validate` and `workflow validate`; not applied to a cluster.
- knowledge, phraseforge, assistant: new values `knowledge.nats.url`, `phraseforge.nats.url` and `assistant.nats.url` (default `nats://jdp-data-nats.data.svc.cluster.local:4222`, the production NATS: the headless Service `jdp-data-nats` in the `data` namespace, port 4222, no authentication). With them an app can call or answer the other apps over NATS; empty disables it and the app never connects. knowledge and phraseforge: rendered as `nats:` / `url:` in `config.yaml` (and nothing when empty; apps' env overrides `KNOWLEDGE_NATS_URL`, `PHRASEFORGE_NATS_URL`); assistant: the Deployment env `ASSISTANT_NATS_URL` (omitted when empty). The `nats.url` name follows the key in the apps' config files. Nothing authenticates a sender, and the `frontend` namespace must be allowed to reach `data:4222`. Older images reject the key (checked: the released knowledge 2026.10.2 and phraseforge 2026.10.12 refuse a `nats` key in `config.yaml`), so the chart renders knowledge's `nats:` block only for an image tag from 2026.10.3 on and phraseforge's only from 2026.10.13 on (a non-CalVer tag counts as new); until the tags are bumped they run without NATS. Those thresholds are the first releases expected to contain the feature: if the release you deploy has a different number (a push made in several parts), change the `semverCompare` threshold in `templates/knowledge.yaml` or `templates/phraseforge.yaml`. The assistant reads only an environment variable, which older images ignore. The image tags are unchanged here and must be set to the new releases: the `release-<app>` workflow tags `<app>-v<year>.<month>.<micro>`, so after the last tags `assistant-v2026.10.3`, `knowledge-v2026.10.2` and `phraseforge-v2026.10.12` the next ones in October 2026 are `2026.10.4`, `2026.10.3` and `2026.10.13` (the micro restarts at 0 in a new month; read the real tag from the workflow run). Rendered with `helm template` and loaded with the apps' own `config.Load`; not applied to a cluster.

### Changed

- knowledge (BREAKING, needs the new image): the configuration follows knowledge's model router. `values.yaml` `knowledge` and `templates/knowledge.yaml` are rewritten: every key is `snake_case` (`generate_title`, `generate_summary`, `knowledge_language`, `num_ctx`, `timeout_seconds`, `qdrant.search_min_score`); a purpose no longer names a `provider` and `model` but lists `model_tags`; the `providers` block is gone, providers and models are now `knowledge.models`, rendered as `models.yaml` into the same ConfigMap as `config.yaml` (`KNOWLEDGE_MODELS_FILE`, default `/etc/knowledge/models.yaml`); embeddings are `embeddings.embedding_space` and `embeddings.dimension` with an embedding model of that space in `knowledge.models` (`bge-m3`, 1024, as before; the space name is stored on every Qdrant item, so keep it); `llm_calls.retention_days` (30) keeps the new `llm_calls` table in check. New `knowledge.secrets.openrouter_api_key` and `anthropic_api_key` flags (rendered ExternalSecret entries only when `true`, optional env in the Deployment, like the other apps), and a `checksum/config` annotation that restarts the pod when any value changes. The old image does not read the new configuration and the new image rejects the old one with a message naming the replacement, so set `knowledge.image` to the tag of the `release-knowledge` run that publishes this change and upgrade in one step; the image tag is not changed here. The migrate Job is unchanged (no ConfigMap mount; it builds the collection for the default `bge-m3`, 1024). The app serves `/metrics` without a login through its route; no scrape job was added. Rendered with `helm template` and checked with knowledge's own `config.Load` and `LoadModels` and the models validator; not applied to a cluster.
- assistant: `files/assistant-workflows/hello-live.yaml`, `orchestrator.yaml` and `ui-compose.yaml` are updated to be byte-identical to `k8s-lab/assistant/workflows` (the new `on_error` fallback states); `learn-topic.yaml` was already identical. `hello.yaml` and `ui-demo.yaml` stay out of the chart (they need the dev-only `demo` provider; the template ships every `*.yaml` in the folder, so the pod still loads 4 workflows). Checked with `workflow validate`.
- assistant: `files/assistant-workflows/` now holds `learn-topic` (with `intents`), `hello-live`, `orchestrator` and `ui-compose`, copies of `k8s-lab/assistant/workflows` (`hello` and `ui-demo` are left out: they need the dev-only `demo` provider). To serve them, `assistant.models` gains the tag `orchestrator` on `gemma-cpu` and `gemma-gpu` and a model `gemma-cpu-ui` (the same `gemma4:12b`, tag `ui`, `num_predict` 2048) for `ui-compose`. These workflows need an assistant image that knows `intents`, the orchestrator and the A2UI interface: set `assistant.image` to the tag of a `release-assistant` run that has them (the pinned `2026.10.2` does not); the tag is not changed here. Checked with the app's own `models validate` and `workflow validate`, and every `model_tags` set of every workflow matches a model.
- phraseforge: no change to the configuration is needed; the rendered `config.yaml` and `models.yaml` load with phraseforge's own `config.Load` and `LoadModels`. A comment in `values.yaml` now names the real property of the Ollama key, `ollama-api-key`.
- README: new sections that say how to configure each app, what the secret store needs, how to check the chart, and the known gaps.
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
