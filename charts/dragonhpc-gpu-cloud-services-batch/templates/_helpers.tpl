{{/*
Expand the name of the chart.
*/}}
{{- define "dragon.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "dragon.runtime.timestamp" -}}
{{ now | date "20060102150405" }}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "dragon.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s-%s" .Release.Name $name (include "dragon.runtime.timestamp" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "dragon.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "dragon.labels" -}}
helm.sh/chart: {{ include "dragon.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/part-of: {{ include "dragon.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service | quote }}
{{- end }}

{{- define "dragon.frontendLabels" -}}
app: {{ include "dragon.frontendAppLabel" . | quote }}
{{ include "dragon.frontendSelectorLabels" . }}
{{ include "dragon.labels" . }}
{{- with .Values.frontend.labels }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{- define "dragon.frontendAppLabel" -}}
{{- printf "%s-frontend" (include "dragon.fullname" .) }}
{{- end }}

{{- define "dragon.frontendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "dragon.name" . }}-frontend
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/component: dragon-frontend
{{- end }}

{{- define "dragon.backendLabels" -}}
app: {{ include "dragon.backendAppLabel" . | quote }}
{{ include "dragon.backendSelectorLabels" . }}
{{ include "dragon.labels" . }}
{{- with .Values.backend.labels }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{- define "dragon.backendAppLabel" -}}
{{- printf "%s-backend" (include "dragon.fullname" .) }}
{{- end }}

{{- define "dragon.backendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "dragon.name" . }}-backend
app.kubernetes.io/instance: {{ .Release.Name | quote }}
app.kubernetes.io/component: dragon-backend
{{- end }}

{{- define "dragon.frontendServiceAccountName" -}}
{{- if .Values.frontend.serviceAccount.create }}
{{- default (printf "%s-frontend" (include "dragon.fullname" .)) .Values.frontend.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.frontend.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "dragon.backendServiceAccountName" -}}
{{- if .Values.backend.serviceAccount.create }}
{{- default (printf "%s-backend" (include "dragon.fullname" .)) .Values.backend.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.backend.serviceAccount.name }}
{{- end }}
{{- end }}

{{- define "dragon.serviceSelector" -}}
{{- printf "%s_pod_0" (include "dragon.backendAppLabel" .) }}
{{- end }}

{{- define "dragon.secretName" -}}
{{- printf "%s-%s" (include "dragon.name" .) .Release.Name }}
{{- end -}}