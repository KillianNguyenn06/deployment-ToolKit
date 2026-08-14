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

selected_services=()
case "${SERVICE:-}" in
    go-backend|react-frontend|ruby-service)
        selected_services+=("${SERVICE}")
        ;;
    all)
        selected_services+=(go-backend react-frontend ruby-service)
        ;;
    *)
        echo "[ERROR] Unsupported or missing SERVICE: ${SERVICE:-<empty>}" >&2
        exit 1
        ;;
esac

profile_for_service() {
    case "$1" in
        go-backend) echo go ;;
        react-frontend) echo react ;;
        ruby-service) echo ruby ;;
    esac
}

image_reference_for_service() {
    case "$1" in
        go-backend) echo "${GO_IMAGE_REPOSITORY:?GO_IMAGE_REPOSITORY is required}:${GO_IMAGE_TAG:?GO_IMAGE_TAG is required}" ;;
        react-frontend) echo "${REACT_IMAGE_REPOSITORY:?REACT_IMAGE_REPOSITORY is required}:${REACT_IMAGE_TAG:?REACT_IMAGE_TAG is required}" ;;
        ruby-service) echo "${RUBY_IMAGE_REPOSITORY:?RUBY_IMAGE_REPOSITORY is required}:${RUBY_IMAGE_TAG:?RUBY_IMAGE_TAG is required}" ;;
    esac
}

profile_args=()
for service in "${selected_services[@]}"; do
    profile_args+=(--profile "$(profile_for_service "${service}")")
    image_reference_for_service "${service}" >/dev/null
done

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

"${COMPOSE[@]}" "${profile_args[@]}" config --quiet

case "${ACTION}" in
    build)
        "${COMPOSE[@]}" "${profile_args[@]}" build "${selected_services[@]}"
        ;;
    deploy)
        "${COMPOSE[@]}" "${profile_args[@]}" up --build -d "${selected_services[@]}"
        ;;
    *)
        echo "[ERROR] Unsupported action: ${ACTION}. Use build or deploy." >&2
        exit 1
        ;;
esac

for service in "${selected_services[@]}"; do
    image_reference="$(image_reference_for_service "${service}")"
    docker image inspect "${image_reference}" \
        --format 'Image={{.RepoTags}} SizeBytes={{.Size}}'
    docker image ls "${image_reference}"
done

if [[ "${ACTION}" == "deploy" ]]; then
    "${COMPOSE[@]}" "${profile_args[@]}" ps "${selected_services[@]}"
    for service in "${selected_services[@]}"; do
        container_id="$("${COMPOSE[@]}" "${profile_args[@]}" ps -q "${service}")"
        if [[ -z "${container_id}" ]]; then
            echo "[ERROR] Compose did not return a container for ${service}." >&2
            exit 1
        fi
        if [[ "$(docker inspect --format '{{.State.Running}}' "${container_id}")" != "true" ]]; then
            echo "[ERROR] Container ${container_id} for ${service} is not running." >&2
            docker logs --tail 100 "${container_id}" >&2 || true
            exit 1
        fi

        health_status="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{end}}' "${container_id}")"
        if [[ -n "${health_status}" ]]; then
            echo "[VERIFY] Waiting for ${service} health check."
            for attempt in {1..30}; do
                health_status="$(docker inspect --format '{{.State.Health.Status}}' "${container_id}")"
                if [[ "${health_status}" == "healthy" ]]; then
                    break
                fi
                if [[ "${health_status}" == "unhealthy" ]]; then
                    echo "[ERROR] Container ${container_id} for ${service} reported unhealthy." >&2
                    docker logs --tail 100 "${container_id}" >&2
                    exit 1
                fi
                sleep 2
            done
            if [[ "${health_status}" != "healthy" ]]; then
                echo "[ERROR] Container ${container_id} for ${service} did not become healthy within 60 seconds." >&2
                docker logs --tail 100 "${container_id}" >&2
                exit 1
            fi
            echo "[VERIFY] ${service} is healthy."
        fi
    done
fi

cleanup_managed_images
cleanup_build_cache
cleanup_old_releases

echo "[DONE] ${ACTION} completed for: ${selected_services[*]}"
