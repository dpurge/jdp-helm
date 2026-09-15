{{/*
Fully qualified resource name for each app in this chart, e.g. "jdp-monitoring-grafana".
*/}}
{{- define "alertmanager.fullname" -}}
{{ .Chart.Name }}-alertmanager
{{- end -}}

{{- define "grafana.fullname" -}}
{{ .Chart.Name }}-grafana
{{- end -}}

{{- define "otel.fullname" -}}
{{ .Chart.Name }}-otel
{{- end -}}

{{- define "prometheus.fullname" -}}
{{ .Chart.Name }}-prometheus
{{- end -}}

{{- define "tempo.fullname" -}}
{{ .Chart.Name }}-tempo
{{- end -}}
