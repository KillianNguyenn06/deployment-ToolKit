#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ENV_FILE:-${ROOT_DIR}/.env}"
ACTION="${1:-build}"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "[ERROR] Environment file not found: ${ENV_FILE}" >&2
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker is not installed on the local server." >&2
    exit 1
fi

docker compose version >/dev/null

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

case "${SERVICE:-}" in
    go-backend|react-frontend|ruby-service)
        ;;
    *)
        echo "[ERROR] Unsupported or missing SERVICE: ${SERVICE:-<empty>}" >&2
        exit 1
        ;;
esac

if [[ -z "${TARGET_IMAGE_REPOSITORY:-}" || -z "${IMAGE_TAG:-}" ]]; then
    echo "[ERROR] TARGET_IMAGE_REPOSITORY and IMAGE_TAG are required." >&2
    exit 1
fi

if [[ ! "${RELEASE_RETENTION:-5}" =~ ^[1-9][0-9]*$ ]]; then
    echo "[ERROR] RELEASE_RETENTION must be a positive whole number." >&2
    exit 1
fi
if [[ ! "${IMAGE_RETENTION_HOURS:-72}" =~ ^[1-9][0-9]*$ ]]; then
    echo "[ERROR] IMAGE_RETENTION_HOURS must be a positive whole number." >&2
    exit 1
fi
if [[ ! "${BUILD_CACHE_RETENTION_HOURS:-168}" =~ ^[1-9][0-9]*$ ]]; then
    echo "[ERROR] BUILD_CACHE_RETENTION_HOURS must be a positive whole number." >&2
    exit 1
fi

cleanup_old_releases() {
    local current_release releases_dir release_name index
    local -a releases

    current_release="$(realpath "${ROOT_DIR}")"
    releases_dir="$(dirname "${current_release}")"
    release_name="$(basename "${current_release}")"

    if [[ "$(basename "${releases_dir}")" != "releases" || ! "${release_name}" =~ ^[0-9]+$ ]]; then
        echo "[WARN] Release cleanup skipped because ${current_release} is not a numbered release directory."
        return
    fi

    mapfile -t releases < <(
        find "${releases_dir}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' \
            | awk '/^[0-9]+$/' \
            | sort -rn
    )

    for ((index=RELEASE_RETENTION; index<${#releases[@]}; index++)); do
        if [[ "${releases[index]}" != "${release_name}" ]]; then
            echo "[CLEANUP] Removing old release ${releases_dir}/${releases[index]}"
            rm -rf -- "${releases_dir:?}/${releases[index]}"
        fi
    done
}

cleanup_managed_images() {
    docker image prune --all --force \
        --filter "label=com.deployment-toolkit.managed=true" \
        --filter "label=com.deployment-toolkit.project=${COMPOSE_PROJECT_NAME}" \
        --filter "until=${IMAGE_RETENTION_HOURS:-72}h"
}

cleanup_build_cache() {
    if [[ "${PRUNE_BUILD_CACHE:-true}" == "true" ]]; then
        docker builder prune --force \
            --filter "until=${BUILD_CACHE_RETENTION_HOURS:-168}h"
    fi
}

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

docker image inspect "${TARGET_IMAGE_REPOSITORY}:${IMAGE_TAG}" \
    --format 'Image={{.RepoTags}} SizeBytes={{.Size}}'
docker image ls "${TARGET_IMAGE_REPOSITORY}:${IMAGE_TAG}"

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

    health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${container_id}")"
    if [[ -n "${health_status}" ]]; then
        echo "[VERIFY] Waiting for ${SERVICE} health check."
        for attempt in {1..30}; do
            health_status="$(docker inspect --format '{{.State.Health.Status}}' "${container_id}")"
            if [[ "${health_status}" == "healthy" ]]; then
                break
            fi
            if [[ "${health_status}" == "unhealthy" ]]; then
                echo "[ERROR] Container ${container_id} reported unhealthy." >&2
                docker logs --tail 100 "${container_id}" >&2
                exit 1
            fi
            sleep 2
        done
        if [[ "${health_status}" != "healthy" ]]; then
            echo "[ERROR] Container ${container_id} did not become healthy within 60 seconds." >&2
            docker logs --tail 100 "${container_id}" >&2
            exit 1
        fi
        echo "[VERIFY] ${SERVICE} is healthy."
    fi
fi

cleanup_managed_images
cleanup_build_cache
cleanup_old_releases

echo "[DONE] ${ACTION} completed for ${SERVICE}: ${TARGET_IMAGE_REPOSITORY}:${IMAGE_TAG}"
