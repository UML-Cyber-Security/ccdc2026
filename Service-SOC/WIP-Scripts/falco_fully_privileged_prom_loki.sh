#!/usr/bin/env bash

# WIP UNTESTED SCRIPT
# Attempts to setup a docker container for:
# - Falco setup (with optional ruleset config)
# - Promtail for auto shipping to a central Loki instance

set -euo pipefail

FALCO_IMAGE="${FALCO_IMAGE:-falcosecurity/falco:latest}"
FALCO_CONTAINER_NAME="${FALCO_CONTAINER_NAME:-falco-fully-privileged}"
FALCO_RESTART_POLICY="${FALCO_RESTART_POLICY:-unless-stopped}"

# Enable promtail shipping to Loki
ENABLE_PROMTAIL="${ENABLE_PROMTAIL:-true}"
PROMTAIL_IMAGE="${PROMTAIL_IMAGE:-grafana/promtail:latest}"
PROMTAIL_CONTAINER_NAME="${PROMTAIL_CONTAINER_NAME:-promtail-falco}"
PROMTAIL_RESTART_POLICY="${PROMTAIL_RESTART_POLICY:-unless-stopped}"
LOKI_URL="${LOKI_URL:-http://loki:3100/loki/api/v1/push}"

# Optional: make Falco emit JSON (nicer in Loki)
FALCO_JSON_OUTPUT="${FALCO_JSON_OUTPUT:-true}"

BASE_VOLUME_MOUNTS=(
  "/var/run/docker.sock:/host/var/run/docker.sock"
  "/dev:/host/dev"
  "/proc:/host/proc:ro"
  "/boot:/host/boot:ro"
  "/lib/modules:/host/lib/modules:ro"
  "/usr:/host/usr:ro"
  "/etc:/host/etc:ro"
)

OPTIONAL_RULES_MOUNT=""

run() {
  if [[ "${EUID}" -ne 0 ]]; then
    sudo "$@"
  else
    "$@"
  fi
}

detect_os_family() {
  if [[ ! -r /etc/os-release ]]; then
    echo "Unsupported distribution." >&2
    exit 1
  fi

  # shellcheck disable=SC1091
  . /etc/os-release
  local id_like="${ID_LIKE:-}"
  local id="${ID:-}"

  case " ${id} ${id_like} " in
    *" debian "*|*" ubuntu "*)
      echo "Debian"
      ;;
    *" rhel "*|*" fedora "*|*" centos "*|*" rocky "*|*" almalinux "*)
      echo "RedHat"
      ;;
    *" suse "*|*" sles "*|*" opensuse "*)
      echo "Suse"
      ;;
    *)
      echo "Unsupported distribution." >&2
      exit 1
      ;;
  esac
}

install_docker() {
  local os_family
  os_family="$(detect_os_family)"

  case "${os_family}" in
    Debian)
      run apt-get update
      run apt-get install -y docker.io python3-docker
      ;;
    RedHat)
      if command -v dnf >/dev/null 2>&1; then
        run dnf install -y docker python3-docker
      else
        run yum install -y docker python3-docker
      fi
      ;;
    Suse)
      run zypper install -y docker python3-docker
      ;;
  esac
}

start_docker() {
  if command -v systemctl >/dev/null 2>&1; then
    run systemctl enable --now docker
  else
    run service docker start
  fi
}

prompt_for_local_rules() {
  echo
  read -r -p "Do you want to supply a falco_rules.local.yaml file? [y/N]: " reply
  case "${reply,,}" in
    y|yes)
      read -r -p "Enter full path to falco_rules.local.yaml: " rules_path
      if [[ ! -f "${rules_path}" ]]; then
        echo "Error: File does not exist: ${rules_path}" >&2
        exit 1
      fi
      OPTIONAL_RULES_MOUNT="${rules_path}:/etc/falco/falco_rules.local.yaml:ro"
      ;;
    *)
      echo "Proceeding with default Falco rules only."
      ;;
  esac
}

deploy_falco() {
  local volume_args=()
  local vol

  for vol in "${BASE_VOLUME_MOUNTS[@]}"; do
    volume_args+=("-v" "${vol}")
  done

  if [[ -n "${OPTIONAL_RULES_MOUNT}" ]]; then
    volume_args+=("-v" "${OPTIONAL_RULES_MOUNT}")
  fi

  run docker pull "${FALCO_IMAGE}"
  run docker rm -f "${FALCO_CONTAINER_NAME}" >/dev/null 2>&1 || true

  local falco_args=()
  if [[ "${FALCO_JSON_OUTPUT}" == "true" ]]; then
    falco_args+=("-o" "json_output=true")
  fi

  run docker run -d \
    --name "${FALCO_CONTAINER_NAME}" \
    --privileged \
    "${volume_args[@]}" \
    --restart "${FALCO_RESTART_POLICY}" \
    "${FALCO_IMAGE}" \
    "${falco_args[@]}"
}

write_promtail_config() {
  # Promtail scrapes ONLY the Falco container logs by container name regex
  run mkdir -p /etc/promtail-falco

  run bash -lc "cat > /etc/promtail-falco/promtail.yaml <<'YAML'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: ${LOKI_URL}

scrape_configs:
  - job_name: docker-falco
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s

    relabel_configs:
      # Keep only the Falco container
      - source_labels: [__meta_docker_container_name]
        regex: \\/${FALCO_CONTAINER_NAME}
        action: keep

      - source_labels: [__meta_docker_container_name]
        target_label: container

      - source_labels: [__meta_docker_container_image]
        target_label: image

      - source_labels: [__meta_docker_container_id]
        target_label: container_id

      # Point promtail at Docker JSON log files
      - source_labels: [__meta_docker_container_id]
        target_label: __path__
        replacement: /var/lib/docker/containers/\$1/\$1-json.log

    pipeline_stages:
      - docker: {}
YAML"
}

deploy_promtail() {
  if [[ "${ENABLE_PROMTAIL}" != "true" ]]; then
    echo "Promtail disabled (ENABLE_PROMTAIL=${ENABLE_PROMTAIL})."
    return 0
  fi

  write_promtail_config

  run docker pull "${PROMTAIL_IMAGE}"
  run docker rm -f "${PROMTAIL_CONTAINER_NAME}" >/dev/null 2>&1 || true

  run docker run -d \
    --name "${PROMTAIL_CONTAINER_NAME}" \
    --restart "${PROMTAIL_RESTART_POLICY}" \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
    -v /etc/promtail-falco/promtail.yaml:/etc/promtail/config.yml:ro \
    "${PROMTAIL_IMAGE}" \
    -config.file=/etc/promtail/config.yml
}

install_docker
start_docker
prompt_for_local_rules
deploy_falco
deploy_promtail

echo
echo "Done."
echo "Falco:     ${FALCO_CONTAINER_NAME}"
echo "Promtail:  ${PROMTAIL_CONTAINER_NAME} -> ${LOKI_URL}"