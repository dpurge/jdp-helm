{{/*
Fully qualified resource name for each app in this chart, e.g. "jdp-frontend-phraseforge".
*/}}
{{- define "pgadmin.fullname" -}}
{{ .Chart.Name }}-pgadmin
{{- end -}}

{{- define "phraseforge.fullname" -}}
{{ .Chart.Name }}-phraseforge
{{- end -}}

{{- define "planka.fullname" -}}
{{ .Chart.Name }}-planka
{{- end -}}
