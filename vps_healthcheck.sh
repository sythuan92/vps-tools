#!/bin/bash
# ============================================================
#  VPS HEALTH CHECK - Khám tổng quát VPS + Docker
#  Chạy: bash vps_healthcheck.sh
#  Output: in màu, dễ scan bằng mắt
# ============================================================

# ---------- màu sắc ----------
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

OK="${GREEN}[OK]${RESET}"
WARN="${YELLOW}[WARN]${RESET}"
ERR="${RED}[ERR]${RESET}"
INFO="${CYAN}[INFO]${RESET}"

SECTION() { echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; echo -e "${BOLD}${CYAN}  $1${RESET}"; echo -e "${BOLD}${CYAN}══════════════════════════════════════════${RESET}"; }
SUB()     { echo -e "\n${BOLD}▶ $1${RESET}"; }

# ---------- ngưỡng cảnh báo ----------
CPU_WARN=80       # % CPU load trung bình (1 phút)
MEM_WARN=85       # % RAM đã dùng
DISK_WARN=85      # % disk đã dùng
LOG_TAIL=30       # số dòng log cuối mỗi container

SECTION "1. THÔNG TIN HỆ THỐNG"
echo -e "${INFO} Hostname  : $(hostname)"
echo -e "${INFO} OS        : $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || uname -a)"
echo -e "${INFO} Kernel    : $(uname -r)"
echo -e "${INFO} Uptime    : $(uptime -p 2>/dev/null || uptime)"
echo -e "${INFO} Thời gian : $(date '+%Y-%m-%d %H:%M:%S %Z')"

# ---------- 2. CPU ----------
SECTION "2. CPU"
LOAD1=$(awk '{print $1}' /proc/loadavg)
LOAD5=$(awk '{print $2}' /proc/loadavg)
LOAD15=$(awk '{print $3}' /proc/loadavg)
CORES=$(nproc)
LOAD_PCT=$(echo "$LOAD1 $CORES" | awk '{printf "%.0f", ($1/$2)*100}')

echo -e "  Load avg (1/5/15 min): ${BOLD}$LOAD1 / $LOAD5 / $LOAD15${RESET}  (${CORES} cores)"
if [ "$LOAD_PCT" -ge "$CPU_WARN" ]; then
  echo -e "  $ERR CPU load cao: ${LOAD_PCT}% (≥ ${CPU_WARN}%)"
else
  echo -e "  $OK CPU load: ${LOAD_PCT}%"
fi

SUB "Top 5 process ăn CPU nhiều nhất"
ps aux --sort=-%cpu | awk 'NR==1{print "  "$0} NR>1 && NR<=6{print "  "$0}' 2>/dev/null

# ---------- 3. RAM ----------
SECTION "3. RAM"
MEM_TOTAL=$(free -m | awk '/^Mem:/{print $2}')
MEM_USED=$(free -m  | awk '/^Mem:/{print $3}')
MEM_FREE=$(free -m  | awk '/^Mem:/{print $4}')
MEM_CACHE=$(free -m | awk '/^Mem:/{print $6}')
MEM_PCT=$(echo "$MEM_USED $MEM_TOTAL" | awk '{printf "%.0f", ($1/$2)*100}')

echo -e "  Tổng: ${MEM_TOTAL}MB  |  Dùng: ${MEM_USED}MB  |  Free: ${MEM_FREE}MB  |  Cache: ${MEM_CACHE}MB"
if [ "$MEM_PCT" -ge "$MEM_WARN" ]; then
  echo -e "  $ERR RAM sử dụng cao: ${MEM_PCT}% (≥ ${MEM_WARN}%)"
else
  echo -e "  $OK RAM: ${MEM_PCT}% đã dùng"
fi

SUB "Swap"
SWAP_TOTAL=$(free -m | awk '/^Swap:/{print $2}')
SWAP_USED=$(free -m  | awk '/^Swap:/{print $3}')
if [ "$SWAP_TOTAL" -gt 0 ] 2>/dev/null; then
  SWAP_PCT=$(echo "$SWAP_USED $SWAP_TOTAL" | awk '{printf "%.0f", ($1/$2)*100}')
  if [ "$SWAP_PCT" -ge 50 ]; then
    echo -e "  $WARN Swap đang dùng: ${SWAP_USED}MB/${SWAP_TOTAL}MB (${SWAP_PCT}%)"
  else
    echo -e "  $OK Swap: ${SWAP_USED}MB/${SWAP_TOTAL}MB"
  fi
else
  echo -e "  ${DIM}Không có Swap${RESET}"
fi

# ---------- 4. DISK ----------
SECTION "4. DISK"
df -hT | grep -vE '^tmpfs|^devtmpfs|^udev|^overlay|^shm' | head -1
df -hT | grep -vE '^tmpfs|^devtmpfs|^udev|^overlay|^shm' | tail -n +2 | while read line; do
  USE_PCT=$(echo "$line" | awk '{print $6}' | tr -d '%')
  MOUNT=$(echo "$line" | awk '{print $7}')
  if [ -n "$USE_PCT" ] && [ "$USE_PCT" -ge "$DISK_WARN" ] 2>/dev/null; then
    echo -e "  $ERR ${line}  ← DISK ĐẦY GẦN HẾT!"
  else
    echo -e "  $OK $line"
  fi
done

# ---------- 5. NETWORK ----------
SECTION "5. NETWORK"
SUB "Kết nối đang mở (ESTABLISHED)"
CONN=$(ss -s 2>/dev/null | grep estab | awk '{print $4}')
echo -e "  Established: ${BOLD}${CONN:-N/A}${RESET}"

SUB "Cổng đang lắng nghe (LISTEN)"
ss -tlnp 2>/dev/null | grep LISTEN | awk '{print "  "$0}' | head -20

SUB "Top interface (RX/TX)"
ip -s link show 2>/dev/null | awk '/^[0-9]+: /{iface=$2} /RX:/{getline; rx=$1} /TX:/{getline; print "  "iface"  RX:"rx"  TX:"$1}' | grep -v lo | head -5

# ---------- 6. SYSTEM HEALTH ----------
SECTION "6. SYSTEM HEALTH"

SUB "Failed systemd services"
FAILED=$(systemctl --failed --no-legend 2>/dev/null | grep -v "^$")
if [ -n "$FAILED" ]; then
  echo -e "  $ERR Có service bị lỗi:"
  echo "$FAILED" | while read line; do echo -e "    ${RED}$line${RESET}"; done
else
  echo -e "  $OK Không có failed service"
fi

SUB "OOM Killer (kernel kill process vì hết RAM)"
OOM=$(dmesg 2>/dev/null | grep -i "oom\|killed process" | tail -5)
if [ -n "$OOM" ]; then
  echo -e "  $ERR Phát hiện OOM kill gần đây:"
  echo "$OOM" | while read line; do echo -e "    ${RED}$line${RESET}"; done
else
  echo -e "  $OK Không có OOM kill"
fi

SUB "Kiểm tra /var/log/syslog hoặc /var/log/messages (lỗi gần đây)"
SYSLOG=""
[ -f /var/log/syslog ]   && SYSLOG=/var/log/syslog
[ -f /var/log/messages ] && SYSLOG=/var/log/messages
if [ -n "$SYSLOG" ]; then
  ERRORS=$(tail -200 "$SYSLOG" 2>/dev/null | grep -iE "error|critical|panic|fail" | tail -10)
  if [ -n "$ERRORS" ]; then
    echo -e "  $WARN Có dòng lỗi trong syslog:"
    echo "$ERRORS" | while read line; do echo -e "    ${YELLOW}$line${RESET}"; done
  else
    echo -e "  $OK Không có lỗi nổi bật trong syslog"
  fi
else
  echo -e "  ${DIM}Không tìm thấy syslog${RESET}"
fi

# ============================================================
#  DOCKER SECTION
# ============================================================
SECTION "7. DOCKER - TỔNG QUAN"

if ! command -v docker &>/dev/null; then
  echo -e "  ${DIM}Docker không được cài đặt trên máy này${RESET}"
else
  # Docker daemon
  if ! docker info &>/dev/null 2>&1; then
    echo -e "  $ERR Docker daemon không chạy hoặc không có quyền!"
  else
    echo -e "  $OK Docker daemon đang chạy"
    docker version --format 'Engine: {{.Server.Version}}  |  API: {{.Server.APIVersion}}' 2>/dev/null | while read l; do echo -e "  ${INFO} $l"; done

    # Tóm tắt containers
    TOTAL=$(docker ps -a -q | wc -l)
    RUNNING=$(docker ps -q | wc -l)
    STOPPED=$(docker ps -a --filter "status=exited" -q | wc -l)
    RESTARTING=$(docker ps -a --filter "status=restarting" -q | wc -l)
    DEAD=$(docker ps -a --filter "status=dead" -q | wc -l)
    PAUSED=$(docker ps -a --filter "status=paused" -q | wc -l)

    echo ""
    echo -e "  Tổng containers : ${BOLD}$TOTAL${RESET}"
    echo -e "  ${GREEN}▶ Running      : $RUNNING${RESET}"
    [ "$STOPPED"    -gt 0 ] && echo -e "  ${YELLOW}■ Exited       : $STOPPED${RESET}"    || echo -e "  ${DIM}■ Exited       : $STOPPED${RESET}"
    [ "$RESTARTING" -gt 0 ] && echo -e "  ${RED}↺ Restarting   : $RESTARTING${RESET}"   || echo -e "  ${DIM}↺ Restarting   : $RESTARTING${RESET}"
    [ "$DEAD"       -gt 0 ] && echo -e "  ${RED}✖ Dead         : $DEAD${RESET}"          || echo -e "  ${DIM}✖ Dead         : $DEAD${RESET}"
    [ "$PAUSED"     -gt 0 ] && echo -e "  ${YELLOW}⏸ Paused       : $PAUSED${RESET}"    || echo -e "  ${DIM}⏸ Paused       : $PAUSED${RESET}"

    # ---------- 8. Docker resource usage ----------
    SECTION "8. DOCKER - RESOURCE USAGE (stats 1 snapshot)"
    echo -e "  ${DIM}(Đang lấy snapshot stats, chờ vài giây...)${RESET}"
    docker stats --no-stream --format \
      "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" \
      2>/dev/null | head -1  # header
    docker stats --no-stream --format \
      "{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}" \
      2>/dev/null | while IFS=$'\t' read NAME CPU MEM MEMPCT NET BLK PIDS; do
        MEM_VAL=$(echo "$MEMPCT" | tr -d '%' | cut -d. -f1)
        CPU_VAL=$(echo "$CPU" | tr -d '%' | cut -d. -f1)
        FLAG=""
        [ "$CPU_VAL" -ge 80 ] 2>/dev/null && FLAG="${FLAG}${RED}[CPU CAO]${RESET} "
        [ "$MEM_VAL" -ge 80 ] 2>/dev/null && FLAG="${FLAG}${RED}[MEM CAO]${RESET} "
        if [ -n "$FLAG" ]; then
          echo -e "  ${RED}▶ $NAME${RESET}  CPU:$CPU  MEM:$MEM ($MEMPCT)  NET:$NET  BLK:$BLK  PIDs:$PIDS  ← $FLAG"
        else
          echo -e "    $NAME  CPU:$CPU  MEM:$MEM ($MEMPCT)  NET:$NET  BLK:$BLK  PIDs:$PIDS"
        fi
    done

    # ---------- 9. Chi tiết từng container ----------
    SECTION "9. DOCKER - CHI TIẾT TỪNG CONTAINER"

    docker ps -a --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null | \
    while IFS=$'\t' read CID CNAME CSTATUS CIMAGE; do

      # Màu theo trạng thái
      case "$CSTATUS" in
        Up*)        STATUS_COLOR="${GREEN}"  ;;
        Exited*)    STATUS_COLOR="${YELLOW}" ;;
        Restarting*)STATUS_COLOR="${RED}"    ;;
        Dead*)      STATUS_COLOR="${RED}"    ;;
        *)          STATUS_COLOR="${DIM}"    ;;
      esac

      echo ""
      echo -e "${BOLD}┌─ Container: ${CYAN}$CNAME${RESET}${BOLD} (${CID:0:12})${RESET}"
      echo -e "│  Image  : $CIMAGE"
      echo -e "│  Status : ${STATUS_COLOR}${CSTATUS}${RESET}"

      # Restart count
      RESTARTS=$(docker inspect --format='{{.RestartCount}}' "$CID" 2>/dev/null)
      if [ "$RESTARTS" -gt 3 ] 2>/dev/null; then
        echo -e "│  $ERR Restart count: ${RED}${RESTARTS}${RESET}  ← restart nhiều lần!"
      else
        echo -e "│  Restarts : $RESTARTS"
      fi

      # Health check
      HEALTH=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' "$CID" 2>/dev/null)
      case "$HEALTH" in
        healthy)         echo -e "│  Health   : ${GREEN}$HEALTH${RESET}" ;;
        unhealthy)       echo -e "│  $ERR Health: ${RED}$HEALTH${RESET}" ;;
        starting)        echo -e "│  ${WARN} Health: ${YELLOW}$HEALTH${RESET}" ;;
        *)               echo -e "│  ${DIM}Health   : $HEALTH${RESET}" ;;
      esac

      # Port mapping
      PORTS=$(docker port "$CID" 2>/dev/null | tr '\n' '  ')
      [ -n "$PORTS" ] && echo -e "│  Ports    : $PORTS" || echo -e "│  ${DIM}Ports    : (none)${RESET}"

      # Log tail - lọc dòng lỗi
      echo -e "│  ${DIM}── Log cuối (${LOG_TAIL} dòng) ──────────────────────────${RESET}"
      LOGS=$(docker logs --tail="$LOG_TAIL" "$CID" 2>&1)
      ERROR_LINES=$(echo "$LOGS" | grep -iE "error|exception|fatal|panic|critical|fail|warn" | tail -10)

      if [ -n "$ERROR_LINES" ]; then
        echo -e "│  $WARN Có dòng đáng chú ý trong log:"
        echo "$ERROR_LINES" | while read logline; do
          if echo "$logline" | grep -qiE "error|exception|fatal|panic|critical"; then
            echo -e "│    ${RED}$logline${RESET}"
          else
            echo -e "│    ${YELLOW}$logline${RESET}"
          fi
        done
      else
        echo -e "│    ${GREEN}Không có lỗi nổi bật trong ${LOG_TAIL} dòng log cuối${RESET}"
      fi

      # 5 dòng log cuối nhất (bất kể nội dung)
      echo -e "│  ${DIM}── 5 dòng log mới nhất ─────────────────────────────${RESET}"
      echo "$LOGS" | tail -5 | while read logline; do
        echo -e "│    ${DIM}$logline${RESET}"
      done

      echo -e "└──────────────────────────────────────────────────────"
    done

    # ---------- 10. Networks & Volumes ----------
    SECTION "10. DOCKER NETWORKS & VOLUMES"
    SUB "Networks"
    docker network ls 2>/dev/null | awk '{print "  "$0}'

    SUB "Volumes"
    docker volume ls 2>/dev/null | awk '{print "  "$0}'

    SUB "Disk usage Docker"
    docker system df 2>/dev/null | awk '{print "  "$0}'

    # ---------- 11. Containers đang cần chú ý ----------
    SECTION "11. TÓM TẮT - CẦN CHÚ Ý"
    NEED_ATTENTION=0

    docker ps -a --format "{{.Names}}\t{{.Status}}" 2>/dev/null | while IFS=$'\t' read CNAME CSTATUS; do
      case "$CSTATUS" in
        Exited*)
          EXIT_CODE=$(echo "$CSTATUS" | grep -oP '(?<=\().*(?=\))')
          if [ "$EXIT_CODE" != "0" ]; then
            echo -e "  $ERR ${CNAME}: exited với code ${RED}${EXIT_CODE}${RESET}"
          else
            echo -e "  $WARN ${CNAME}: stopped (exit 0)"
          fi
          ;;
        Restarting*)
          echo -e "  $ERR ${CNAME}: đang RESTARTING LOOP!"
          ;;
        Dead*)
          echo -e "  $ERR ${CNAME}: DEAD!"
          ;;
      esac
    done

    # Containers restart nhiều
    docker ps -a --format "{{.Names}}\t{{.ID}}" 2>/dev/null | while IFS=$'\t' read CNAME CID; do
      RC=$(docker inspect --format='{{.RestartCount}}' "$CID" 2>/dev/null)
      [ "$RC" -gt 3 ] 2>/dev/null && echo -e "  $ERR ${CNAME}: restart ${RED}${RC}${RESET} lần"
    done

    # Containers unhealthy
    docker ps --filter "health=unhealthy" --format "{{.Names}}" 2>/dev/null | while read CNAME; do
      echo -e "  $ERR ${CNAME}: UNHEALTHY"
    done

    echo ""
    echo -e "  ${DIM}(Nếu không có dòng nào ở trên = tất cả containers đều ổn)${RESET}"
  fi
fi

# ---------- DONE ----------
echo ""
echo -e "${BOLD}${GREEN}══════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}  ✓ HEALTH CHECK HOÀN TẤT${RESET}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════${RESET}"
echo ""