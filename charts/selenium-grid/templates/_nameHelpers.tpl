{{/*
Expand the name of the chart.
*/}}
{{- define "seleniumGrid.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "seleniumGrid.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "seleniumGrid.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "seleniumGrid.commonLabels" -}}
{{- $defaultLabels := dict
    "app.kubernetes.io/managed-by" (.Release.Service | lower)
    "app.kubernetes.io/instance" .Release.Name
    "app.kubernetes.io/version" .Chart.AppVersion
    "app.kubernetes.io/component" (printf "selenium-grid-%s" .Chart.AppVersion)
    "helm.sh/chart" (include "seleniumGrid.chart" .)
}}
{{- $customLabels := tpl (toYaml (.Values.customLabels | default dict)) $ | fromYaml }}
{{- $mergedLabels := merge $defaultLabels $customLabels }}
{{- toYaml $mergedLabels | nindent 0 }}
{{- end -}}

{{/*
Bring common labels to tracing resource attributes
*/}}
{{- define "seleniumGrid.tracing.attributes" -}}
{{- $labels := include "seleniumGrid.commonLabels" $ | fromYaml }}
{{- $attrs := list }}
{{- range $k, $v := $labels }}
{{- $attrs = append $attrs (printf "%s=%s" $k $v) }}
{{- end }}
{{- join "," $attrs }}
{{- end -}}

{{/*
Autoscaling labels
*/}}
{{- define "seleniumGrid.autoscalingLabels" -}}
component.autoscaling: "{{ .Release.Name }}"
{{- end -}}

{{- define "seleniumGrid.component.name" -}}
{{- $component := index . 0 }}
{{- $root := index . 1 }}
{{- if eq $root.Release.Name "selenium" }}
{{- $component | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" $root.Release.Name $component | replace "." "" | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{/*
Selenium metrics exporter fullname
*/}}
{{- define "seleniumGrid.monitoring.exporter.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-metrics-exporter" $)) ($.Values.monitoring).exporter.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selenium metrics scrape key in secret resource
*/}}
{{- define "seleniumGrid.monitoring.scrape.key" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-grid-scrape" $)) ($.Values.monitoring).additionalScrapeConfigs.key) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Selenium Hub fullname
*/}}
{{- define "seleniumGrid.hub.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-hub" $)) .Values.hub.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Event bus fullname
*/}}
{{- define "seleniumGrid.eventBus.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-event-bus" $)) .Values.components.eventBus.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Event bus ConfigMap fullname
*/}}
{{- define "seleniumGrid.eventBus.configmap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-event-bus-config" $)) .Values.busConfigMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Session Map ConfigMap fullname
*/}}
{{- define "seleniumGrid.sessionMap.configmap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-session-map-config" $)) .Values.sessionMapConfigMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Session Queue ConfigMap fullname
*/}}
{{- define "seleniumGrid.sessionQueue.configmap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-session-queue-config" $)) .Values.sessionQueueConfigMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Router fullname
*/}}
{{- define "seleniumGrid.router.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-router" $)) .Values.components.router.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Distributor fullname
*/}}
{{- define "seleniumGrid.distributor.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-distributor" $)) .Values.components.distributor.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
SessionMap fullname
*/}}
{{- define "seleniumGrid.sessionMap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-session-map" $)) .Values.components.sessionMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
SessionQueue fullname
*/}}
{{- define "seleniumGrid.sessionQueue.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-session-queue" $)) .Values.components.sessionQueue.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Chrome node fullname
*/}}
{{- define "seleniumGrid.chromeNode.fullname" -}}
{{- $component := index . 0 }}
{{- $root := index . 1 }}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-node-chrome" $root)) $component.nameOverride) $root | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Firefox node fullname
*/}}
{{- define "seleniumGrid.firefoxNode.fullname" -}}
{{- $component := index . 0 }}
{{- $root := index . 1 }}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-node-firefox" $root)) $component.nameOverride) $root | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Edge node fullname
*/}}
{{- define "seleniumGrid.edgeNode.fullname" -}}
{{- $component := index . 0 }}
{{- $root := index . 1 }}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-node-edge" $root)) $component.nameOverride) $root | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Relay node fullname
*/}}
{{- define "seleniumGrid.relayNode.fullname" -}}
{{- $component := index . 0 }}
{{- $root := index . 1 }}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-node-relay" $root)) $component.nameOverride) $root | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Ingress fullname
*/}}
{{- define "seleniumGrid.ingress.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-ingress" $)) .Values.ingress.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common secrets cross components
*/}}
{{- define "seleniumGrid.common.secrets.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-secrets" $)) .Values.secrets.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Basic authentication secrets for components fullname
*/}}
{{- define "seleniumGrid.basicAuth.secrets.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-basic-auth-secrets" $)) .Values.basicAuth.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
KEDA TriggerAuthentication resource fullname
*/}}
{{- define "seleniumGrid.autoscaling.authenticationRef.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-scaler-trigger-auth" $)) .Values.autoscaling.authenticationRef.name) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Secret TLS fullname
*/}}
{{- define "seleniumGrid.tls.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-tls-secret" $)) .Values.tls.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Service Account fullname
*/}}
{{- define "seleniumGrid.serviceAccount.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-serviceaccount" $)) .Values.serviceAccount.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Distributor ConfigMap fullname
*/}}
{{- define "seleniumGrid.distributor.configmap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-distributor-config" $)) .Values.distributorConfigMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Router ConfigMap fullname
*/}}
{{- define "seleniumGrid.router.configmap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-router-config" $)) .Values.routerConfigMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Recorder ConfigMap fullname
*/}}
{{- define "seleniumGrid.recorder.configmap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-recorder-config" $)) .Values.recorderConfigMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Video manager fullname
*/}}
{{- define "seleniumGrid.videoManager.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-video-manager" $)) .Values.videoManager.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Uploader ConfigMap fullname
*/}}
{{- define "seleniumGrid.uploader.configmap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-uploader-config" $)) .Values.uploaderConfigMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Logging ConfigMap fullname
*/}}
{{- define "seleniumGrid.logging.configmap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-logging-config" $)) .Values.loggingConfigMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Node ConfigMap fullname
*/}}
{{- define "seleniumGrid.node.configmap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-node-config" $)) .Values.nodeConfigMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Server ConfigMap fullname
*/}}
{{- define "seleniumGrid.server.configmap.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-server-config" $)) .Values.serverConfigMap.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Delete scaledObjects leafover job fullname
*/}}
{{- define "seleniumGrid.keda.deleteObjectsJob.fullname" -}}
{{- printf "%s-scaledobjects-deletion" (tpl ( default (include "seleniumGrid.component.name" (list "selenium-patch" $)) .Values.autoscaling.patchObjectFinalizers.nameOverride) $) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Patch scaledObjects finalizers job fullname
*/}}
{{- define "seleniumGrid.keda.patchObjectsJob.fullname" -}}
{{- printf "%s-scaledobjects-finalizers" (tpl ( default (include "seleniumGrid.component.name" (list "selenium-patch" $)) .Values.autoscaling.patchObjectFinalizers.nameOverride) $) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
RBAC RoleBinding fullname
*/}}
{{- define "seleniumGrid.rbac.roleBinding.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-rolebinding" $)) .Values.rbacRoleBinding.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
RBAC Role fullname
*/}}
{{- define "seleniumGrid.rbac.role.fullname" -}}
{{- tpl (default (include "seleniumGrid.component.name" (list "selenium-role" $)) .Values.rbacRole.nameOverride) $ | trunc 63 | trimSuffix "-" -}}
{{- end -}}
