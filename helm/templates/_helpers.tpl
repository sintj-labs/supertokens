{{/*
Expand the name of the chart.
*/}}
{{- define "supertokens.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "supertokens.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- printf "%s" $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "supertokens.labels" -}}
helm.sh/chart: {{ include "supertokens.name" . }}-{{ .Chart.Version }}
app.kubernetes.io/name: {{ include "supertokens.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "supertokens.selectorLabels" -}}
app.kubernetes.io/name: {{ include "supertokens.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
