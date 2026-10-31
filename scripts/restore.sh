#!/usr/bin/env bash
# Đưa dữ liệu 9router vào server. Nhận:
#   - tệp .tgz do backup.sh tạo, hoặc
#   - thư mục ~/.9router chép từ máy tính (Windows: %APPDATA%\9router), đã nén thành .zip/.tgz hoặc để nguyên thư mục.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Chạy bằng sudo."; exit 1; }
SRC="${1:?Cách dùng: sudo bash scripts/restore.sh <backup.tgz | thư mục .9router | .zip>}"
DATA=/var/lib/9router/data
TMP="$(mktemp -d)"
case "$SRC" in
  *.tgz|*.tar.gz) tar xzf "$SRC" -C "$TMP" ;;
  *.zip) command -v unzip >/dev/null || apt-get install -y unzip; unzip -q "$SRC" -d "$TMP" ;;
  *) [ -d "$SRC" ] || { echo "Không thấy $SRC"; exit 1; }; cp -a "$SRC/." "$TMP/" ;;
esac
DB="$(find "$TMP" -name db.json -print -quit)"
[ -n "$DB" ] || { echo "Không tìm thấy db.json trong $SRC"; exit 1; }
systemctl stop 9router
[ -d "$DATA" ] && mv "$DATA" "${DATA}.bak-$(date +%s)"
mkdir -p "$DATA" && cp -a "$(dirname "$DB")/." "$DATA/"
rm -rf "$DATA/runtime"   # thư viện native của máy cũ (Windows) — server tự cài lại
chown -R ninerouter:ninerouter /var/lib/9router
rm -rf "$TMP"
systemctl start 9router
echo "Đã khôi phục từ $SRC. Kiểm tra: systemctl status 9router"
