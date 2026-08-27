# USGiftCardHub 容灾接管与备用部署手册

本文档用于 VPS200 故障时，将 `usgiftcardhub.com` 接管到 VPS201 或 VPS228。操作目标是保持单写、使用最新完整快照、先验证备用源站再切换 Cloudflare。

> 红线：任何时刻只能有一台服务器运行 API、Worker 和 Redis。不能在未确认 VPS200 停止写入时正式激活温备。

## 1. 当前拓扑

| 角色 | SSH 别名 | 公网 IP | 正常状态 |
| --- | --- | --- | --- |
| 主站 | `vps200` | `38.110.228.200` | API、Worker、Redis 运行 |
| 温备 A | `vps201` | `38.110.228.201` | 只应用副本，业务服务停止 |
| 温备 B | `vps228` | `154.29.74.228` | 只应用副本，业务服务停止 |

数据链路：

1. VPS200 每 5 分钟使用 SQLite 在线 Backup API 和 Redis RDB 生成可恢复快照。
2. VPS200 通过 Tailscale 和 rsync 将快照推送到 VPS201、VPS228。
3. 两台温备每 5 分钟校验 `SHA256SUMS`，只在收到最后发送的 `READY` 后应用快照。
4. VPS200 每小时生成 AES-256-CBC 加密完整归档并上传 Google Drive。

SQLite 是商品、订单、支付、卡密和设置等业务数据的主存储。Redis 用于缓存和异步任务队列，不是第二套业务主数据库。SQLite、Redis 与 uploads 的取样相差数秒，因此副本保证可恢复一致性，不保证跨存储原子事务时点。

## 2. 正常状态基线

VPS200 应满足：

```text
usgiftcardhub.service                 active
usgiftcardhub-worker.service          active
redis-server.service                  active
usgiftcardhub-snapshot.timer          active
usgiftcardhub-archive.timer           active
usgiftcardhub-rclone-upload.timer     active
```

VPS201、VPS228 应满足：

```text
usgiftcardhub-replica-apply.timer     active/enabled
tls-shunt-proxy.service               active/enabled
usgiftcardhub.service                 inactive/disabled
usgiftcardhub-worker.service          inactive/disabled
redis-server.service                  inactive/disabled
```

温备的 443 端口可以由 `tls-shunt-proxy` 监听，但在正式接管前，USGiftCardHub 的本地 API 和 Worker 不运行。

## 3. 日常只读检查

在本地执行：

```bash
ssh vps200 '
  systemctl list-timers --all --no-pager \
    usgiftcardhub-snapshot.timer \
    usgiftcardhub-archive.timer \
    usgiftcardhub-rclone-upload.timer
  printf "ready="
  cat /var/lib/usgiftcardhub-replica/current/READY
  systemctl is-active \
    usgiftcardhub.service \
    usgiftcardhub-worker.service \
    redis-server.service
'

ssh vps201 '
  printf "applied="
  cat /var/lib/usgiftcardhub-replica/applied-snapshot
  systemctl is-active \
    usgiftcardhub-replica-apply.timer \
    tls-shunt-proxy.service \
    usgiftcardhub.service \
    usgiftcardhub-worker.service \
    redis-server.service || true
'

ssh vps228 '
  printf "applied="
  cat /var/lib/usgiftcardhub-replica/applied-snapshot
  systemctl is-active \
    usgiftcardhub-replica-apply.timer \
    tls-shunt-proxy.service \
    usgiftcardhub.service \
    usgiftcardhub-worker.service \
    redis-server.service || true
'
```

验收标准：

- 主站 `READY` 与至少一台温备的 `applied-snapshot` 一致；正常情况下两台都应追平。
- 温备最近一次 `usgiftcardhub-replica-apply.service` 日志包含 `database_check=ok`。
- 温备 API、Worker、Redis 保持停止。
- 主站 API、Worker、Redis 正常运行。

温备应用 timer 与主站快照 timer 不同相位，刚生成快照时可能短暂落后。确认 `incoming/READY` 已更新后，最多等待一个温备应用周期再判断失败：

```bash
ssh vps201 'cat /var/lib/usghsync/incoming/READY; systemctl list-timers --all --no-pager usgiftcardhub-replica-apply.timer'
ssh vps228 'cat /var/lib/usghsync/incoming/READY; systemctl list-timers --all --no-pager usgiftcardhub-replica-apply.timer'
```

## 4. 故障接管决策

只有满足以下任一条件才进入正式接管：

- VPS200 无法访问，且已确认不是本地网络或 Cloudflare 单点故障。
- VPS200 可以访问，但已人工停止 API、Worker 和 Redis，确认不再接受写入。
- 已明确决定将 VPS201 或 VPS228 提升为唯一写节点。

禁止以下操作：

- VPS200 仍在处理订单时执行 `--confirm-primary-down`。
- 同时在 VPS201、VPS228 执行正式接管。
- 先改 Cloudflare DNS，再启动和验证温备。
- 仅凭进程启动成功就宣布接管完成。

## 5. 接管前检查

### 5.1 判断主站是否仍在写入

如果 VPS200 仍可 SSH，检查：

```bash
ssh vps200 '
  systemctl is-active \
    usgiftcardhub.service \
    usgiftcardhub-worker.service \
    redis-server.service
  curl --fail --silent --show-error --max-time 5 \
    http://127.0.0.1:8080/health
'
```

如果这是计划切换，先在 Cloudflare 或业务层阻止新写入，再停止会改变业务状态的 Worker 和 API；Redis 暂时保持运行：

```bash
ssh vps200 '
  sudo systemctl stop usgiftcardhub-worker.service usgiftcardhub.service
  sudo /usr/local/sbin/usgiftcardhub-primary-snapshot --snapshot --push
  sudo systemctl stop redis-server.service
'
```

这会在停止写入后再生成并推送最后一份 SQLite/Redis 快照。等待选定温备应用该快照后，再确认 VPS200 的 API、Worker、Redis 均为 `inactive`。如果 VPS200 完全失联，必须把“主站确实无法继续处理写入”作为人工确认条件记录下来。

### 5.2 选择温备

优先选择 `applied-snapshot` 最新、数据库检查成功、磁盘和服务状态正常的一台：

```bash
ssh vps201 '
  cat /var/lib/usgiftcardhub-replica/applied-snapshot
  journalctl -u usgiftcardhub-replica-apply.service -n 20 --no-pager
  df -h /
'

ssh vps228 '
  cat /var/lib/usgiftcardhub-replica/applied-snapshot
  journalctl -u usgiftcardhub-replica-apply.service -n 20 --no-pager
  df -h /
'
```

还应确认接管脚本和关键材料存在：

```bash
ssh vps201 '
  test -x /usr/local/sbin/usgiftcardhub-failover-activate
  test -s /opt/usgiftcardhub/config.yml
  test -s /opt/usgiftcardhub/db/dujiao.db
  test -s /var/lib/redis/dump.rdb
  bash -n /usr/local/sbin/usgiftcardhub-failover-activate
'
```

将 `vps201` 替换为 `vps228` 可检查另一台。

## 6. 正式接管

以下示例选择 VPS201。只执行其中一台：

```bash
ssh vps201
sudo /usr/local/sbin/usgiftcardhub-failover-activate --confirm-primary-down
```

如果选择 VPS228：

```bash
ssh vps228
sudo /usr/local/sbin/usgiftcardhub-failover-activate --confirm-primary-down
```

脚本会按顺序执行：

1. 停止副本应用 timer，冻结接管快照。
2. 备份现有 `tls-shunt-proxy` 配置。
3. 启动 Redis 和 API。
4. 验证 `http://127.0.0.1:8080/health`。
5. 加载 `usgiftcardhub.com` TLS 路由并重启 `tls-shunt-proxy`。
6. 使用 `--resolve` 验证本机 HTTPS。
7. 启动 Worker。
8. 写入 `/etc/usgiftcardhub-failover-active` 单写标记。

只有看到以下结果才允许继续改 DNS：

```text
failover_status=active
snapshot_id=<快照编号>
public_ip=<备用机 IP>
```

如果脚本任一步失败，会恢复 TLS 配置并停止刚启动的业务服务。此时不要修改 DNS。

## 7. 接管后本机验收

仍在已接管温备上执行：

```bash
systemctl is-active \
  redis-server.service \
  usgiftcardhub.service \
  usgiftcardhub-worker.service \
  tls-shunt-proxy.service

systemctl is-active usgiftcardhub-replica-apply.timer || true

curl --fail --silent --show-error --max-time 5 \
  http://127.0.0.1:8080/health

curl --fail --silent --show-error --max-time 5 \
  --noproxy '*' \
  --resolve usgiftcardhub.com:443:127.0.0.1 \
  https://usgiftcardhub.com/health

cat /etc/usgiftcardhub-failover-active
```

期望：

- Redis、API、Worker、TLS 代理均为 `active`。
- 副本应用 timer 已停止。
- HTTP 和本机 HTTPS 均返回健康结果。
- active marker 中的快照编号与接管时选择的快照一致。

## 8. Cloudflare DNS 切换

在 Cloudflare 的 `usgiftcardhub.com` Zone 中：

1. 找到根域名 `usgiftcardhub.com` 的 A 记录。
2. 将内容改为已接管温备的公网 IP：
   - VPS201：`38.110.228.201`
   - VPS228：`154.29.74.228`
3. 保持原有 Proxy 状态不变；原来是橙云就继续使用橙云。
4. 检查是否存在根域 AAAA 记录。如果它仍指向旧源站，应同步处理，避免 IPv6 流量绕过新 A 记录。
5. 不要修改 MX、邮件路由、TXT、CAA 或其他无关记录。

只有第 7 节本机验收全部通过后才能执行 DNS 切换。

## 9. 公网验收

从不在备用机上的终端执行：

```bash
curl --fail --silent --show-error --max-time 10 \
  https://usgiftcardhub.com/health

curl --head --fail --silent --show-error --max-time 10 \
  https://usgiftcardhub.com/
```

随后人工验证：

- 首页能正常加载，静态资源没有 404/5xx。
- 管理后台可以登录。
- 商品和卡密库存显示符合接管快照。
- Worker 日志无持续报错。
- Stripe webhook、邮件和订单流程没有异常积压。

未经单独授权，不要为了验收创建真实支付、重复发送邮件或重新投递含卡密的历史任务。

查看接管后的日志：

```bash
journalctl -u usgiftcardhub.service -n 100 --no-pager
journalctl -u usgiftcardhub-worker.service -n 100 --no-pager
journalctl -u redis-server.service -n 50 --no-pager
journalctl -u tls-shunt-proxy.service -n 50 --no-pager
```

## 10. 接管失败处理

### 10.1 DNS 尚未修改

如果接管脚本失败，不做 DNS 修改。脚本会自动停止温备业务服务并恢复 TLS 配置。检查日志和状态后重新决定，不要绕过失败检查手工启动 Worker。

### 10.2 DNS 已修改但公网验收失败

先判断问题在 Cloudflare、TLS 还是应用。不要同时启动另一台温备或恢复 VPS200 写入。

如果需要放弃当前温备，必须先确定新的唯一写节点和流量切换顺序。避免在 DNS 尚可能访问当前温备时，同时启动另一台的 Worker。

## 11. 撤回温备接管

只有确认业务流量和最新数据已经安全迁移到新的唯一主站后，才能在原接管温备执行：

```bash
sudo /usr/local/sbin/usgiftcardhub-failover-deactivate
```

脚本会：

- 停止并禁用 API、Worker、Redis。
- 删除临时 USGiftCardHub TLS 路由。
- 恢复副本应用 timer。
- 保留温备数据。

### 重要：回切 VPS200 不是 DNS 反向修改

当前自动同步方向只有 VPS200 → VPS201/VPS228。温备正式接管后产生的新订单、支付、卡密变化和 Redis 队列不会自动回传 VPS200。

因此回切前必须：

1. 阻止温备继续接受新写入。
2. 停止温备 Worker 和 API。
3. 从当前温备生成一致性 SQLite、Redis 和 uploads 快照。
4. 将该快照受控恢复到 VPS200，并执行数据库、队列、配置和文件校验。
5. 在 VPS200 本机验证 HTTP/HTTPS 和 Worker。
6. 保证温备仍停止后，才将 Cloudflare 指回 VPS200。
7. 公网验收完成后，再执行温备撤回脚本。

反向数据回迁当前没有一键自动化脚本，应作为单独的计划变更执行，不能临时猜测命令。

## 12. 主站在线时的隔离演练

主站仍在线时只能使用 `--test-only`：

```bash
ssh vps201
sudo /usr/local/sbin/usgiftcardhub-failover-activate --test-only
```

或在 VPS228 执行同一命令。

演练会临时启动 Redis/API、加载 TLS 并验证本机 HTTPS；Worker 永不启动，结束后自动恢复温备状态。期望输出：

```text
failover_test=passed
worker_started=no
standby_services=stopped
```

演练后必须再次检查 API、Worker、Redis 均为 `inactive`，副本应用 timer 为 `active`。

## 13. 从 Google Drive 归档重建温备

当两台温备都不可用时，从 VPS200 实际使用的 Google Drive 备份目录取得同一快照编号的三个文件：

```text
usgiftcardhub-full-YYYYMMDDTHHMMSSZ.tar.gz.enc
usgiftcardhub-full-YYYYMMDDTHHMMSSZ.tar.gz.enc.sha256
usgiftcardhub-full-YYYYMMDDTHHMMSSZ.tar.gz.enc.manifest
```

备份密钥不在 Drive 中，必须使用单独保管、权限为 `0600` 的密钥文件。将归档和校验文件放到目标机后执行：

```bash
sudo /usr/local/sbin/usgiftcardhub-restore-encrypted-archive \
  /path/usgiftcardhub-full-YYYYMMDDTHHMMSSZ.tar.gz.enc \
  /path/usgiftcardhub-full-YYYYMMDDTHHMMSSZ.tar.gz.enc.sha256 \
  /root/.config/usgiftcardhub-backup/backup.key
```

恢复脚本会校验整包 SHA-256、拒绝危险归档路径、解密、校验内部文件并应用为停止状态的温备。恢复完成后仍须执行第 5 至第 9 节，不能直接改 DNS。

## 14. 故障记录模板

每次正式接管至少记录：

```text
故障开始时间：
主站最后确认状态：
选择的温备：
主站 READY：
温备 applied-snapshot：
接管命令开始/结束时间：
failover_status：
Cloudflare 修改时间：
公网 /health 验证结果：
后台登录验证结果：
Worker/Redis 验证结果：
已知数据时间窗口：
回切负责人和计划：
```

不要在故障记录中粘贴数据库、卡密、OAuth token、Stripe 密钥、SMTP 密码或备份密钥。

## 15. 2026-08-27 验证基线

本手册编写时已只读确认：

- VPS201、VPS228 可以接收并应用同一最新快照。
- 两台 SQLite `PRAGMA quick_check` 均为 `ok`。
- 两台均有 Redis RDB、应用配置、接管脚本和有效的 `usgiftcardhub.com` TLS 证书。
- 两台的 `tls-shunt-proxy` 和副本应用 timer 正常运行。
- 两台 API、Worker、Redis 按温备要求保持停止。

这份基线会随时间失效。实际接管必须重新执行本文的实时检查，不能只引用历史结论。
