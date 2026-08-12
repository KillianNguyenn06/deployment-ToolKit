#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
ACTION="${1:-build}"
SERVICE="go-backend"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "[ERROR] Environment file not found: ${ENV_FILE}" >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker is not installed on the local server." >&2
    exit 1
fi

docker compose version >/dev/null

COMPOSE=(
    docker compose
    --project-directory "${ROOT_DIR}"
    --env-file "${ENV_FILE}"
    --file "${ROOT_DIR}/compose.yaml"
)

"${COMPOSE[@]}" config --quiet

case "${ACTION}" in
    build)
        "${COMPOSE[@]}" build "${SERVICE}"
        ;;
    deploy)
        "${COMPOSE[@]}" up --build -d "${SERVICE}"
        ;;
    *)
        echo "[ERROR] Unsupported action: ${ACTION}. Use build or deploy." >&2
        exit 1
        ;;
esac

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

docker image inspect "${GO_IMAGE_REPOSITORY}:${IMAGE_TAG}" \
    --format 'Image={{.RepoTags}} SizeBytes={{.Size}}'
docker image ls "${GO_IMAGE_REPOSITORY}:${IMAGE_TAG}"

if [[ "${ACTION}" == "deploy" ]]; then
    "${COMPOSE[@]}" ps "${SERVICE}"
    container_id="$("${COMPOSE[@]}" ps -q "${SERVICE}")"
    if [[ -z "${container_id}" ]]; then
        echo "[ERROR] Compose did not return a container for ${SERVICE}." >&2
        exit 1
    fi
    if [[ "$(docker inspect --format '{{.State.Running}}' "${container_id}")" != "true" ]]; then
        echo "[ERROR] Container ${container_id} is not running." >&2
        exit 1
    fi
fi

echo "[DONE] ${ACTION} completed for ${GO_IMAGE_REPOSITORY}:${IMAGE_TAG}"
