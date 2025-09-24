# kt-tools

一个整合式的内网资源中心，结合了 **kt-share** 的文件服务体验与 **mac---** 的 Mac 软件批量部署能力，为新机器提供"一键安装 + 自动缓存更新"的完整解决方案。

## ✨ 功能特性

- **可视化资源中心**：Node.js 服务提供美观的首页、工具列表及文件浏览
- **Mac 一键部署**：`public/installers/quick_install.sh` + `mac_m4_installer.sh` 复用原批量安装流程
- **缓存自动更新**：`scripts/update_cache.sh` 定时同步 13 款常用软件到本地缓存目录
- **HTTP 直接分发**：所有脚本、安装包与日志通过统一端口对外发布，便于局域网共享
- **API 辅助**：可选的 `/api/update-cache` 接口，配合 `UPDATE_SECRET` 实现手动触发刷新

## 🏗️ 技术架构

### 核心组件
- **后端**: Node.js HTTP 服务器 (`server/file_server.js`)
- **前端**: 静态 HTML 页面 + CSS 样式
- **安装脚本**: Bash 脚本用于自动化软件安装
- **缓存系统**: 自动更新 13 款常用软件到本地缓存

### 支持的软件包
- ChatGPT、Telegram、Google Chrome、Docker Desktop
- WeChat、Wave Terminal、Trae、Qoder
- Clash Verge、Visual Studio Code、WPS Office
- Git、Homebrew、Node.js、Traefik

## 📁 目录结构

```
kt-tools/
├── server/                        # Node.js 服务端代码
│   └── file_server.js            # 主入口 (默认端口 8000)
├── public/                        # 静态页面与可下载脚本
│   ├── index.html                # 资源中心首页
│   ├── tools.html                # 常用工具说明
│   ├── other.html                # 资源浏览入口
│   ├── download.html             # 其他下载页
│   ├── assets/                   # 页面使用到的图片等资源
│   └── installers/               # Mac 端一键脚本
│       ├── quick_install.sh      # 快速启动脚本
│       └── mac_m4_installer.sh   # 主安装脚本
├── scripts/                       # 服务器端脚本
│   ├── setup.sh                  # 初始化配置助手
│   ├── update_cache.sh           # 自动拉取/更新 Mac 软件包
│   └── node/update_picgo.js      # 其他辅助脚本
├── resources/                     # 资源存储目录
│   ├── software-cache/macos-arm/ # 软件缓存目录（由 update_cache.sh 维护）
│   └── logs/                     # 更新日志等输出
├── package.json                   # 项目配置
└── README.md
```

> 注意：`resources/software-cache/macos-arm/` 中的安装包默认被 `.gitignore` 忽略，请直接在服务器上维护。

## 🚀 部署指南

### 环境要求

- **操作系统**: macOS/Linux
- **Node.js**: 无需额外安装 (使用系统内置模块)
- **Python 3**: 用于配置脚本
- **网络**: 需要互联网连接下载软件包
- **存储空间**: 建议预留 5-10GB 用于软件缓存

### 快速部署

#### 1. 准备项目文件
```bash
cd kt-tools
```

#### 2. 运行配置助手
```bash
bash scripts/setup.sh
```

配置脚本将执行以下操作：
- 自动检测服务器IP地址
- 创建必要目录结构
- 设置脚本执行权限
- 更新安装脚本中的服务器IP和端口配置
- 可选配置 cron 自动更新任务
- 可选立即执行缓存更新

#### 3. 启动服务
```bash
# 方式一：使用 npm
npm start

# 方式二：直接运行
node server/file_server.js

# 方式三：自定义端口和密钥
PORT=9000 UPDATE_SECRET=your-secret-key node server/file_server.js
```

#### 4. 验证部署
```bash
# 检查服务状态
curl -I http://localhost:8000

# 访问主页
curl http://localhost:8000
```

### 高级配置

#### 环境变量
- `PORT`: 服务端口 (默认: 8000)
- `UPDATE_SECRET`: API更新接口密钥 (可选)

#### 系统服务 (可选)

##### systemd (Linux)
创建 `/etc/systemd/system/kt-tools.service`:
```ini
[Unit]
Description=kt-tools File Server
After=network.target

[Service]
Type=simple
User=your-user
WorkingDirectory=/path/to/kt-tools
ExecStart=/usr/bin/node server/file_server.js
Restart=always
Environment=PORT=8000
Environment=UPDATE_SECRET=your-secret-key

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable kt-tools
sudo systemctl start kt-tools
```

##### launchd (macOS)
创建 `~/Library/LaunchAgents/com.kt-tools.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.kt-tools</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/node</string>
        <string>/path/to/kt-tools/server/file_server.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/path/to/kt-tools</string>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.kt-tools.plist
```

## 🔧 使用说明

### 服务访问

- **主页**: `http://服务器IP:8000`
- **软件包浏览**: `http://服务器IP:8000/packages`
- **工具页面**: `http://服务器IP:8000/tools`
- **资源页面**: `http://服务器IP:8000/other`
- **下载页面**: `http://服务器IP:8000/download`

### Mac 客户端安装

在目标 Mac 设备上执行：
```bash
curl -fsSL http://服务器IP:8000/installers/quick_install.sh | bash
```

### 缓存管理

#### 手动更新缓存
```bash
bash scripts/update_cache.sh
```

#### API 触发更新
需要先设置 `UPDATE_SECRET` 环境变量：
```bash
curl "http://服务器IP:8000/api/update-cache?token=your-secret-key"
```

#### 查看更新日志
```bash
# Web 方式
curl "http://服务器IP:8000/logs/update"

# 直接查看文件
tail -f resources/logs/update.log
```

#### 自动更新任务
setup.sh 脚本可配置 cron 任务：
```bash
# 每月1日和16日凌晨3点自动更新
0 3 1,16 * * bash /path/to/scripts/update_cache.sh >> /path/to/resources/logs/cron.log 2>&1
```

## 🧪 测试验证

### 基础功能测试

```bash
# 1. 服务启动测试
node server/file_server.js &
curl -I http://localhost:8000
# 期望返回: HTTP/1.1 200 OK

# 2. 路由测试
curl http://localhost:8000                           # 主页
curl http://localhost:8000/packages                  # 软件包目录
curl http://localhost:8000/installers/quick_install.sh  # 安装脚本

# 3. 静态资源测试
curl http://localhost:8000/tools                     # 工具页面
curl http://localhost:8000/other                     # 资源页面
```

### 缓存系统测试

```bash
# 1. 缓存更新测试
bash scripts/update_cache.sh

# 2. 检查缓存目录
ls -la resources/software-cache/macos-arm/

# 3. 验证软件包大小
for file in resources/software-cache/macos-arm/*; do
    if [ -f "$file" ]; then
        echo "$(basename "$file"): $(du -h "$file" | cut -f1)"
    fi
done

# 4. 查看更新日志
cat resources/logs/update.log
```

### Mac 安装测试

在 Mac 设备上测试：
```bash
# 测试快速安装脚本
curl -fsSL http://服务器IP:8000/installers/quick_install.sh | bash

# 检查安装日志
tail -f /tmp/mac_m4_install.log
```

### API 接口测试

```bash
# 设置测试环境
export UPDATE_SECRET="test-secret"
PORT=8000 UPDATE_SECRET=$UPDATE_SECRET node server/file_server.js &

# 测试更新接口
curl -X GET "http://localhost:8000/api/update-cache?token=test-secret"

# 测试错误处理
curl -X GET "http://localhost:8000/api/update-cache?token=wrong-token"
# 期望返回: 401 Unauthorized
```

### 性能测试

```bash
# 并发访问测试 (需安装 apache2-utils)
ab -n 100 -c 10 http://localhost:8000/

# 大文件下载测试
time curl -O http://localhost:8000/packages/Docker_M.dmg
```

## 🔒 安全最佳实践

### 1. 网络安全
- 在生产环境中限制服务器访问 IP 范围
- 使用防火墙规则限制端口访问
- 考虑使用 HTTPS (需要反向代理如 nginx)

### 2. 认证授权
```bash
# 设置更新API密钥
export UPDATE_SECRET=$(openssl rand -hex 32)
```

### 3. 文件权限
```bash
# 设置适当的文件权限
chmod 755 scripts/*.sh
chmod 644 public/*.html
chmod 755 resources/software-cache/macos-arm
```

### 4. 日志监控
```bash
# 监控更新日志异常
grep -i "error\|failed" resources/logs/update.log

# 设置日志轮转 (logrotate)
sudo tee /etc/logrotate.d/kt-tools << EOF
/path/to/kt-tools/resources/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    notifempty
    copytruncate
}
EOF
```

## 🛠️ 故障排除

### 常见问题

#### 1. 服务启动失败
```bash
# 检查端口占用
lsof -i :8000

# 检查 Node.js 版本
node --version
```

#### 2. 缓存更新失败
```bash
# 检查网络连接
ping -c 1 8.8.8.8

# 检查磁盘空间
df -h resources/software-cache/macos-arm/

# 查看详细错误日志
tail -n 50 resources/logs/update.log
```

#### 3. Mac 安装脚本执行失败
```bash
# 检查服务器连接
ping -c 1 服务器IP

# 验证脚本下载
curl -I http://服务器IP:8000/installers/quick_install.sh

# 查看安装日志
cat /tmp/mac_m4_install.log
```

### 调试模式
```bash
# 启用详细日志
DEBUG=* node server/file_server.js

# 测试缓存更新脚本
bash -x scripts/update_cache.sh
```

## 🔄 与旧仓库的对应关系

| 旧仓库 | 现位置 | 说明 |
|--------|--------|------|
| `kt-share` 静态页面 + Node 服务 | `public/` 与 `server/file_server.js` | 保留原 UI，重构服务以适配新目录 |
| `mac---` 的安装脚本 | `public/installers/`、`scripts/` | 路径与 BASE_URL 统一指向 `/packages` |
| 软件缓存 | `resources/software-cache/macos-arm/` | 可由 `update_cache.sh` 自动填充 |

## 📈 性能优化

### 1. 缓存优化
```bash
# 清理过期缓存文件
find resources/software-cache/macos-arm/ -name "*.backup.*" -mtime +7 -delete

# 压缩日志文件
gzip resources/logs/*.log
```

### 2. 网络优化
- 使用 CDN 加速静态资源
- 配置适当的 HTTP 缓存头
- 考虑使用 nginx 作为反向代理

### 3. 系统资源监控
```bash
# 监控服务资源使用
ps aux | grep node
netstat -tulpn | grep :8000
```

## 🔮 扩展功能

### 计划中的优化

- **权限验证**: 引入 Basic Auth 或 JWT 认证
- **监控系统**: 集成 Prometheus + Grafana 监控
- **版本管理**: 添加软件版本比较和回滚功能
- **UI增强**: 添加缓存状态展示和手动触发界面
- **多平台支持**: 扩展对 Intel Mac 和 Linux 的支持

### 自定义扩展

#### 添加新软件包
编辑 `scripts/update_cache.sh`，添加新的更新规则：
```bash
# 添加新软件示例
update_software "New App" "https://example.com/app.dmg" "NewApp_M.dmg" 50000000
```

#### 自定义页面
在 `public/` 目录下添加新的 HTML 页面，服务器会自动提供访问。

## 📝 开发指南

### 代码结构
```
server/file_server.js      # 主服务器逻辑
├── mimeTypes             # MIME 类型映射
├── serveFile()           # 文件服务处理
├── handlePackages()      # 软件包目录处理
├── handleUpdateTrigger() # API 更新触发
└── generateDirectoryListing()  # 目录列表生成
```

### 开发环境
```bash
# 开发模式启动 (启用调试日志)
NODE_ENV=development node server/file_server.js

# 代码格式化 (如果使用 prettier)
npx prettier --write server/*.js
```

## 📄 许可证

MIT License - 详见 LICENSE 文件

## 🤝 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📞 支持与反馈

- 问题反馈: 请创建 GitHub Issue
- 功能建议: 欢迎通过 Pull Request 贡献
- 文档改进: 帮助完善使用文档

---

欢迎根据自身需求继续扩展。若迁移自旧仓库，只需停止旧服务并启动 `kt-tools` 即可实现一体化运维。