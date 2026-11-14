{{- define "searxng.selectorLabels" -}}
app: searxng
{{- end }}

{{- define "searxng.labels" -}}
{{ include "searxng.selectorLabels" . }}
app.kubernetes.io/name: searxng
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}
