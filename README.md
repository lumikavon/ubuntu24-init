# code-server HTTPS 配置指南

本文说明如何为 code-server 配置 TLS 证书并启用 HTTPS 访问，适用于 systemd 安装方式（service 名称形如 `code-server@<username>`）。

## 关键路径
- 配置文件：`~/.config/code-server/config.yaml`（root 运行时在 `/root/.config/code-server/config.yaml`）
- 服务管理：`sudo systemctl restart code-server@<username>`
- 证书保存位置：建议放在 `/etc/code-server/ssl/`（需确保只有当前用户或 root 可读）

## 使用自签名证书
1. 创建目录：`sudo mkdir -p /etc/code-server/ssl && sudo chmod 700 /etc/code-server/ssl`
2. 生成证书（用你的域名替换 `your.domain.com`）：
   ```bash
   sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout /etc/code-server/ssl/code-server.key \
     -out /etc/code-server/ssl/code-server.crt \
     -subj "/CN=your.domain.com"
   sudo chmod 600 /etc/code-server/ssl/code-server.key
   ```
3. 在配置文件中启用证书（如下节所示），重启服务后通过 `https://your.domain.com:8080` 访问，并在浏览器接受自签名证书（或导入信任）。

## 使用受信任的证书
- 如果有 CA 颁发的证书（例如从 ACME/Let’s Encrypt 获取的 `fullchain.pem` 和 `privkey.pem`），将其复制到 `/etc/code-server/ssl/`：
  ```bash
  sudo cp /path/to/fullchain.pem /etc/code-server/ssl/code-server.crt
  sudo cp /path/to/privkey.pem /etc/code-server/ssl/code-server.key
  sudo chmod 600 /etc/code-server/ssl/code-server.key
  ```
- 确保证书包含完整链（`fullchain.pem`），否则部分客户端可能不信任。

## 修改 config.yaml
在 `~/.config/code-server/config.yaml` 中添加或修改以下字段（`password` 按需保留或调整）：
```yaml
bind-addr: 0.0.0.0:8080      # 监听地址与端口
auth: password               # 或 none / custom
password: "<your-strong-password>"
cert: /etc/code-server/ssl/code-server.crt
cert-key: /etc/code-server/ssl/code-server.key
```
说明：
- `cert` 和 `cert-key` 支持指向自签或受信任的证书文件。
- 如果只写 `cert: true`，code-server 会为当前主机名生成临时自签证书；不推荐生产使用。
- 端口可改为 443，但需 root 绑定低端口（或使用 setcap/Nginx 反代）。

## 应用配置
```bash
sudo systemctl restart code-server@$(whoami)
# 或指定用户：sudo systemctl restart code-server@youruser
sudo systemctl status code-server@$(whoami)
```

## 测试与排查
- 浏览器访问 `https://your.domain.com:8080`，确认证书链有效。
- 若无法访问，检查防火墙与安全组放行对应端口。
- 查看日志：`journalctl -u code-server@$(whoami) -e`
- 确认证书权限：私钥应为 `600`，目录 `700`，否则 code-server 可能拒绝读取。

## 反向代理可选方案
如果需要 80/443 端口或多站点共存，建议在前面放置 Nginx/Caddy/Traefik，后端 code-server 监听本地端口（如 127.0.0.1:8080），代理层负责 TLS 终止与证书自动续期。

## Claude Code 安装（可选）
仓库内置了一键安装入口，可通过 `install.sh` 安装官方包 `@anthropic-ai/claude-code`，并可选执行环境变量配置脚本。

```bash
# 交互式安装（会提示输入 API Key；留空则跳过配置）
./install.sh claudecode

# 非交互安装（推荐在 CI/自动化中使用）
CLAUDECODE_API_KEY="你的API_KEY" ./install.sh claudecode

# 或者显式传参
./install.sh claudecode --api-key "你的API_KEY"

# 验证
claude -v
```
