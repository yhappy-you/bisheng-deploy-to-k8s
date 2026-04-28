{{/*
Expand the name of the chart.
*/}}
{{- define "bisheng.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "bisheng.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "bisheng.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bisheng.labels" -}}
helm.sh/chart: {{ include "bisheng.chart" . }}
{{ include "bisheng.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bisheng.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bisheng.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Component labels - adds a component field for sub-resources
Usage: include "bisheng.componentLabels" (dict "component" "mysql" "context" $)
*/}}
{{- define "bisheng.componentLabels" -}}
{{- $component := .component }}
{{- $ctx := .context }}
helm.sh/chart: {{ include "bisheng.chart" $ctx }}
app.kubernetes.io/name: {{ include "bisheng.name" $ctx }}
app.kubernetes.io/instance: {{ $ctx.Release.Name }}
app.kubernetes.io/component: {{ $component }}
app.kubernetes.io/version: {{ $ctx.Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ $ctx.Release.Service }}
{{- end }}

{{/*
Component selector labels
Usage: include "bisheng.componentSelectorLabels" (dict "component" "mysql" "context" $)
*/}}
{{- define "bisheng.componentSelectorLabels" -}}
{{- $component := .component }}
{{- $ctx := .context }}
app.kubernetes.io/name: {{ include "bisheng.name" $ctx }}
app.kubernetes.io/instance: {{ $ctx.Release.Name }}
app.kubernetes.io/component: {{ $component }}
{{- end }}

{{/*
Component fullname
Usage: include "bisheng.componentFullname" (dict "component" "mysql" "context" $)
*/}}
{{- define "bisheng.componentFullname" -}}
{{- $component := .component }}
{{- $ctx := .context }}
{{- printf "%s-%s" (include "bisheng.fullname" $ctx) $component | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Resolve image reference with optional global registry prefix
Usage: include "bisheng.image" (dict "image" .Values.mysql.image "context" $)
*/}}
{{- define "bisheng.image" -}}
{{- $registry := .context.Values.global.imageRegistry }}
{{- if $registry }}
{{- printf "%s/%s" $registry .image }}
{{- else }}
{{- .image }}
{{- end }}
{{- end }}

{{/*
Storage class helper
*/}}
{{- define "bisheng.storageClass" -}}
{{- $sc := .Values.global.storageClass }}
{{- if $sc }}
storageClassName: {{ $sc | quote }}
{{- end }}
{{- end }}
