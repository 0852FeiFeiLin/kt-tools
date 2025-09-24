# Repository Guidelines

## 项目结构与模块划分
`kt-share/` 存放 Node.js 静态文件服务端 (`file_server.js`) 以及页面入口 (`index.html`, `tools.html`, `other.html`, `download.html`)；页面专用脚本与图片请放在同级目录，路径命名采用短横线形式确保 URL 易读。体积较大的安装包归档到 `kt-share/resources/`，其中 PicGo 安装包会在 `resources/picGo/` 下轮换备份；追加新版本时保留旧文件到 `bak/` 目录。Apple Silicon 部署脚本集中在 `mac---/`，涵盖 `quick_install.sh`、`mac_m4_installer.sh`、`setup.sh`、`update_cache.sh` 等安装与分发工具。新增自动化脚本请放在对应目录并在开头注释列出必要环境变量与依赖命令。

## 构建、测试与开发命令
- `node file_server.js`：在 3100 端口启动静态服务器，修改路由或 MIME 表后需重启；建议使用 Node.js LTS ≥18，可通过 `node -v` 检查，或借助 `nvm use 18` 切换版本。
- `node scripts/update_picgo.js`：抓取最新 PicGo DMG，运行后请比对日志确认下载 URL 与保存路径；线上部署时将命令写入 cron（如 `30 3 * * *`）。
- `bash mac---/setup.sh`：在分发主机初始化缓存目录、权限与可选的定时任务，脚本会提示是否立即启动 Python HTTP 服务。
- `python3 -m http.server 8000 --bind 0.0.0.0`（于软件缓存目录执行）：快速验证下载链路或在局域网演示时的轻量替代方案。

## 代码风格与命名约定
JavaScript 采用两个空格缩进、单引号、分号结尾，工具函数使用 `camelCase`（例如 `formatSize`、`generateDirectoryListing`），常量保持 `UPPER_SNAKE_CASE`。Bash 脚本以 `#!/bin/bash` 开头并启用 `set -euo pipefail`（若新增脚本请补上），配置变量大写，复用函数使用 `snake_case`（如 `download_file`）。HTML 保持两空格缩进、属性小写，公共样式集中在页面 `<style>` 块中，避免内联 CSS；若需要共享样式，可引入统一的 `styles/` 目录。

## 测试指引
当前无自动化测试，请执行可重复的手动校验。修改网页或服务器后访问 `http://localhost:3100/` 以及 `/tools`、`/other`、`/files`，必要时使用 `curl -I http://localhost:3100/index.html` 观察 HTTP 头。调整 `update_picgo.js` 时运行一次，确认 `resources/picGo/` 新增安装包且旧版本进入 `bak/`。Bash 修改后先执行 `bash -n mac---/mac_m4_installer.sh` 与 `shellcheck mac---/mac_m4_installer.sh`（若已安装），再在预生产 Mac 上试跑并检视 `/tmp/mac_m4_install.log`。更新 `setup.sh` 或 `update_cache.sh` 时务必测试 `cron` 行为，可利用 `crontab -l` 验证配置，并在需要时配合 `launchctl`。

## 提交与合并请求规范
提交信息使用祈使句现在时（例如 `优化文件列表渲染`、`Add PicGo checksum check`），跨目录改动拆分成小而清晰的提交。合并请求需说明变更动机、列出手动验证步骤，并在界面或安装体验改动时附上截图或终端输出。引用任务时采用 `Refs #123`、`Fixes #123` 处理；涉及配置或端口调整时，在 PR 描述中写明需要同步的环境变量、cron 表达式与网络策略，以便维护者快速复现。

## 安全与配置提示
`file_server.js` 与 macOS 缓存目录均未提供认证或限流，请勿直接暴露在公网；若必须对外开放，请放置在受保护的内网并通过反向代理启用 basic auth、VPN 或 HTTPS offloading。上传日志前先脱敏 IP、Token、机器名等信息。调整端口或根目录时，请同时更新 `PORT`、`BASE_DIR`、`SERVER_IP` 等常量，并在 PR 中提醒运维检查防火墙、NAT 与 `launchd`/`cron` 配置，避免遗留旧端口。服务器上保存的安装包属于半信任环境，请定期校验 SHA256、执行 `codesign --verify`，必要时加上 `notarization` 报告。

## 架构概览
轻量级 Node.js 服务负责静态页面与文件列目录，macOS 自动化脚本负责把缓存内容推送到客户端。更新流程为：`update_picgo.js` 获取最新资源 → 管理员通过 `setup.sh` 或手工同步到缓存目录 → `file_server.js` 提供下载。若后续需要扩展 REST API，可考虑采用 Express.js + middleware，但必须先评估认证策略与速率限制，避免破坏当前的轻量模型。保持这三部分的版本记录一致，可以快速追踪故障来源并回滚。
