# AdsPower Global on Linux — 主界面连不上网（排查与修复）

Ubuntu 24.04 上 **AdsPower Global 8.7.x**（Electron 35）主窗口加载 `app-global.adspower.net` / `app-sg.adspower.com` 等失败，而 **curl / 系统 Chrome 正常**。本文记录一次完整排查与可用修复。

## 现象

- AdsPower 提示网络错误 / tips 页（`tips.html?code=-100` 或 `-7`）
- 日志 `~/.config/adspower_global/logs/main.log` 常见：
  - `ERR_CONNECTION_CLOSED (-100)`
  - `ERR_TIMED_OUT (-7)`（约 30 秒后）
  - `ERR_FAILED (-2)`（退出或切线时）

## 容易误判的点

| 检查项 | 结论 |
|--------|------|
| 关 TUN / 关系统代理 | 必要但不充分；Electron 仍可能走坏路径 |
| 终端 `curl` 200 | **不能**代表 AdsPower 能连上 |
| 命令行加 `--disable-ipv6` | AdsPower 启动器可能 **未把参数传给** Chromium 主进程 |
| 在客户端里切换 sg / global / app 线 | 会改 `config.json` 的 `appLine`，加重排查难度 |

## 根因（本次环境）

1. **sing-box TUN（`tun0`）** 开启时：IPv6 TLS 到 CloudFront / AdsPower CDN **握手 EOF**；部分 IPv4 节点超时 → Electron `ERR_CONNECTION_CLOSED`。
2. **TUN 关闭后**：系统直连 IPv4 正常，但 **AdsPower 内置 Chromium** 仍可能对 AdsPower 域名做 **IPv6 连接**，卡满 **~30s → ERR_TIMED_OUT**。
3. **线路频繁切换**：`~/.config/adspower_global/config.json` 中 `appLine` 在 `app-global` / `app-sg` / `app.adspowerapp.com` 之间变化，对应不同 CDN。

验证命令（对比 curl vs Electron 行为）：

```bash
curl -4 -sS -o /dev/null -w '%{http_code} ip:%{remote_ip} time:%{time_total}\n' https://app-global.adspower.net/
tail -30 ~/.config/adspower_global/logs/main.log
```

## 修复方案（推荐）

使用仓库内脚本（需 **sudo** 写 `/etc/hosts` 一段，仅 IPv4）：

```bash
git clone <本仓库 URL>
cd adspower-linux-network-fix
./scripts/adspower-fix-network.sh
```

脚本会：

1. 退出 AdsPower 进程  
2. 备份并删除 `Network Persistent State`（清 QUIC / 坏线路缓存）  
3. 将 `appLine` 固定为 `https://app-global.adspower.net`  
4. 在 `/etc/hosts` 追加 `adspower-ipv4-fix-*` 段（无 AAAA，避免 Electron IPv6 超时）  
5. 以 `--disable-ipv6 --disable-quic --proxy-server=direct://` 启动 AdsPower  

成功时终端可能出现 `did-finish-load`（见实际运行记录）。

### 撤销 hosts 段

编辑 `/etc/hosts`，删除 `# adspower-ipv4-fix-start` 与 `# adspower-ipv4-fix-end` 之间的行。

### 手动启动（hosts 已配置时）

```bash
"/opt/AdsPower Global/adspower_global" \
  --disable-ipv6 --disable-quic --proxy-server=direct://
```

## 与「环境浏览器代理」的区别

- **主界面进不去**：本文范围（Electron + DNS/IPv6/线路）。  
- **主界面正常、开 profile 失败**：查各环境代理、20725 本地节点、`cwd_global` 日志，不是同一问题。

## 环境信息（记录用）

- OS: Ubuntu 24.04, kernel 6.14  
- AdsPower: 8.7.23, 内置节点曾升到 v2.8.9.9  
- 曾用 sing-box TUN + 本机 `127.0.0.1:7893`（hawaii-fast，非 TUN）  

## 许可

文档与脚本按 **MIT** 提供，按现状使用，自行承担风险。与 AdsPower 官方无关联。
