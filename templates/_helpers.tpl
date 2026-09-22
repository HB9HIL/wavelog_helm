{{- define "wavelog.fullname" -}}
{{- if contains .Chart.Name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/* PVC spec. Usage: (dict "cfg" .Values.persistence.dbdata "root" $) */}}
{{- define "wavelog.pvcSpec" -}}
accessModes: [{{ .cfg.accessMode | default "ReadWriteOnce" }}]
{{- with (.cfg.storageClass | default .root.Values.persistence.storageClass) }}
storageClassName: {{ . | quote }}
{{- end }}
resources:
  requests:
    storage: {{ .cfg.size }}
{{- end -}}

{{- define "wavelog.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end -}}
