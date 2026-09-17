{{/*
Fully qualified resource name for each app in this chart, e.g. "jdp-backend-openbao".
*/}}
{{- define "secrets.fullname" -}}
{{ .Chart.Name }}-secrets
{{- end -}}

{{- define "headlamp.fullname" -}}
{{ .Chart.Name }}-headlamp
{{- end -}}

{{- define "nfs.fullname" -}}
{{ .Chart.Name }}-nfs-subdir-external-provisioner
{{- end -}}

{{- define "openbao.fullname" -}}
{{ .Chart.Name }}-openbao
{{- end -}}

{{- define "workflows.fullname" -}}
{{ .Chart.Name }}-workflows
{{- end -}}

{{- define "argo-events.fullname" -}}
{{ .Chart.Name }}-argo-events
{{- end -}}

{{- define "ollama.fullname" -}}
{{ .Chart.Name }}-ollama
{{- end -}}
