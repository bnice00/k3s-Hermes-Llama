{{- define "platform.labels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "platform.image" -}}
{{ .repository }}{{ if .digest }}@{{ .digest }}{{ else }}:{{ .tag }}{{ end }}
{{- end }}
