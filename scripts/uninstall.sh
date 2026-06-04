#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="/etc/sing-box"
INSTALL_DIR="/opt/singbox-rule-ui"
PURGE=0
ASSUME_YES=0

usage() {
  cat <<'EOF'
Usage:
  sudo bash scripts/uninstall.sh [--purge] [--yes]

Default uninstall keeps /etc/sing-box and /usr/local/bin/sing-box.
Use --purge to remove config, downloaded UI files, rule cache, and sing-box binary.
EOF
}

need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Please run as root." >&2
    exit 1
  fi
}

ask_confirm() {
  if [ "$ASSUME_YES" = "1" ]; then
    return 0
  fi
  if [ ! -r /dev/tty ]; then
    echo "No interactive terminal. Re-run with --yes to confirm." >&2
    exit 1
  fi
  prompt="Uninstall sing-box-gateway-ui and stop gateway services?"
  if [ "$PURGE" = "1" ]; then
    prompt="PURGE all sing-box-gateway-ui files, configs, and sing-box binary?"
  fi
  printf "%s [y/N]: " "$prompt" > /dev/tty
  read -r answer < /dev/tty
  case "$answer" in
    y|Y|yes|YES) ;;
    *) echo "Cancelled."; exit 0 ;;
  esac
}

run_systemctl() {
  if command -v systemctl >/dev/null 2>&1; then
    systemctl "$@" >/dev/null 2>&1 || true
  fi
}

cleanup_tproxy_runtime() {
  if command -v nft >/dev/null 2>&1; then
    nft delete table inet singbox >/dev/null 2>&1 || true
  fi
  ip rule del fwmark 1 table 100 >/dev/null 2>&1 || true
  ip -6 rule del fwmark 1 table 100 >/dev/null 2>&1 || true
  ip route flush table 100 >/dev/null 2>&1 || true
  ip -6 route flush table 100 >/dev/null 2>&1 || true
}

restore_resolver_if_purging() {
  if [ "$PURGE" != "1" ]; then
    return
  fi
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files systemd-resolved.service >/dev/null 2>&1; then
    systemctl enable --now systemd-resolved.service >/dev/null 2>&1 || true
    if [ -e /run/systemd/resolve/stub-resolv.conf ]; then
      ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
      return
    fi
  fi
  rm -f /etc/resolv.conf
  {
    echo "nameserver 223.5.5.5"
    echo "nameserver 1.1.1.1"
    echo "options timeout:2 attempts:2"
  } > /etc/resolv.conf
}

parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --purge) PURGE=1 ;;
      -y|--yes) ASSUME_YES=1 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $arg" >&2; usage >&2; exit 1 ;;
    esac
  done
}

main() {
  parse_args "$@"
  need_root
  ask_confirm

  echo "Stopping services..."
  run_systemctl disable --now update-sing-box-rules-jsdelivr.timer
  run_systemctl disable --now update-sing-box-rules-jsdelivr.service
  run_systemctl disable --now singbox-rule-ui.service
  run_systemctl disable --now sing-box.service
  run_systemctl disable --now sing-box-tproxy.service

  cleanup_tproxy_runtime

  echo "Removing service files and helper scripts..."
  rm -f \
    /etc/systemd/system/sing-box.service \
    /etc/systemd/system/sing-box-tproxy.service \
    /etc/systemd/system/singbox-rule-ui.service \
    /etc/systemd/system/update-sing-box-rules-jsdelivr.service \
    /etc/systemd/system/update-sing-box-rules-jsdelivr.timer \
    /usr/local/sbin/sing-box-tproxy-setup \
    /usr/local/sbin/refresh-sing-box-runtime-config \
    /usr/local/sbin/update-sing-box-rules-jsdelivr \
    /usr/local/bin/sing-box-gateway-info \
    /usr/local/bin/sing-box-gateway-uninstall \
    /etc/sysctl.d/99-sing-box-tproxy.conf

  rm -rf "$INSTALL_DIR"
  restore_resolver_if_purging

  if [ "$PURGE" = "1" ]; then
    echo "Purging config and sing-box binary..."
    rm -rf "$CONFIG_DIR"
    rm -f /usr/local/bin/sing-box
  else
    echo "Kept $CONFIG_DIR and /usr/local/bin/sing-box."
  fi

  run_systemctl daemon-reload
  echo "Uninstalled."
}

main "$@"
