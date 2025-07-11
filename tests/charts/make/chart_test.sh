#!/bin/bash
mkdir -p tests/tests
set -o xtrace

echo "Set ENV variables"
RESOURCE_ID=$(openssl rand -hex 4)
CLUSTER_NAME=${CLUSTER_NAME:-"chart-testing"}
RELEASE_NAME=${RELEASE_NAME:-"test"}
SELENIUM_NAMESPACE=${SELENIUM_NAMESPACE:-"selenium"}
KEDA_NAMESPACE=${KEDA_NAMESPACE:-"keda"}
INGRESS_NAMESPACE=${INGRESS_NAMESPACE:-"ingress-nginx"}
SUB_PATH=${SUB_PATH:-"/selenium"}
CHART_PATH=${CHART_PATH:-"charts/selenium-grid"}
TEST_VALUES_PATH=${TEST_VALUES_PATH:-"tests/charts/ci"}
SELENIUM_GRID_PROTOCOL=${SELENIUM_GRID_PROTOCOL:-"http"}
SELENIUM_GRID_HOST=${SELENIUM_GRID_HOST:-"localhost"}
SELENIUM_GRID_PORT=${SELENIUM_GRID_PORT:-"80"}
MATRIX_BROWSER=${1:-"NodeChrome"}
SELENIUM_GRID_AUTOSCALING=${SELENIUM_GRID_AUTOSCALING:-"true"}
SELENIUM_GRID_AUTOSCALING_MIN_REPLICA=${SELENIUM_GRID_AUTOSCALING_MIN_REPLICA:-"0"}
WAIT_TIMEOUT=${WAIT_TIMEOUT:-"90s"}
HUB_CHECKS_INTERVAL=${HUB_CHECKS_INTERVAL:-45}
HUB_CHECKS_MAX_ATTEMPTS=${HUB_CHECKS_MAX_ATTEMPTS:-6}
WEB_DRIVER_WAIT_TIMEOUT=${WEB_DRIVER_WAIT_TIMEOUT:-120}
AUTOSCALING_POLL_INTERVAL=${AUTOSCALING_POLL_INTERVAL:-20}
AUTOSCALING_COOLDOWN_PERIOD=${AUTOSCALING_COOLDOWN_PERIOD:-"1800"}
ENABLE_VIDEO_RECORDER=${ENABLE_VIDEO_RECORDER:-"true"}
SCALING_STRATEGY=${SCALING_STRATEGY:-"default"}
SKIP_CLEANUP=${SKIP_CLEANUP:-"true"} # For debugging purposes, retain the cluster after the test run
CHART_CERT_PATH=${CHART_CERT_PATH:-"${CHART_PATH}/certs/tls.crt"}
SSL_CERT_DIR=${SSL_CERT_DIR:-"/etc/ssl/certs"}
VIDEO_TAG=${VIDEO_TAG:-"latest"}
KEDA_BASED_NAME=${KEDA_BASED_NAME:-"selenium"}
KEDA_BASED_TAG=${KEDA_BASED_TAG:-"latest"}
CHART_ENABLE_TRACING=${CHART_ENABLE_TRACING:-"false"}
CHART_FULL_DISTRIBUTED_MODE=${CHART_FULL_DISTRIBUTED_MODE:-"false"}
HOSTNAME_ADDRESS=${HOSTNAME_ADDRESS:-${SELENIUM_GRID_HOST}}
CHART_ENABLE_INGRESS_HOSTNAME=${CHART_ENABLE_INGRESS_HOSTNAME:-"false"}
CHART_ENABLE_BASIC_AUTH=${CHART_ENABLE_BASIC_AUTH:-"false"}
BASIC_AUTH_USERNAME=${BASIC_AUTH_USERNAME:-"sysAdminUser"}
BASIC_AUTH_PASSWORD=${BASIC_AUTH_PASSWORD:-"myStrongPassword"}
LOG_LEVEL=${LOG_LEVEL:-"INFO"}
INGRESS_DISABLE_USE_HTTP2=${INGRESS_DISABLE_USE_HTTP2:-false}
TEST_EXISTING_KEDA=${TEST_EXISTING_KEDA:-"false"}
TEST_UPGRADE_CHART=${TEST_UPGRADE_CHART:-"false"}
RENDER_HELM_TEMPLATE_ONLY=${RENDER_HELM_TEMPLATE_ONLY:-"false"}
TEST_PV_CLAIM_NAME=${TEST_PV_CLAIM_NAME:-"selenium-grid-pvc-local"}
LIMIT_RESOURCES=${LIMIT_RESOURCES:-"true"}
TEST_PLATFORMS=${PLATFORMS:-"linux/amd64"}
if [ "${RELEASE_NAME}" = "selenium" ]; then
  SELENIUM_TLS_SECRET_NAME="selenium-tls-secret"
else
  SELENIUM_TLS_SECRET_NAME="${RELEASE_NAME}-selenium-tls-secret"
fi
EXTERNAL_TLS_SECRET_NAME=${EXTERNAL_TLS_SECRET_NAME:-"external-tls-secret-${RESOURCE_ID}"}
SELENIUM_ENABLE_MANAGED_DOWNLOADS=${SELENIUM_ENABLE_MANAGED_DOWNLOADS:-"true"}
TEST_NODE_MAX_SESSIONS=${TEST_NODE_MAX_SESSIONS:-"1"}
MAX_SESSIONS_CHROME=${MAX_SESSIONS_CHROME:-${TEST_NODE_MAX_SESSIONS}}
MAX_SESSIONS_FIREFOX=${MAX_SESSIONS_FIREFOX:-${TEST_NODE_MAX_SESSIONS}}
MAX_SESSIONS_EDGE=${MAX_SESSIONS_EDGE:-${TEST_NODE_MAX_SESSIONS}}
TEST_NAME_OVERRIDE=${TEST_NAME_OVERRIDE:-"false"}
TEST_PATCHED_KEDA=${TEST_PATCHED_KEDA:-"false"}
BASIC_AUTH_EMBEDDED_URL=${BASIC_AUTH_EMBEDDED_URL:-"false"}
SELENIUM_GRID_MONITORING=${SELENIUM_GRID_MONITORING:-"true"}
TEST_EXISTING_PTS=${TEST_EXISTING_PTS:-"false"}
TEST_MULTIPLE_VERSIONS=${TEST_MULTIPLE_VERSIONS:-"false"}
TEST_MULTIPLE_VERSIONS_EXPLICIT=${TEST_MULTIPLE_VERSIONS_EXPLICIT:-"true"}
TEST_MULTIPLE_PLATFORMS=${TEST_MULTIPLE_PLATFORMS:-"false"}
TEST_MULTIPLE_PLATFORMS_RELAY=${TEST_MULTIPLE_PLATFORMS_RELAY:-"false"}
TEST_CUSTOM_SPECIFIC_NAME=${TEST_CUSTOM_SPECIFIC_NAME:-"false"}
TEST_VIDEO_RECORDER_SIDECAR=${TEST_VIDEO_RECORDER_SIDECAR:-"false"}

wait_for_terminated() {
  # Wait until no pods are in "Terminating" state
  while true; do
    terminating_pods=$(kubectl get pods -n ${SELENIUM_NAMESPACE} --no-headers | grep Terminating | wc -l)
    if [ $terminating_pods -eq 0 ]; then
      echo "No pods in 'Terminating' state."
      break
    else
      echo "Waiting for $terminating_pods pod(s) to terminate..."
      sleep 2
    fi
  done
}

cleanup() {
  # Get the list of pods
  pods=$(kubectl get pods -n ${SELENIUM_NAMESPACE} -o jsonpath='{.items[*].metadata.name}')
  # Iterate over the pods and print their logs
  for pod in $pods; do
    echo "Logs for pod $pod"
    kubectl logs -n ${SELENIUM_NAMESPACE} $pod --all-containers --tail=10000 > tests/tests/pod_logs_${pod}.txt
  done
  if [ "${SKIP_CLEANUP}" = "false" ] || [ "${CI:-false}" != "false" ]; then
    helm ls -A
    echo "Clean up chart release and namespace"
    helm delete ${RELEASE_NAME} --namespace ${SELENIUM_NAMESPACE} || true
    wait_for_terminated
    sudo chmod -R 777 ${HOST_PATH}/logs
  fi
}

# Function to be executed on command failure
on_failure() {
    local exit_status=$?
    if [ ${RENDER_HELM_TEMPLATE_ONLY} = "true" ]; then
      exit $exit_status
    fi
    kubectl get pods -n "${SELENIUM_NAMESPACE}" -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read pod; do
      echo "Logs for pod $pod"
      kubectl logs -n "${SELENIUM_NAMESPACE}" "$pod" --all-containers --tail=10000
    done
    echo "Get all resources in all namespaces"
    kubectl get all -A >> tests/tests/describe_all_resources_${MATRIX_BROWSER}.txt
    echo "Describe all resources in the ${SELENIUM_NAMESPACE} namespace for debugging purposes"
    kubectl describe all -n ${SELENIUM_NAMESPACE} >> tests/tests/describe_all_resources_${MATRIX_BROWSER}.txt
    kubectl describe pod -n ${SELENIUM_NAMESPACE} >> tests/tests/describe_all_resources_${MATRIX_BROWSER}.txt
    echo "There is step failed with exit status $exit_status"
    sudo chmod -R 777 ${HOST_PATH}/logs
    cleanup
    exit $exit_status
}

# Trap ERR signal and call on_failure function
trap 'on_failure' ERR

if [ "${RENDER_HELM_TEMPLATE_ONLY}" != "true" ]; then
  rm -rf tests/tests/*
  touch tests/tests/describe_all_resources_${MATRIX_BROWSER}.txt
fi

if [ "${RENDER_HELM_TEMPLATE_ONLY}" = "true" ]; then
  KEDA_BASED_NAME="${NAMESPACE}"
  KEDA_BASED_TAG="${KEDA_TAG_VERSION}-${BUILD_DATE}"
  TEST_EXISTING_PTS="true"
fi

if [ -f .env ]
then
    export "$(cat .env | xargs)"
fi
export RELEASE_NAME=${RELEASE_NAME}
export SELENIUM_NAMESPACE=${SELENIUM_NAMESPACE}
export TEST_PV_CLAIM_NAME=${TEST_PV_CLAIM_NAME}
export HOST_PATH=$(realpath ./tests/videos)
export SELENIUM_ENABLE_MANAGED_DOWNLOADS=${SELENIUM_ENABLE_MANAGED_DOWNLOADS}
export AUTOSCALING_COOLDOWN_PERIOD=${AUTOSCALING_COOLDOWN_PERIOD}
export ENABLE_VIDEO_RECORDER=${ENABLE_VIDEO_RECORDER}
RECORDER_VALUES_FILE=${TEST_VALUES_PATH}/base-recorder-values.yaml
MATRIX_BROWSER_VALUES_FILE=${TEST_VALUES_PATH}/${MATRIX_BROWSER}-values.yaml
envsubst < ${RECORDER_VALUES_FILE} > ./tests/tests/base-recorder-values.yaml
envsubst < ${MATRIX_BROWSER_VALUES_FILE} > ./tests/tests/${MATRIX_BROWSER}-values.yaml
RECORDER_VALUES_FILE=./tests/tests/base-recorder-values.yaml
MATRIX_BROWSER_VALUES_FILE=./tests/tests/${MATRIX_BROWSER}-values.yaml

if [ "${TEST_UPGRADE_CHART}" != "true" ] && [ "${RENDER_HELM_TEMPLATE_ONLY}" != "true" ]; then
  LOCAL_PVC_YAML="${TEST_VALUES_PATH}/local-pvc.yaml"
  envsubst < ${LOCAL_PVC_YAML} > ./tests/tests/local-pvc.yaml
  LOCAL_PVC_YAML=./tests/tests/local-pvc.yaml
#  kubectl delete -n ${SELENIUM_NAMESPACE} -f ${LOCAL_PVC_YAML} --ignore-not-found=true
  sudo rm -rf ${HOST_PATH}; sudo mkdir -p ${HOST_PATH}/logs
  sudo chmod -R 777 ${HOST_PATH}
  kubectl create ns ${SELENIUM_NAMESPACE} || true
  kubectl apply -n ${SELENIUM_NAMESPACE} -f ${LOCAL_PVC_YAML}
  kubectl describe pod,svc,pv,pvc -n ${SELENIUM_NAMESPACE} -l app=ftp-server
  kubectl delete pod -n ${SELENIUM_NAMESPACE} -l app=ftp-server --force --grace-period=0
fi

if [ "${TEST_NAME_OVERRIDE}" = "true" ]; then
  HELM_COMMAND_SET_BASE_VALUES="${HELM_COMMAND_SET_BASE_VALUES} \
  --values ${TEST_VALUES_PATH}/nameOverride-values.yaml \
  "
  SELENIUM_TLS_SECRET_NAME="selenium-grid-tls"
fi

HELM_COMMAND_SET_IMAGES=" \
--set global.seleniumGrid.imageRegistry=${NAMESPACE} \
--set global.seleniumGrid.imageTag=${VERSION} \
--set global.seleniumGrid.nodesImageTag=${VERSION} \
--set global.seleniumGrid.videoImageTag=${VIDEO_TAG} \
--set autoscaling.scaledOptions.pollingInterval=${AUTOSCALING_POLL_INTERVAL} \
--set tracing.enabled=${CHART_ENABLE_TRACING} \
--set global.seleniumGrid.httpLogs=${CHART_ENABLE_TRACING} \
--set isolateComponents=${CHART_FULL_DISTRIBUTED_MODE} \
--set global.seleniumGrid.logLevel=${LOG_LEVEL} \
--set chromeNode.nodeMaxSessions=${MAX_SESSIONS_CHROME} \
--set firefoxNode.nodeMaxSessions=${MAX_SESSIONS_FIREFOX} \
--set edgeNode.nodeMaxSessions=${MAX_SESSIONS_EDGE} \
"

if [ -n "${SET_UPDATE_STRATEGY}" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set global.seleniumGrid.updateStrategy.type=${SET_UPDATE_STRATEGY} \
  "
fi

if [ -n "${TRACING_EXPORTER_ENDPOINT}" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set tracing.exporterEndpoint=\\"${TRACING_EXPORTER_ENDPOINT}\\" \
  "
fi

if [ "${TEST_CUSTOM_SPECIFIC_NAME}" = "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set global.seleniumGrid.nodeCustomCapabilities={'myApp:version':'beta','myApp:publish':'public'} \
  "
fi

if [ "${SELENIUM_GRID_AUTOSCALING}" = "true" ] && [ "${TEST_EXISTING_KEDA}" = "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set autoscaling.enabled=false \
  --set autoscaling.enableWithExistingKEDA=true \
  --set autoscaling.scaledJobOptions.scalingStrategy.strategy=${SCALING_STRATEGY} \
  "
elif [ "${SELENIUM_GRID_AUTOSCALING}" = "true" ] && [ "${TEST_EXISTING_KEDA}" = "false" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set autoscaling.enabled=true \
  --set autoscaling.enableWithExistingKEDA=false \
  --set autoscaling.scaledJobOptions.scalingStrategy.strategy=${SCALING_STRATEGY} \
  "
fi

if [ "${TEST_EXTERNAL_DATASTORE}" = "postgresql" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set components.sessionMap.externalDatastore.enabled=true \
  --set components.sessionMap.externalDatastore.backend=postgresql \
  --set postgresql.enabled=true \
  "
elif [ "${TEST_EXTERNAL_DATASTORE}" = "redis" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set components.sessionMap.externalDatastore.enabled=true \
  --set components.sessionMap.externalDatastore.backend=redis \
  --set redis.enabled=true \
  "
fi

if [ "${SELENIUM_GRID_MONITORING}" = "true" ] && [ "${TEST_EXISTING_PTS}" = "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set monitoring.enabled=false \
  --set monitoring.enabledWithExistingAgent=true \
  "
elif [ "${SELENIUM_GRID_MONITORING}" = "true" ] && [ "${TEST_EXISTING_PTS}" = "false" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set monitoring.enabled=true \
  --set monitoring.enabledWithExistingAgent=false \
  "
fi

if [ "${SELENIUM_GRID_AUTOSCALING}" = "true" ] && [ -n "${SET_MAX_REPLICAS}" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set autoscaling.scaledOptions.maxReplicaCount=${SET_MAX_REPLICAS} \
  "
fi

if [ "${SELENIUM_GRID_AUTOSCALING}" = "true" ] && [ "${CLEAR_POD_HISTORY}" = "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set autoscaling.scaledJobOptions.successfulJobsHistoryLimit=0 \
  --set autoscaling.scaledJobOptions.failedJobsHistoryLimit=0 \
  "
fi

if [ "${CHART_ENABLE_INGRESS_HOSTNAME}" = "true" ] && [ "${RENDER_HELM_TEMPLATE_ONLY}" != "true" ]; then
  if [[ ! $(cat /etc/hosts) == *"${HOSTNAME_ADDRESS}"* ]]; then
    sudo -- sh -c -e "echo \"$(hostname -I | cut -d' ' -f1) ${HOSTNAME_ADDRESS}\" >> /etc/hosts"
  fi
  if [[ ! $(cat /etc/hosts) == *"alertmanager.${HOSTNAME_ADDRESS}"* ]]; then
    sudo -- sh -c -e "echo \"$(hostname -I | cut -d' ' -f1) alertmanager.${HOSTNAME_ADDRESS}\" >> /etc/hosts"
  fi
  if [[ ! $(cat /etc/hosts) == *"grafana.${HOSTNAME_ADDRESS}"* ]]; then
    sudo -- sh -c -e "echo \"$(hostname -I | cut -d' ' -f1) grafana.${HOSTNAME_ADDRESS}\" >> /etc/hosts"
  fi
  if [[ ! $(cat /etc/hosts) == *"pts.${HOSTNAME_ADDRESS}"* ]]; then
    sudo -- sh -c -e "echo \"$(hostname -I | cut -d' ' -f1) pts.${HOSTNAME_ADDRESS}\" >> /etc/hosts"
  fi
  ping -c 2 ${HOSTNAME_ADDRESS}
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set ingress.hostname=${HOSTNAME_ADDRESS} \
  "
  SELENIUM_GRID_HOST=${HOSTNAME_ADDRESS}
else
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set global.K8S_PUBLIC_IP=${SELENIUM_GRID_HOST} \
  "
fi

if [ "${CHART_ENABLE_BASIC_AUTH}" = "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set basicAuth.enabled=${CHART_ENABLE_BASIC_AUTH} \
  --set basicAuth.username=${BASIC_AUTH_USERNAME} \
  --set basicAuth.password=${BASIC_AUTH_PASSWORD} \
  --set basicAuth.embeddedUrl=${BASIC_AUTH_EMBEDDED_URL} \
  "
  export SELENIUM_GRID_USERNAME=${BASIC_AUTH_USERNAME}
  export SELENIUM_GRID_PASSWORD=${BASIC_AUTH_PASSWORD}
fi

if [ "${TEST_PLATFORMS}" != "linux/amd64" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set edgeNode.enabled=false \
  "
fi

if [ "${TEST_PLATFORMS}" != "linux/amd64" ] || [ "${TEST_CHROMIUM}" = "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set chromeNode.imageName=node-chromium \
  "
fi

if [ "${SERVICE_TYPE_NODEPORT}" = "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set ingress.enabled=false \
  --set ingress.enableWithController=false \
  --set hub.serviceType=NodePort \
  --set components.router.serviceType=NodePort \
  "
fi

if [ "${SECURE_INGRESS_ONLY_GENERATE}" = "true" ] && [ "${RENDER_HELM_TEMPLATE_ONLY}" != "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set tls.ingress.generateTLS=true \
  --set tls.ingress.defaultCN=${SELENIUM_GRID_HOST} \
  --set tls.ingress.defaultSANList[0]=${SELENIUM_GRID_HOST} \
  --set tls.ingress.defaultIPList[0]=$(hostname -I | cut -d' ' -f1) \
  "
fi

if [ "${SECURE_INGRESS_ONLY_DEFAULT}" = "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set tls.ingress.enabled=true \
  "
fi

if [ "${INGRESS_DISABLE_USE_HTTP2}" = "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set ingress.nginx.useHttp2=false \
  "
else
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set ingress.nginx.useHttp2=true \
  "
fi

if [ "${SECURE_CONNECTION_SERVER}" = "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set tls.enabled=true \
  "
fi

if [ "${SECURE_USE_EXTERNAL_CERT}" = "true" ] && [ "${RENDER_HELM_TEMPLATE_ONLY}" != "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set tls.create=false
  --set tls.nameOverride=${EXTERNAL_TLS_SECRET_NAME} \
  --set ingress.nginx.sslSecret="${SELENIUM_NAMESPACE}/${EXTERNAL_TLS_SECRET_NAME}" \
  "
  cert_dir="./tests/tests"
  if [ ! -f "./tests/tests/tls.crt" ]; then
    ADD_IP_ADDRESS=hostname ./${CHART_PATH}/certs/gen-cert-helper.sh -d ${cert_dir}
    kubectl create secret generic -n ${SELENIUM_NAMESPACE} ${EXTERNAL_TLS_SECRET_NAME} \
    --from-file=tls.crt=${cert_dir}/tls.crt \
    --from-file=tls.key=${cert_dir}/tls.key \
    --from-file=server.jks=${cert_dir}/server.jks \
    --from-file=server.pass=${cert_dir}/server.pass \
    --dry-run=client -o yaml | kubectl apply -n ${SELENIUM_NAMESPACE} -f -
  fi
  CHART_CERT_PATH="./tests/tests/tls.crt"
fi

if [ "${RENDER_HELM_TEMPLATE_ONLY}" != "true" ]; then
  kubectl create secret generic -n ${SELENIUM_NAMESPACE} test-cloud-credentials \
  --from-literal=SAUCE_REGION=${SAUCE_REGION} \
  --dry-run=client -o yaml | kubectl apply -n ${SELENIUM_NAMESPACE} -f -
fi

if [ "${SECURE_INGRESS_ONLY_CONFIG_INLINE}" = "true" ]; then
  if [ "${SECURE_USE_EXTERNAL_CERT}" = "true" ]; then
    HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
    --set ingress.tls[0].hosts[0]=${SELENIUM_GRID_HOST} \
    --set ingress.tls[0].secretName=${EXTERNAL_TLS_SECRET_NAME} \
    "
  else
    HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
    --set ingress.tls[0].hosts[0]=${SELENIUM_TLS_SECRET_NAME} \
    "
  fi
fi

if [ "${SELENIUM_GRID_PROTOCOL}" = "https" ] && [ "${CHART_ENABLE_INGRESS_HOSTNAME}" != "true" ]; then
  if [ "${SECURE_USE_EXTERNAL_CERT}" = "true" ]; then
    HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
    --set ingress-nginx.controller.extraArgs.default-ssl-certificate=${SELENIUM_NAMESPACE}/${EXTERNAL_TLS_SECRET_NAME} \
    "
  else
    HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
    --set ingress-nginx.controller.extraArgs.default-ssl-certificate=${SELENIUM_NAMESPACE}/${SELENIUM_TLS_SECRET_NAME} \
    "
  fi
fi

if [ "${SELENIUM_GRID_AUTOSCALING}" = "true" ]; then
  HELM_COMMAND_SET_AUTOSCALING=" \
  --set autoscaling.scaledOptions.minReplicaCount=${SELENIUM_GRID_AUTOSCALING_MIN_REPLICA} \
  "
fi

if [ "${EXTERNAL_UPLOADER_CONFIG}" = "true" ]; then
    HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
    --set videoRecorder.uploader.secrets=null \
    --set-file uploaderConfigMap.secretFiles.upload\.conf=${TEST_VALUES_PATH}/uploader.conf \
    "
fi

if [ "${TEST_VIDEO_RECORDER_SIDECAR}" = "true" ]; then
    HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
    --set videoRecorder.sidecarContainer=true
    "
fi

HELM_COMMAND_SET_BASE_VALUES="${HELM_COMMAND_SET_BASE_VALUES} \
--values ${TEST_VALUES_PATH}/base-auth-ingress-values.yaml \
--values ${RECORDER_VALUES_FILE} \
"

if [ "${LIMIT_RESOURCES}" = "true" ]; then
  HELM_COMMAND_SET_BASE_VALUES="${HELM_COMMAND_SET_BASE_VALUES} \
  --values ${TEST_VALUES_PATH}/base-resources-values.yaml \
  "
fi

if [ "${SUB_PATH}" = "/selenium" ]; then
  HELM_COMMAND_SET_BASE_VALUES="${HELM_COMMAND_SET_BASE_VALUES} \
  --values ${TEST_VALUES_PATH}/base-subPath-values.yaml \
  "
fi

if [ "${SUB_PATH}" = "/" ]; then
  SUB_PATH=""
fi

if [ "${SELENIUM_GRID_PROTOCOL}" = "https" ]; then
  HELM_COMMAND_SET_BASE_VALUES="${HELM_COMMAND_SET_BASE_VALUES} \
  --values ${TEST_VALUES_PATH}/base-tls-values.yaml \
  "
fi

if [ "${TEST_MULTIPLE_VERSIONS}" = "true" ]; then
  HELM_COMMAND_SET_BASE_VALUES="${HELM_COMMAND_SET_BASE_VALUES} \
  --values ${CHART_PATH}/multiple-nodes-platform-version.yaml \
  "
elif [ "${TEST_MULTIPLE_PLATFORMS}" = "true" ] && [ "${TEST_MULTIPLE_PLATFORMS_RELAY}" != "true" ]; then
  HELM_COMMAND_SET_BASE_VALUES="${HELM_COMMAND_SET_BASE_VALUES} \
  --values ${CHART_PATH}/multiple-nodes-platform.yaml \
  "
elif [ "${TEST_MULTIPLE_PLATFORMS_RELAY}" = "true" ]; then
  HELM_COMMAND_SET_BASE_VALUES="${HELM_COMMAND_SET_BASE_VALUES} \
  --values ${CHART_PATH}/multiple-nodes-platform-relay.yaml \
  "
fi

HELM_COMMAND_SET_BASE_VALUES="${HELM_COMMAND_SET_BASE_VALUES} \
--values ${MATRIX_BROWSER_VALUES_FILE} \
"

if [ "${TEST_EXISTING_KEDA}" = "true" ] && [ "${TEST_UPGRADE_CHART}" != "true" ] && [ "${RENDER_HELM_TEMPLATE_ONLY}" != "true" ]; then
  if [ "${TEST_PATCHED_KEDA}" = "true" ]; then
    KEDA_SET_IMAGES="--set image.keda.registry=${KEDA_BASED_NAME} --set image.keda.repository=keda --set image.keda.tag=${KEDA_BASED_TAG} \
    --set image.metricsApiServer.registry=${KEDA_BASED_NAME} --set image.metricsApiServer.repository=keda-metrics-apiserver --set image.metricsApiServer.tag=${KEDA_BASED_TAG} \
    --set image.webhooks.registry=${KEDA_BASED_NAME} --set image.webhooks.repository=keda-admission-webhooks --set image.webhooks.tag=${KEDA_BASED_TAG} \
    "
  fi
  helm repo add kedacore https://kedacore.github.io/charts
  echo "Install KEDA core on Kubernetes cluster"
  helm upgrade -i ${KEDA_NAMESPACE} -n ${KEDA_NAMESPACE} --create-namespace --set webhooks.enabled=true ${KEDA_SET_IMAGES} kedacore/keda
  echo "Wait for KEDA core to be ready"
  kubectl -n ${KEDA_NAMESPACE} wait --for=condition=ready pod -l app.kubernetes.io/instance=${KEDA_NAMESPACE} --timeout 180s
elif [ "${TEST_EXISTING_KEDA}" != "true" ]; then
  if [ "${TEST_PATCHED_KEDA}" = "true" ]; then
    HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
    --set keda.image.keda.registry=${KEDA_BASED_NAME} --set keda.image.keda.repository=keda --set keda.image.keda.tag=${KEDA_BASED_TAG} \
    --set keda.image.metricsApiServer.registry=${KEDA_BASED_NAME} --set keda.image.metricsApiServer.repository=keda-metrics-apiserver --set keda.image.metricsApiServer.tag=${KEDA_BASED_TAG} \
    --set keda.image.webhooks.registry=${KEDA_BASED_NAME} --set keda.image.webhooks.repository=keda-admission-webhooks --set keda.image.webhooks.tag=${KEDA_BASED_TAG} \
    "
  else
    HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
    --set keda.image.keda.registry=ghcr.io/kedacore --set keda.image.keda.repository=keda --set keda.image.keda.tag=null \
    --set keda.image.metricsApiServer.registry=ghcr.io/kedacore --set keda.image.metricsApiServer.repository=keda-metrics-apiserver --set keda.image.metricsApiServer.tag=null \
    --set keda.image.webhooks.registry=ghcr.io/kedacore --set keda.image.webhooks.repository=keda-admission-webhooks --set keda.image.webhooks.tag=null \
    "
  fi
fi

if [ "${TEST_UPGRADE_CHART}" != "true" ]; then
  HELM_COMMAND_SET_IMAGES="${HELM_COMMAND_SET_IMAGES} \
  --set autoscaling.patchObjectFinalizers.enabled=false \
  "
fi

HELM_COMMAND_ARGS="${RELEASE_NAME} \
${HELM_COMMAND_SET_BASE_VALUES} \
${HELM_COMMAND_SET_AUTOSCALING} \
${HELM_COMMAND_SET_IMAGES} \
${CHART_PATH} --namespace ${SELENIUM_NAMESPACE} --create-namespace"

echo "Render manifests YAML for this deployment"
helm template --debug ${HELM_COMMAND_ARGS} > tests/tests/${TEMPLATE_OUTPUT_FILENAME:-"cluster_deployment_manifests_${MATRIX_BROWSER}.yaml"}

if [ "${RENDER_HELM_TEMPLATE_ONLY}" = "true" ]; then
  exit 0
fi

echo "Deploy Selenium Grid Chart"
helm upgrade --install ${HELM_COMMAND_ARGS}

kubectl get pods -A

if [ "${TEST_UPGRADE_CHART}" = "true" ]; then
  echo "Focus on verify chart upgrade, skip Selenium tests"
  exit 0
fi

if [ "${SECURE_INGRESS_ONLY_GENERATE}" = "true" ] && [ "${RENDER_HELM_TEMPLATE_ONLY}" != "true" ]; then
  kubectl get secret ${SELENIUM_TLS_SECRET_NAME} -n ${SELENIUM_NAMESPACE} -o jsonpath="{.data.tls\.crt}" | base64 -d > ./tests/tests/tls.crt
  CHART_CERT_PATH="./tests/tests/tls.crt"
fi

echo "Run Tests"
export CHART_CERT_PATH=$(readlink -f ${CHART_CERT_PATH})
export SELENIUM_GRID_PROTOCOL=${SELENIUM_GRID_PROTOCOL}
export SELENIUM_GRID_HOST=${SELENIUM_GRID_HOST}
export SELENIUM_GRID_PORT=${SELENIUM_GRID_PORT}""${SUB_PATH}
export SELENIUM_GRID_AUTOSCALING=${SELENIUM_GRID_AUTOSCALING}
export SELENIUM_GRID_AUTOSCALING_MIN_REPLICA=${SELENIUM_GRID_AUTOSCALING_MIN_REPLICA}
export RUN_IN_DOCKER_COMPOSE=true
export HUB_CHECKS_INTERVAL=${HUB_CHECKS_INTERVAL}
export HUB_CHECKS_MAX_ATTEMPTS=${HUB_CHECKS_MAX_ATTEMPTS}
export WEB_DRIVER_WAIT_TIMEOUT=${WEB_DRIVER_WAIT_TIMEOUT}
export SELENIUM_GRID_TEST_HEADLESS=${SELENIUM_GRID_TEST_HEADLESS:-"false"}
export TEST_DELAY_AFTER_TEST=${TEST_DELAY_AFTER_TEST:-"0"}
export TEST_PLATFORMS=${TEST_PLATFORMS}
export TEST_NODE_MAX_SESSIONS=${TEST_NODE_MAX_SESSIONS}
export TEST_AUTOSCALING_ITERATIONS=${TEST_AUTOSCALING_ITERATIONS:-"20"}
export TEST_MULTIPLE_VERSIONS=${TEST_MULTIPLE_VERSIONS}
export TEST_MULTIPLE_VERSIONS_EXPLICIT=${TEST_MULTIPLE_VERSIONS_EXPLICIT}
export TEST_MULTIPLE_PLATFORMS=${TEST_MULTIPLE_PLATFORMS}
export TEST_MULTIPLE_PLATFORMS_RELAY=${TEST_MULTIPLE_PLATFORMS_RELAY}
export TEST_CUSTOM_SPECIFIC_NAME=${TEST_CUSTOM_SPECIFIC_NAME}
if [ "${MATRIX_BROWSER}" = "NoAutoscaling" ]; then
  ./tests/bootstrap.sh NodeFirefox
  if [ "${TEST_PLATFORMS}" = "linux/amd64" ]; then
    ./tests/bootstrap.sh NodeChrome
    ./tests/bootstrap.sh NodeEdge
  else
    ./tests/bootstrap.sh NodeChromium
  fi
elif [ "${MATRIX_TESTS}" = "CDPTests" ]; then
  ./tests/CDPTests/bootstrap.sh "chrome"
  if [ "${TEST_PLATFORMS}" = "linux/amd64" ]; then
    ./tests/CDPTests/bootstrap.sh "MicrosoftEdge"
  fi
elif [ "${MATRIX_TESTS}" = "AutoscalingTestsScaleUp" ]; then
  ./tests/bootstrap.sh ${MATRIX_TESTS}
elif [ "${MATRIX_TESTS}" = "AutoScalingTestsScaleChaos" ]; then
  ./tests/bootstrap.sh ${MATRIX_TESTS}
else
  ./tests/bootstrap.sh ${MATRIX_BROWSER}
fi

wait_for_terminated
