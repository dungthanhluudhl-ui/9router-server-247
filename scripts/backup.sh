#!/usr/bin/env bash
# Sao lưu dữ liệu 9router (tài khoản provider, API key, cài đặt) thành tệp .tgz.
# Khôi phục: sudo bash scripts/restore.sh <tệp.tgz>
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Chạy bằng sudo."; exit 1; }
OUT="${1:-$HOME/9router-backup-$(date +%Y%m%d-%H%M%S).tgz}"
tar czf "$OUT" -C /var/lib/9router data
chmod 600 "$OUT"
echo "Đã sao lưu: $OUT  (chứa token đăng nhập — KHÔNG commit lên git, KHÔNG chia sẻ)"
