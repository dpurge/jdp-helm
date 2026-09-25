# Project Memory

<!-- Append-only, one entry per line: `YYYY-MM-DDTHH:MM:SSZ [tag] text`. See the `memory-format` skill. Do not read this file in full — grep it. -->

2026-09-25T13:32:03Z [gotcha] phraseforge/knowledge (k8s-lab) read PG host/port/database only from mounted CONFIG_FILE, never env vars; only PGUSER/PGPASSWORD/SESSION_KEY/*_API_KEY are env-sourced.
2026-09-25T13:32:03Z [gotcha] phraseforge/knowledge's runtime images are FROM scratch (no shell); a migrate Job can't write config inline, needs a mounted ConfigMap/Secret.
2026-09-25T14:10:00Z [convention] jdp-frontend: one ConfigMap per app (no hook annotations, no migrate-only ConfigMap). Postgres host/port/database (+ Qdrant URL for knowledge) live in the app's Secret, used as env vars by both the Deployment and the migrate Job — migrate never mounts a ConfigMap. Requires a matching k8s-lab source change (see k8s-lab specs/features/migrate-env-only-connection-config.md) so the binaries read these from env, not the mounted file.
