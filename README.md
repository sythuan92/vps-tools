# 🖥️ VPS Tools

> **Bộ công cụ giám sát VPS & Docker** — chạy một lệnh, thấy ngay toàn bộ sức khỏe server.

![Shell](https://img.shields.io/badge/shell-bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![Platform](https://img.shields.io/badge/platform-Linux-FCC624?style=flat-square&logo=linux&logoColor=black)
![Docker](https://img.shields.io/badge/docker-supported-2496ED?style=flat-square&logo=docker&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)

---

## ✨ Tính năng

| # | Mục kiểm tra | Chi tiết |
|---|---|---|
| 1 | **Thông tin hệ thống** | Hostname, OS, Kernel, Uptime, Thời gian |
| 2 | **CPU** | Load average 1/5/15 phút, % so với số core, top 5 process ăn CPU |
| 3 | **RAM & Swap** | Tổng / Đã dùng / Free / Cache, cảnh báo ngưỡng |
| 4 | **Disk** | Tất cả mount point, cảnh báo khi gần đầy |
| 5 | **Network** | Số kết nối ESTABLISHED, cổng đang LISTEN, RX/TX per interface |
| 6 | **System Health** | Failed systemd services, OOM Killer, lỗi trong syslog |
| 7 | **Docker Overview** | Tổng containers theo trạng thái (running/exited/restarting/dead) |
| 8 | **Docker Stats** | CPU%, RAM%, Net I/O, Block I/O snapshot từng container |
| 9 | **Docker Chi tiết** | Log tail, healthcheck, port mapping, restart count từng container |
| 10 | **Docker Networks & Volumes** | Danh sách network, volume, disk usage Docker |
| 11 | **Tóm tắt cần chú ý** | Highlight container lỗi, restart loop, unhealthy |

---

## 🚀 Sử dụng

```bash
# Clone về
git clone https://github.com/sythuan92/vps-tools.git
cd vps-tools

# Cấp quyền thực thi
chmod +x vps_healthcheck.sh

# Chạy
bash vps_healthcheck.sh
```

> **Tip:** Cần `sudo` nếu muốn đọc `dmesg` (OOM Killer) hoặc Docker daemon yêu cầu quyền root.

```bash
sudo bash vps_healthcheck.sh
```

---

## ⚙️ Cấu hình ngưỡng cảnh báo

Chỉnh trực tiếp trong file script (phần đầu):

```bash
CPU_WARN=80    # % CPU load trung bình (1 phút) → cảnh báo khi vượt ngưỡng
MEM_WARN=85    # % RAM đã dùng
DISK_WARN=85   # % disk đã dùng
LOG_TAIL=30    # Số dòng log cuối mỗi Docker container
```

---

## 📋 Yêu cầu

- **OS:** Linux (Ubuntu, Debian, CentOS, AlmaLinux, ...)
- **Shell:** Bash 4+
- **Tùy chọn:** Docker Engine (nếu muốn phần Docker hoạt động)
- **Công cụ cần có:** `ss`, `ip`, `free`, `df`, `ps`, `awk`, `grep` — đều có sẵn trên mọi distro

---

## 🎨 Output mẫu

```
══════════════════════════════════════════
  1. THÔNG TIN HỆ THỐNG
══════════════════════════════════════════
[INFO] Hostname  : my-vps
[INFO] OS        : Ubuntu 22.04.3 LTS
[INFO] Kernel    : 5.15.0-91-generic
[INFO] Uptime    : up 14 days, 3 hours, 22 minutes

══════════════════════════════════════════
  2. CPU
══════════════════════════════════════════
  Load avg (1/5/15 min): 0.42 / 0.38 / 0.35  (4 cores)
  [OK] CPU load: 10%

══════════════════════════════════════════
  3. RAM
══════════════════════════════════════════
  Tổng: 7982MB  |  Dùng: 3241MB  |  Free: 512MB  |  Cache: 4229MB
  [OK] RAM: 40% đã dùng

...

┌─ Container: my-app (a1b2c3d4e5f6)
│  Image  : myapp:latest
│  Status : Up 3 days
│  Restarts : 0
│  Health   : healthy
│  Ports    : 0.0.0.0:3000->3000/tcp
│  ── Log cuối (30 dòng) ──────────────────────────
│    Không có lỗi nổi bật trong 30 dòng log cuối
└──────────────────────────────────────────────────────
```

---

## 🔄 Tự động hóa với Cron

Chạy health check mỗi ngày lúc 8 giờ sáng và lưu log:

```bash
crontab -e
```

```cron
0 8 * * * /path/to/vps_healthcheck.sh >> /var/log/vps_healthcheck.log 2>&1
```

---

## 📁 Cấu trúc repo

```
vps-tools/
└── vps_healthcheck.sh   # Script kiểm tra sức khỏe VPS + Docker
```

> Sẽ có thêm các tool khác trong tương lai.

---

## 📄 License

MIT © [sythuan92](https://github.com/sythuan92)
