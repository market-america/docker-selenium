#!/usr/bin/env bash

cd tests/CDPTests || true

npm install
npx playwright install --force chromium

BROWSER=${1:-"chrome"}

SELENIUM_REMOTE_URL="${SELENIUM_GRID_PROTOCOL}://${SELENIUM_GRID_HOST}:${SELENIUM_GRID_PORT}"
echo "SELENIUM_REMOTE_URL=${SELENIUM_REMOTE_URL}" > .env

if [ -n "${SELENIUM_GRID_USERNAME}" ] && [ -n "${SELENIUM_GRID_PASSWORD}" ]; then
  BASIC_AUTH="$(echo -en "${SELENIUM_GRID_USERNAME}:${SELENIUM_GRID_PASSWORD}" | base64 -w0)"
  echo "SELENIUM_REMOTE_HEADERS={\"Authorization\": \"Basic ${BASIC_AUTH}\"}" >> .env
  BASIC_AUTH="Authorization: Basic ${BASIC_AUTH}"
fi

echo "SELENIUM_REMOTE_CAPABILITIES={\"browserName\": \"${BROWSER}\", \"platformName\": \"Linux\"}" >> .env
echo "NODE_EXTRA_CA_CERTS=${CHART_CERT_PATH}" >> .env

cat .env

start_time=$(date +%s)
until [ "$(curl --noproxy "*" -sk -H "${BASIC_AUTH}" -o /dev/null -w "%{http_code}" "${SELENIUM_REMOTE_URL}/status")" = "200" ]; do
  current_time=$(date +%s)
  elapsed_time=$((current_time - start_time))
  if [ $elapsed_time -ge 400 ]; then
    echo "Timeout reached: Grid is not ready after 5 minutes."
    exit 1
  fi
  echo "Waiting for Grid to be ready..."
  sleep 1
done

npx playwright test
