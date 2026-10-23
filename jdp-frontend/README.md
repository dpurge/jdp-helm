# Frontend services

The apps in this chart: **phraseforge**, **knowledge** and **assistant** (their images come
from `dpurge/k8s-lab`), plus **pgAdmin** and **Planka**. Each app has its own block in
`values.yaml` and its own template in `templates/`.

## Before you deploy

1. **Images.** Each app image is published by its `release-<app>` workflow in `k8s-lab` on a
   merge to main, tagged `YYYY.MM.micro`. Set `<app>.image` in `values.yaml` to the tag that run
   produced. The image and the chart's configuration must match, so do not deploy this chart
   with the old tag of:
   - **knowledge**: the configuration changed incompatibly (see "Upgrading knowledge" below);
   - **assistant**: the workflows use keys (`intents`) and the orchestrator that older images
     do not know.
   phraseforge's configuration is unchanged; its image can stay or be updated.
2. **Secret store** (OpenBao, ClusterSecretStore `jdp-backend-secrets`): one key per app, with
   these properties:

   | Key | Always needed | Only when the flag in `values.yaml` is `true` |
   |---|---|---|
   | `phraseforge` | `postgres-host`, `postgres-port`, `postgres-database`, `postgres-username`, `postgres-password`, `ollama-api-key` | `openrouter-api-key` (`phraseforge.secrets.openrouter_api_key`), `anthropic-api-key` (`phraseforge.secrets.anthropic_api_key`) |
   | `knowledge` | the five `postgres-*` properties, `qdrant-url` | `openrouter-api-key` (`knowledge.secrets.openrouter_api_key`), `anthropic-api-key` (`knowledge.secrets.anthropic_api_key`) |
   | `assistant` | the five `postgres-*` properties | `openrouter-api-key` (`assistant.secrets.openrouter_api_key`), `anthropic-api-key` (`assistant.secrets.anthropic_api_key`) |

   A missing property fails the whole ExternalSecret sync, the database credentials with it,
   so a provider key is only copied when its flag is `true`: create the property first, then
   set the flag.
3. **Databases.** Create the database of each app on the production Postgres (`phraseforge`,
   `knowledge`, `assistant`); the migrate Job creates the tables, not the database.
4. **Check the chart** before you install or upgrade:

   ```sh
   helm lint ./jdp-frontend
   helm template jdp-frontend ./jdp-frontend --namespace frontend -s templates/knowledge.yaml
   ```

   A rendered `models.yaml` can be checked with the assistant's validator, which phraseforge
   and knowledge use as well (they share the schema); save the block to a file and run, from
   `k8s-lab/assistant`: `go run . models validate <file>`. The assistant's workflow files:
   `go run . workflow validate --tools memory_search,memory_add,rag_search,web_search <files>`.

## Configuring the apps

All three apps choose models the same way: a *purpose* (or workflow state) asks for tags, and
the router calls the available model that has **all** of them, the highest `priority` first,
falling back down the list when a model fails or its provider is down. Providers and models
are in the `models` block of each app, rendered as `models.yaml`. A provider has the
compulsory key `api_key_from`: `""` (no credential), `env:NAME` (an environment variable) or
`file:/path` (a file). A key is never written in `values.yaml`.

### knowledge

`values.yaml`, block `knowledge`:

| Key | Meaning |
|---|---|
| `image`, `hostname` | the image tag and the host name of the route |
| `secrets.openrouter_api_key`, `secrets.anthropic_api_key` | copy that key from the secret store into the pod (see above) |
| `qdrant.collection`, `qdrant.search_min_score` | the vector collection and the lowest score a search result may have |
| `embeddings.embedding_space`, `embeddings.dimension` | the vector space of the index and the length of its vectors |
| `chat`, `generate_title`, `generate_summary`, `translate` | each has `model_tags` and `timeout_seconds`; `chat` also `num_ctx` |
| `knowledge_language` | the language the knowledge base is kept in |
| `llm_calls.retention_days` | days to keep the model-call records; 0 keeps them forever |
| `nats.url` | NATS URL, rendered as `nats.url` in `config.yaml` (see "NATS" below); empty disables it |
| `models` | providers, models and the circuit breaker, rendered as `models.yaml` |

- Every key is `snake_case`; the pod restarts by itself when any value changes.
- A model whose tags include `chat` must have `options.num_ctx` of at least `chat.num_ctx`, or
  the app does not start. The app also refuses to start when no model has all the tags of a
  purpose, or when no embedding model has the configured `embedding_space`.
- **Embedding space.** An embedding model carries `embedding_space` and `dimension`. The router
  falls back only between models of the same space (for example the same `bge-m3` on two
  machines). The space name is stored on every item in Qdrant: keep it while the index holds
  items made with it. A different embedding model or dimension needs a new collection.
  Only `ollama` and `openai` providers can carry an embedding model.
- To add OpenRouter: set `secrets.openrouter_api_key: true` (after creating the property), add
  the provider (the commented example in `values.yaml`) and a model on it with the tags
  `default` and `chat`.
- The app serves `/metrics` without a login through the same route as the pages. No scrape job
  is configured in `jdp-monitoring`.
- The migrate Job runs before the ConfigMap exists, so it builds the Qdrant collection for the
  image's default space and dimension (`bge-m3`, 1024), which are the values here. If you change
  `knowledge.embeddings`, create the collection yourself first.

**Upgrading knowledge.** The new image does not start with the old `config.yaml` (camelCase
keys: `generateTitle`, `numCtx`, `providers` and so on are rejected, with a message naming the
replacement), and the old image does not read the new one. Release the image first, set
`knowledge.image` to its tag, and upgrade the chart in the same step. Existing items in Qdrant
stay valid because `embedding_space` equals the model name stored on them (`bge-m3`).

### assistant

Block `assistant`: `image`, `hostname`, `secrets` (as above), `nats.url` (see "NATS" below) and
`models` (providers, models, routing). The pod restarts when `models` or a workflow file
changes.

- **Workflows** are the files in `files/assistant-workflows/`, copies of
  `k8s-lab/assistant/workflows` that must be kept equal by hand: `learn-topic`, `hello-live`,
  `orchestrator` and `ui-compose`. `hello` and `ui-demo` are left out: they need the
  dev-only `demo` provider.
- **Tags the workflows ask for** and the models that carry them in `values.yaml`:

  | Tag | Used by | Models |
  |---|---|---|
  | `chat` | `hello-live` | `gemma-cpu`, `gemma-gpu` |
  | `orchestrator` | `orchestrator` (routes a chat message to the workflow that fits) | `gemma-cpu`, `gemma-gpu` |
  | `ui` | `ui-compose` (writes an A2UI interface; needs `num_predict` 2048) | `gemma-cpu-ui` |

  A workflow whose tags no model has fails when it runs, so when you change tags in `models`,
  check each workflow.
- `ASSISTANT_LLM_CALLS_RETENTION_DAYS` (default 90) and `ASSISTANT_A2UI_MEDIA_HOSTS` (default
  none: no external images in an interface) are not set by the chart.
- The app has **no authentication**: keep the host name on the internal network.
- `ollama-gpu` points at a placeholder host (`gpu-host.lan`); replace it or remove the provider
  and its model.

### phraseforge

Block `phraseforge`: `image`, `hostname`, `bindAddr`, `ingest`, `llm_calls.retention_days`,
`jobs.retention_days_done` and `retention_days_failed`, `nats.url` (see "NATS" below), `secrets`,
`models`, and the 14
purposes (`transcription`, `translation`, `title`, `processText`, `processDialog`,
`generateVocabulary`, `generateModels`, `vocabularyItem`, `modelsItem`, `checkVocabulary`,
`reviewVocabulary`, `reviewModels`, `reviewTranscription`, `reviewTranslation`), each with
`model_tags`, `numCtx`, `timeoutSeconds`, `maxAttempts`, `maxReplyTokens` and `prompt`. Every
purpose is stated explicitly: one that is missing from `values.yaml` or the template runs on
the image's default. An Ollama model that matches a purpose must have `options.num_ctx` of at
least the purpose's `numCtx`. The pod reads the config at startup: restart it after a change.

### NATS

`knowledge.nats.url`, `phraseforge.nats.url` and `assistant.nats.url` let each app call or
answer the other apps over NATS. The default is the production NATS, the headless Service
`jdp-data-nats` in the `data` namespace (`nats://jdp-data-nats.data.svc.cluster.local:4222`).
An empty value disables it: the app never connects, and the chart renders no key or variable.

- knowledge and phraseforge: rendered as `nats:` / `url:` in `config.yaml` (env override
  `KNOWLEDGE_NATS_URL`, `PHRASEFORGE_NATS_URL`). The assistant has no config file: the chart
  sets `ASSISTANT_NATS_URL` in the Deployment.
- Older images reject a `nats` key in `config.yaml` (knowledge before 2026.10.3, phraseforge before
  2026.10.13), so the chart renders that block only for an image tag from those releases on; with an
  older tag the app simply runs without NATS. If the release you deploy is numbered differently,
  change the `semverCompare` threshold in `templates/knowledge.yaml` or `templates/phraseforge.yaml`.
- Nothing authenticates a sender: any pod that can reach NATS can send a message to an app.
  The `frontend` namespace needs network access to `data`, port 4222.

## Known gaps

- **Vertex AI is not supported in production.** The provider needs an OAuth access token that
  lasts about an hour and nothing here renews it. Use Ollama and OpenRouter.
- No Prometheus scrape job exists for the apps' `/metrics` (they are reachable through their
  routes without a login).


## Planka

Set up database:

```sql
CREATE DATABASE planka;
CREATE USER planka WITH PASSWORD '********';
GRANT ALL PRIVILEGES ON DATABASE planka TO planka;
-- change to the planka database: \connect planka
GRANT USAGE, CREATE ON SCHEMA public TO planka;
```
