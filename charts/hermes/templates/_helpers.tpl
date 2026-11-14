{{- define "hermes.labels" -}}
app: {{ .app }}
app.kubernetes.io/name: {{ .app }}
app.kubernetes.io/instance: {{ .root.Release.Name }}
app.kubernetes.io/managed-by: {{ .root.Release.Service }}
helm.sh/chart: {{ .root.Chart.Name }}-{{ .root.Chart.Version }}
{{- end }}

{{- define "hermes.image" -}}
{{ .repository }}{{ if .digest }}@{{ .digest }}{{ else }}:{{ .tag }}{{ end }}
{{- end }}
