# 3X-UI 面板 v5.1

## 项目介绍

3X-UI 是一个支持多协议多用户的 xray 面板，支持系统状态监控、流量统计、定时重启、邀请注册、节点订阅等功能。

本版本（v5.1）是基于原版 x-ui 进行改进的增强版本，专为 Linux 系统和 Docker 环境设计，提供更简单的部署方式和更强大的功能。

## 功能特点

- 🔄 **支持多协议**：Vmess、Vless、Trojan、Shadowsocks、Wireguard 等
- 👥 **多用户管理**：支持多用户、多节点配置
- 📊 **流量统计**：详细的流量统计和图表展示
- 🔔 **系统监控**：CPU、内存、网络等系统状态监控
- ⏰ **定时任务**：支持定时重启面板、xray 核心
- 📱 **Telegram 集成**：支持 Telegram Bot 进行状态通知和远程管理
- 🌐 **伪装网站**：内置 80 端口伪装网站功能，提高安全性
- 🔐 **安全防护**：多重安全措施，防止恶意探测和攻击

## 系统要求

- 支持的操作系统：各类 Linux 发行版（Ubuntu、Debian、CentOS 等）
- 必要环境：Docker 和 Docker Compose
- 推荐配置：1 核 CPU、1GB 内存、10GB 存储空间

## 一键安装

我们提供了简单的一键安装脚本，只需执行以下命令：

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Li-yi-sen/21-zhuanfavpn/main/3x-ui/install.sh)
```

此命令将自动：
1. 检查并安装 Docker 和 Docker Compose（如果尚未安装）
2. 拉取最新的 3X-UI 镜像
3. 配置并启动服务
4. 设置开机自启动

整个安装过程无需人工干预，完成后会自动显示访问信息。

## Docker 手动安装

如果您希望手动安装，可以按照以下步骤操作：

1. 确保已安装 Docker 和 Docker Compose
```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 安装 Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```

2. 下载配置文件
```bash
mkdir -p 3x-ui && cd 3x-ui
curl -O https://raw.githubusercontent.com/Li-yi-sen/21-zhuanfavpn/main/3x-ui/docker-compose.yml
curl -O https://raw.githubusercontent.com/Li-yi-sen/21-zhuanfavpn/main/3x-ui/nginx.conf
mkdir -p wwwroot
```

3. 启动服务
```bash
docker-compose up -d
```

## 访问面板

安装完成后，可通过以下方式访问面板：

- 面板地址：`http://服务器IP:2053`
- 默认用户名：`admin`
- 默认密码：`admin`

**重要提示**：首次登录后请立即修改默认密码！

## 伪装网站

系统已自动配置 80 端口伪装网站，访问 `http://服务器IP` 将显示一个云服务提供商网站，有效提高安全性。

## 常见问题

1. **面板无法访问？**
   - 检查防火墙是否开放 2053 端口
   - 确认服务是否正常运行：`docker ps`

2. **流量统计不准确？**
   - 可能是时区设置问题，请在面板设置中调整时区

3. **如何更新？**
   - 执行 `cd 3x-ui && docker-compose pull && docker-compose up -d`

4. **如何备份数据？**
   - 所有数据存储在 `3x-ui/db` 目录，备份此目录即可

## 联系与支持

如有问题或建议，请通过以下方式联系我们：

- GitHub Issues: [https://github.com/Li-yi-sen/21-zhuanfavpn/issues](https://github.com/Li-yi-sen/21-zhuanfavpn/issues)
- Telegram 群组: [https://t.me/3xui_support](https://t.me/3xui_support)

## 许可证

本项目采用 GPL-3.0 开源许可证，详情请参阅 LICENSE 文件。
