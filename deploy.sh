#!/usr/bin/env bash
# Deploy an already-built image to one environment. On failure restore the old image ID.
set -Eeuo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <dev|staging|prod> <host-port> <image:tag-or-digest>" >&2
  exit 2
fi

ENV_NAME=$1
PORT=$2
IMAGE_REF=$3
NETWORK=cd-net
HEALTH_ATTEMPTS=${HEALTH_ATTEMPTS:-10}
HEALTH_INTERVAL=${HEALTH_INTERVAL:-3}

case "$ENV_NAME" in
  dev)     APP_ENV=development ;;
  staging) APP_ENV=staging ;;
  prod)    APP_ENV=production ;;
  *) echo "Invalid environment: $ENV_NAME" >&2; exit 2 ;;
esac
if [[ ! "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Invalid port: $PORT" >&2
  exit 2
fi
if [[ ! "$HEALTH_ATTEMPTS" =~ ^[1-9][0-9]*$ ]] || [[ ! "$HEALTH_INTERVAL" =~ ^[1-9][0-9]*$ ]]; then
  echo "Health attempts and interval must be positive integers" >&2
  exit 2
fi

CONTAINER="ai-$ENV_NAME"
if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  docker network create "$NETWORK" >/dev/null
fi

# Fetch the candidate before stopping the current container.
docker pull "$IMAGE_REF"
PREVIOUS_IMAGE=""
PREVIOUS_APP_ENV="$APP_ENV"
if docker inspect "$CONTAINER" >/dev/null 2>&1; then
  PREVIOUS_IMAGE=$(docker inspect --format '{{.Image}}' "$CONTAINER")
  saved_env=$(docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' "$CONTAINER" | sed -n 's/^APP_ENV=//p' | head -n 1)
  if [[ -n "$saved_env" ]]; then PREVIOUS_APP_ENV=$saved_env; fi
  echo "Previous image ID: $PREVIOUS_IMAGE"
else
  echo "No previous container exists for $CONTAINER"
fi

docker_run_image() {
  local image=$1 app_env=$2
  docker run -d --name "$CONTAINER" --network "$NETWORK" \
    -p "$PORT:8000" -e "APP_ENV=$app_env" "$image" >/dev/null
}

wait_for_health() {
  local attempt response
  for ((attempt=1; attempt<=HEALTH_ATTEMPTS; attempt++)); do
    if response=$(curl --connect-timeout 2 --max-time 3 -fsS \
      "http://127.0.0.1:$PORT/health" 2>/dev/null) && [[ "$response" == "OK" ]]; then
      echo "Health check passed on attempt $attempt"
      return 0
    fi
    if (( attempt < HEALTH_ATTEMPTS )); then sleep "$HEALTH_INTERVAL"; fi
  done
  return 1
}

restore_previous() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  if [[ -z "$PREVIOUS_IMAGE" ]]; then
    echo "No previous image is available to restore" >&2
    return 1
  fi
  echo "Restoring previous image ID: $PREVIOUS_IMAGE"
  docker_run_image "$PREVIOUS_IMAGE" "$PREVIOUS_APP_ENV"
  if wait_for_health; then
    echo "Rollback completed; $CONTAINER is healthy on port $PORT"
    return 0
  fi
  echo "Rollback image did not pass the health check" >&2
  return 1
}

if docker inspect "$CONTAINER" >/dev/null 2>&1; then
  docker rm -f "$CONTAINER" >/dev/null
fi
if ! docker_run_image "$IMAGE_REF" "$APP_ENV"; then
  echo "Could not start candidate image $IMAGE_REF" >&2
  restore_previous || true
  exit 1
fi

if wait_for_health; then
  echo "Environment $ENV_NAME ($APP_ENV) updated to $IMAGE_REF and is healthy"
  exit 0
fi

echo "Health check failed for $IMAGE_REF; starting rollback" >&2
if restore_previous; then
  exit 1
fi
exit 2
