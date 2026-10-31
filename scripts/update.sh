#!/usr/bin/env bash
# Cập nhật 9router lên bản mới nhất rồi khởi động lại dịch vụ.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Chạy bằng sudo."; exit 1; }
npm install -g "9router@${NR_VERSION:-latest}" --prefer-online
systemctl restart 9router
9router --version || true
systemctl --no-pager --lines=5 status 9router
