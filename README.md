# 9router-server-247

Chạy [9router](https://www.npmjs.com/package/9router) 24/7 trên VPS để gọi API 9router online, không cần bật máy tính.

## 1. Chọn VPS miễn phí

| Lựa chọn | Cấu hình free | Ghi chú |
|---|---|---|
| **Oracle Cloud Always Free** (khuyến nghị) | ARM Ampere tới 4 OCPU / 24 GB RAM, 200 GB đĩa | Free vĩnh viễn, cần thẻ để xác minh (không trừ tiền). Chọn region có máy ARM trống (Singapore/Tokyo hay hết — thử lại hoặc chọn region khác). Nâng lên "Pay As You Go" (vẫn 0đ nếu trong hạn mức) để máy không bị thu hồi khi rảnh. |
| Google Cloud e2-micro | 2 vCPU chia sẻ / 1 GB RAM, 30 GB đĩa | Free vĩnh viễn ở us-west1/us-central1/us-east1, cần thẻ. Đủ cho 9router (script tự thêm swap). |
| Render / Koyeb / HF Spaces | — | **Không hợp**: ngủ khi rảnh và mất dữ liệu (tài khoản provider) khi khởi động lại. |

Tạo máy **Ubuntu 22.04/24.04**, mở cổng **80 và 443** ở tường lửa nhà cung cấp
(Oracle: Networking → VCN → Security List → Add Ingress Rule `0.0.0.0/0` TCP 80,443; GCP: tích "Allow HTTP/HTTPS traffic").

## 2. Cài (1 lệnh, SSH vào VPS)

```bash
curl -fsSL https://raw.githubusercontent.com/dungthanhluudhl-ui/9router-server-247/main/scripts/install.sh | sudo bash
```

Script: cài Node 22 → `npm install -g 9router` → dịch vụ systemd (tự chạy lại khi lỗi/khởi động lại máy) →
Caddy HTTPS tự động với địa chỉ miễn phí `https://<IP>.sslip.io` (có tên miền riêng: `sudo DOMAIN=ai.vidu.com bash install.sh`).

## 3. Sau khi cài

1. Mở `https://<IP>.sslip.io` → **đặt mật khẩu dashboard ngay** và bật bắt buộc API key (server công khai trên Internet).
2. Thêm provider: đăng nhập lại trong dashboard, **hoặc** chép dữ liệu từ máy tính đang chạy 9router
   (Windows `%APPDATA%\9router`, Mac/Linux `~/.9router`) lên VPS rồi:
   ```bash
   sudo bash scripts/restore.sh ./9router.zip
   ```
   (OAuth của một số provider gọi về `localhost` — chép dữ liệu từ máy cũ là cách chắc nhất.)
3. Tạo API key trong dashboard, rồi đặt ở môi trường Claude Code cloud / `.env`:
   ```
   NINEROUTER_BASE_URL=https://<IP>.sslip.io/v1
   NINEROUTER_API_KEY=<key>
   ```

## Vận hành

```bash
sudo systemctl status 9router        # trạng thái
sudo journalctl -u 9router -f        # log
sudo bash scripts/update.sh          # cập nhật 9router
sudo bash scripts/backup.sh          # sao lưu dữ liệu (.tgz chứa token — không commit)
```

Docker thay cho npm: `docker compose up -d` (xem `docker-compose.yml`).
