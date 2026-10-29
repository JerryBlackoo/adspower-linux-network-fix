#!/usr/bin/env bash
# AdsPower 主界面 ERR_TIMED_OUT / ERR_CONNECTION_CLOSED：强制 IPv4 + 固定 Global 线路
set -euo pipefail

NS="$HOME/.config/adspower_global/Network Persistent State"
STAMP=$(date +%Y%m%d-%H%M%S)

echo "[1/4] 退出 AdsPower…"
pkill -f '/opt/AdsPower Global/adspower_global' 2>/dev/null || true
sleep 2

echo "[2/4] 备份并清理 Electron 网络缓存（QUIC/坏线路记录）…"
if [[ -f "$NS" ]]; then
  cp "$NS" "${NS}.bak-${STAMP}"
  rm -f "$NS"
fi

echo "[3/4] 固定 appLine 为 Global（勿在客户端里来回切 sg/app 线）…"
python3 - <<'PY'
import json
from pathlib import Path
p = Path.home() / ".config/adspower_global/config.json"
d = json.loads(p.read_text())
want = "https://app-global.adspower.net"
old = d.get("appLine")
if old != want:
    d["appLine"] = want
    p.write_text(json.dumps(d, ensure_ascii=False, indent="\t") + "\n")
    print(f"  appLine: {old!r} -> {want!r}")
else:
    print(f"  appLine 已是 {want}")
PY

echo "[4/4] 写入 /etc/hosts（仅 IPv4，避免 Electron 卡 IPv6 30 秒超时）…"
HOSTS_BLOCK='# adspower-ipv4-fix-start
211.95.37.91 app-global.adspower.net
112.132.35.140 app-global.adspower.net
23.251.99.194 api-global.adspower.net
76.223.109.22 api.adspower.net
75.2.97.117 api.adspower.net
108.157.254.129 app.adspowerapp.com
108.157.254.62 app-sg.adspower.com
47.245.124.73 app-sg.adspower.com
# adspower-ipv4-fix-end'

if grep -q 'adspower-ipv4-fix-start' /etc/hosts 2>/dev/null; then
  echo "  /etc/hosts 里已有 adspower 段，跳过"
else
  printf '%s\n' "$HOSTS_BLOCK" | sudo tee -a /etc/hosts >/dev/null
  echo "  已追加 hosts 段"
fi

echo
echo "启动 AdsPower（带 Chromium 参数）…"
exec "/opt/AdsPower Global/adspower_global" \
  --disable-ipv6 \
  --disable-quic \
  --proxy-server=direct:// \
  "$@"
