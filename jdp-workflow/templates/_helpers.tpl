{{/*
Fully qualified resource name for each app in this chart, e.g. "jdp-workflow-youtube".
*/}}
{{- define "flashcards.fullname" -}}
{{ .Chart.Name }}-flashcards
{{- end -}}

{{- define "workflows.fullname" -}}
{{ .Chart.Name }}-workflows
{{- end -}}

{{- define "youtube.fullname" -}}
{{ .Chart.Name }}-youtube
{{- end -}}

{{- define "webhook.fullname" -}}
{{ .Chart.Name }}-webhook
{{- end -}}

{{- define "events-workflow.fullname" -}}
{{ .Chart.Name }}-events-workflow
{{- end -}}
