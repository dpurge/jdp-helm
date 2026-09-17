{{/*
Fully qualified resource name for each app in this chart, e.g. "jdp-data-minio".
*/}}
{{- define "garage.fullname" -}}
{{ .Chart.Name }}-garage
{{- end -}}

{{- define "nats.fullname" -}}
{{ .Chart.Name }}-nats
{{- end -}}

{{- define "postgres.fullname" -}}
{{ .Chart.Name }}-postgres
{{- end -}}

{{- define "qdrant.fullname" -}}
{{ .Chart.Name }}-qdrant
{{- end -}}
