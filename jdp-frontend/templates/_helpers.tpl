{{/*
Fully qualified resource name for each app in this chart, e.g. "jdp-frontend-phraseforge".
*/}}

{{- define "anki.fullname" -}}
{{ .Chart.Name }}-anki
{{- end -}}

{{- define "pgadmin.fullname" -}}
{{ .Chart.Name }}-pgadmin
{{- end -}}

{{- define "phraseforge.fullname" -}}
{{ .Chart.Name }}-phraseforge
{{- end -}}

{{- define "planka.fullname" -}}
{{ .Chart.Name }}-planka
{{- end -}}

{{- define "knowledge.fullname" -}}
{{ .Chart.Name }}-knowledge
{{- end -}}

{{- define "assistant.fullname" -}}
{{ .Chart.Name }}-assistant
{{- end -}}
