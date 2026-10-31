#!/usr/bin/env bash
# Cài 9router chạy 24/7 trên VPS Ubuntu/Debian (Oracle Always Free, GCP e2-micro...).
#   curl -fsSL https://raw.githubusercontent.com/dungthanhluudhl-ui/9router-server-247/main/scripts/install.sh | sudo bash
# Tuỳ chọn (biến môi trường):
#   DOMAIN=ten.mien.cua.ban   tên miền trỏ về IP VPS; bỏ trống -> dùng <ip>.sslip.io (miễn phí, có HTTPS)
#   NR_VERSION=latest         phiên bản 9router
#   NR_PORT=20128             cổng nội bộ (chỉ nghe 127.0.0.1, ra ngoài qua Caddy HTTPS)
#   NO_HTTPS=1                không cài Caddy, mở thẳng cổng NR_PORT (không khuyến nghị)
set -euo pipefail

NR_VERSION="${NR_VERSION:-latest}"
NR_PORT="${NR_PORT:-20128}"
NR_USER="${NR_USER:-ninerouter}"
NR_HOME="/var/lib/9router"

[ "$(id -u)" -eq 0 ] || { echo "Chạy bằng sudo/root."; exit 1; }
command -v apt-get >/dev/null || { echo "Script chỉ hỗ trợ Ubuntu/Debian."; exit 1; }

echo "==> Cài gói nền + Node.js 22"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates gnupg iptables
if ! command -v node >/dev/null || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]; then
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  apt-get install -y nodejs
fi
node -v

# Máy 1 GB RAM (GCP e2-micro): thêm swap 2 GB để npm install không bị OOM
if [ "$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)" -lt 2000 ] && ! swapon --show | grep -q .; then
  echo "==> Thêm swap 2 GB"
  fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> npm install -g 9router@${NR_VERSION}"
npm install -g "9router@${NR_VERSION}" --prefer-online
NR_BIN="$(command -v 9router)"

id "$NR_USER" >/dev/null 2>&1 || useradd --system --home-dir "$NR_HOME" --create-home --shell /usr/sbin/nologin "$NR_USER"
mkdir -p "$NR_HOME/data" && chown -R "$NR_USER:$NR_USER" "$NR_HOME"

BIND_HOST=127.0.0.1
[ "${NO_HTTPS:-0}" = "1" ] && BIND_HOST=0.0.0.0

echo "==> Tạo dịch vụ systemd 9router (tự chạy lại khi lỗi/khởi động máy)"
cat > /etc/systemd/system/9router.service <<UNIT
[Unit]
Description=9Router AI router
After=network-online.target
Wants=network-online.target

[Service]
User=${NR_USER}
Environment=HOME=${NR_HOME}
Environment=DATA_DIR=${NR_HOME}/data
Environment=NODE_ENV=production
ExecStart=${NR_BIN} --host ${BIND_HOST} --port ${NR_PORT} --no-browser --skip-update --log
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now 9router

# Oracle Ubuntu chặn mọi cổng bằng iptables (REJECT) -> mở 80/443 (hoặc cổng 9router nếu NO_HTTPS)
open_port() {
  iptables -C INPUT -p tcp --dport "$1" -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p tcp --dport "$1" -j ACCEPT
}
if [ "${NO_HTTPS:-0}" = "1" ]; then
  open_port "$NR_PORT"
else
  open_port 80; open_port 443
fi
if [ -d /etc/iptables ] || dpkg -s netfilter-persistent >/dev/null 2>&1; then
  apt-get install -y iptables-persistent >/dev/null 2>&1 || true
  netfilter-persistent save 2>/dev/null || iptables-save > /etc/iptables/rules.v4
fi

PUBLIC_IP="$(curl -fsS4 https://api.ipify.org || curl -fsS4 https://ifconfig.me)"

if [ "${NO_HTTPS:-0}" != "1" ]; then
  DOMAIN="${DOMAIN:-${PUBLIC_IP}.sslip.io}"
  echo "==> Cài Caddy (HTTPS tự động Let's Encrypt) cho ${DOMAIN}"
  if ! command -v caddy >/dev/null; then
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' > /etc/apt/sources.list.d/caddy-stable.list
    apt-get update -y && apt-get install -y caddy
  fi
  cat > /etc/caddy/Caddyfile <<CADDY
${DOMAIN} {
	encode zstd gzip
	reverse_proxy 127.0.0.1:${NR_PORT} {
		flush_interval -1
		transport http {
			read_timeout 30m
			write_timeout 30m
		}
	}
}
CADDY
  systemctl enable caddy && systemctl restart caddy
  URL="https://${DOMAIN}"
else
  URL="http://${PUBLIC_IP}:${NR_PORT}"
fi

sleep 5
systemctl --no-pager --lines=5 status 9router || true
cat <<DONE

==================================================================
 9router đang chạy 24/7.
 Dashboard : ${URL}
 API (base): ${URL}/v1
 Dữ liệu   : ${NR_HOME}/data  (sao lưu: sudo bash scripts/backup.sh)

 VIỆC CẦN LÀM NGAY:
 1. Mở dashboard -> ĐẶT MẬT KHẨU, bật bắt buộc API key, tạo API key.
 2. Kết nối provider (đăng nhập lại tài khoản, hoặc chép db từ máy cũ: xem README).
 3. Ở môi trường Claude Code cloud đặt:
      NINEROUTER_BASE_URL=${URL}/v1
      NINEROUTER_API_KEY=<key vừa tạo>
 Nếu không vào được: mở cổng 80/443 ở tường lửa của nhà cung cấp
 (Oracle: VCN -> Security List -> Ingress; GCP: VPC firewall).
==================================================================
DONE
