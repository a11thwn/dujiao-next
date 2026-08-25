# USGiftCardHub 容灾与备份

## 当前拓扑

- 主站：VPS200，API、Worker、Redis 为唯一运行写节点。
- 温备：VPS201、VPS228，保存完整应用、SQLite、Redis、配置、systemd 与 TLS 恢复材料。
- 三台服务器已加入同一 Tailscale 网络；VPS200 通过 Tailscale IP 向两台温备执行 rsync，公网 SSH 仅作为人工应急入口。
- 异地归档：通过 VPS200 rclone 的 `gdbaby:USGiftCardHub Backups` 上传，只保存 AES-256-CBC 加密归档及校验文件。
- 备份密钥不进入仓库或 Google Drive；主站、两台温备和本机各保存一份，权限为 `0600`。
- rclone 配置从现有受控运维节点复制到 VPS200 后保持 `0600`；账号信息与 OAuth token 不进入日志或仓库。

## 自动任务

- VPS200 的 `usgiftcardhub-snapshot.timer` 每 15 分钟生成一致性 SQLite/Redis 快照并增量推送到两台温备。
- VPS201、VPS228 的 `usgiftcardhub-replica-apply.timer` 每 5 分钟校验并应用完整快照。
- VPS200 的 `usgiftcardhub-archive.timer` 每天 19:10 UTC（北京时间次日 03:10）生成加密完整归档，随后用 rclone 上传 Google Drive；服务器保留 14 天。
- rclone 上传完成后执行 Drive 端哈希/大小核验；上传失败会令 systemd 任务失败并保留本地归档供下次重试。
- `usgiftcardhub-rclone-upload.timer` 每小时幂等重试最新归档，缓解 rclone 公共 OAuth client 的 Google Drive API 分钟级配额拥塞。

副本同步地址保存在主站权限为 `0600` 的目标文件中，不提交具体 Tailscale IP。Tailscale 节点不接受 tailnet DNS 或子网路由，也不启用 Tailscale SSH；原有公网、Cloudflare 和 `tls-shunt-proxy` 路径不变。

正常 standby 状态必须满足：

```text
usgiftcardhub.service         inactive/disabled
usgiftcardhub-worker.service  inactive/disabled
redis-server.service          inactive/disabled
tls-shunt-proxy.service       active/enabled
usgiftcardhub-replica-apply.timer active/enabled
```

## 快照内容

- `/opt/usgiftcardhub/usgiftcardhub-api`
- `/opt/usgiftcardhub/usgiftcardhub`
- `/opt/usgiftcardhub/config.yml`
- SQLite 在线备份与 `uploads/`
- Redis RDB 与 Redis 配置
- API/Worker systemd 单元及 drop-in
- `usgiftcardhub.com` TLS 证书缓存与 ACME 账户材料
- `MANIFEST`、`SHA256SUMS`、`READY`

生产历史日志和旧的部署备份不属于接管必需数据，不进入每 15 分钟快照。

## 接管

先确认 VPS200 已停止写入，避免双主造成重复发信、重复队列消费或订单状态分叉。选择一台温备执行：

```bash
ssh vps201
sudo /usr/local/sbin/usgiftcardhub-failover-activate --confirm-primary-down
```

或：

```bash
ssh vps228
sudo /usr/local/sbin/usgiftcardhub-failover-activate --confirm-primary-down
```

脚本会停止副本应用定时器，启动 Redis/API，加载 `usgiftcardhub.com` TLS vhost，验证本机 HTTPS，再启动 Worker。成功后将 Cloudflare 的 `usgiftcardhub.com` A 记录切换到脚本输出的备用机公网 IP。

当前备用 IP：

- VPS201：`38.110.228.201`
- VPS228：`154.29.74.228`

## 撤回接管

确认流量和写入已迁回主站后，在备用机执行：

```bash
sudo /usr/local/sbin/usgiftcardhub-failover-deactivate
```

脚本停止 API/Worker/Redis，移除临时 vhost，恢复副本应用定时器，不删除备用数据。

## 隔离演练

主站在线时只能使用演练模式，禁止执行正式接管：

```bash
sudo /usr/local/sbin/usgiftcardhub-failover-activate --test-only
```

演练只临时启动 Redis/API、加载 TLS 并验证本机 HTTPS；Worker 永不启动，结束后恢复 standby 状态。

## 从 Google Drive 归档恢复

将 `.tar.gz.enc`、对应 `.sha256` 和备份密钥放到目标机。安装 Redis、部署本目录脚本并创建 `usghsync` 后执行：

```bash
sudo /usr/local/sbin/usgiftcardhub-restore-encrypted-archive \
  /path/usgiftcardhub-full-YYYYMMDDTHHMMSSZ.tar.gz.enc \
  /path/usgiftcardhub-full-YYYYMMDDTHHMMSSZ.tar.gz.enc.sha256 \
  /root/.config/usgiftcardhub-backup/backup.key
```

恢复脚本会校验整包 SHA-256、拒绝危险归档路径、解密、校验内部文件并应用为停止状态的温备。完成后仍需使用正式接管命令启动。

## 日常核验

```bash
systemctl list-timers usgiftcardhub-snapshot.timer usgiftcardhub-archive.timer usgiftcardhub-rclone-upload.timer
cat /var/lib/usgiftcardhub-replica/current/READY

ssh vps201 'cat /var/lib/usgiftcardhub-replica/applied-snapshot; systemctl is-active usgiftcardhub.service usgiftcardhub-worker.service redis-server.service'
ssh vps228 'cat /var/lib/usgiftcardhub-replica/applied-snapshot; systemctl is-active usgiftcardhub.service usgiftcardhub-worker.service redis-server.service'
```

只有主站 `READY` 与两台温备 `applied-snapshot` 一致、数据库检查通过且备用服务停止，才能报告副本可用。
