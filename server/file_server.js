#!/usr/bin/env node

const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');
const { spawn } = require('child_process');

const ROOT_DIR = path.join(__dirname, '..');
const PUBLIC_DIR = path.join(ROOT_DIR, 'public');
const INSTALLER_DIR = path.join(PUBLIC_DIR, 'installers');
const PACKAGE_DIR = path.join(ROOT_DIR, 'resources', 'software-cache', 'macos-arm');
const LOG_DIR = path.join(ROOT_DIR, 'resources', 'logs');
const UPDATE_SCRIPT = path.join(ROOT_DIR, 'scripts', 'update_cache.sh');
const UPDATE_SECRET = process.env.UPDATE_SECRET || null;
const PORT = Number(process.env.PORT || 8000);

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.wav': 'audio/wav',
  '.mp4': 'video/mp4',
  '.woff': 'application/font-woff',
  '.ttf': 'application/font-ttf',
  '.eot': 'application/vnd.ms-fontobject',
  '.otf': 'application/font-otf',
  '.wasm': 'application/wasm',
  '.pdf': 'application/pdf',
  '.doc': 'application/msword',
  '.zip': 'application/zip',
  '.dmg': 'application/octet-stream',
  '.pkg': 'application/octet-stream',
  '.tar': 'application/x-tar',
  '.gz': 'application/gzip',
  '.txt': 'text/plain; charset=utf-8',
  '.sh': 'text/plain; charset=utf-8'
};

const formatSize = (bytes) => {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} KB`;
  if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(1)} MB`;
  return `${(bytes / 1024 ** 3).toFixed(1)} GB`;
};

const readDirectorySafe = (dir) => {
  try {
    return fs.readdirSync(dir, { withFileTypes: true });
  } catch (err) {
    return [];
  }
};

const generateDirectoryListing = ({ title, urlPath, entries }) => {
  const items = entries
    .map(({ name, isDirectory, size }) => {
      const icon = isDirectory ? '📁' : '📄';
      const displaySize = isDirectory ? '' : `<span class="file-size">${formatSize(size)}</span>`;
      const href = `${urlPath.replace(/\/$/, '')}/${encodeURIComponent(name)}`.replace(/\/+/, '/');
      const iconClass = isDirectory ? 'folder-icon' : 'file-icon';
      return `
        <li class="file-item">
          <a href="${href}${isDirectory ? '/' : ''}">
            <div class="icon ${iconClass}">${icon}</div>
            <span class="file-name">${name}</span>
            ${displaySize}
          </a>
        </li>`;
    })
    .join('\n');

  return `<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${title}</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      min-height: 100vh; padding: 20px;
    }
    .container {
      max-width: 1000px; margin: 0 auto; background: white;
      border-radius: 12px; box-shadow: 0 20px 40px rgba(0,0,0,0.1);
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white; padding: 30px; word-break: break-all;
    }
    h1 { font-size: 24px; margin-bottom: 8px; }
    .path { font-size: 14px; opacity: 0.9; }
    ul { list-style: none; }
    .file-item {
      display: flex; align-items: center; padding: 15px 30px;
      border-bottom: 1px solid #f0f0f0; transition: all 0.3s ease;
    }
    .file-item:hover { background: #f8f9fa; transform: translateX(5px); }
    .file-item a {
      display: flex; align-items: center; width: 100%; text-decoration: none; color: #333;
    }
    .icon {
      width: 40px; height: 40px; margin-right: 15px;
      display: flex; align-items: center; justify-content: center;
      border-radius: 8px; font-size: 20px;
    }
    .folder-icon { background: #ffeaa7; }
    .file-icon { background: #74b9ff; }
    .file-name { flex: 1; }
    .file-size { color: #999; font-size: 14px; margin-left: 15px; }
    .actions { padding: 0 30px 20px; }
    .actions a { color: #667eea; text-decoration: none; margin-right: 15px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>${title}</h1>
      <div class="path">当前路径：${urlPath}</div>
    </div>
    <div class="actions">
      <a href="/">返回首页</a>
      <a href="/installers/quick_install.sh">下载一键安装脚本</a>
      <a href="/packages">查看所有安装包</a>
    </div>
    <ul>${items || '<li class="file-item">目录为空</li>'}</ul>
  </div>
</body>
</html>`;
};

const serveFile = (res, filePath, cacheControl = 'public, max-age=60') => {
  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
      res.statusCode = 404;
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.end('<h1>404 - 文件未找到</h1>');
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    const contentType = mimeTypes[ext] || 'application/octet-stream';
    res.statusCode = 200;
    res.setHeader('Content-Type', contentType);
    res.setHeader('Content-Length', stat.size);
    res.setHeader('Cache-Control', cacheControl);
    if (/(\.dmg|\.pkg|\.zip|\.tar\.gz)$/i.test(filePath)) {
      res.setHeader('Content-Disposition', `attachment; filename="${path.basename(filePath)}"`);
    }
    const stream = fs.createReadStream(filePath);
    stream.on('error', () => {
      res.statusCode = 500;
      res.end('Error reading file');
    });
    stream.pipe(res);
  });
};

const servePublic = (res, relativePath) => {
  const safePath = path
    .normalize(relativePath)
    .replace(/^([.]{2}[\/\\])+/, '')
    .replace(/^\//, '');
  const filePath = path.join(PUBLIC_DIR, safePath);
  if (!filePath.startsWith(PUBLIC_DIR)) {
    res.statusCode = 403;
    res.end('Forbidden');
    return;
  }
  serveFile(res, filePath);
};

const handlePackages = (res, pathname) => {
  const relative = pathname.replace(/^\/packages/, '') || '/';
  const safeRel = path.normalize(relative).replace(/^\/+/, '');
  const targetPath = path.join(PACKAGE_DIR, safeRel);

  if (!targetPath.startsWith(PACKAGE_DIR)) {
    res.statusCode = 403;
    res.end('Forbidden');
    return;
  }

  fs.stat(targetPath, (err, stat) => {
    if (err) {
      res.statusCode = 404;
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.end('<h1>404 - 文件未找到</h1>');
      return;
    }

    if (stat.isDirectory()) {
      res.statusCode = 404;
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.end('<h1>404 - 页面未找到</h1>');
    } else {
      serveFile(res, targetPath, 'no-cache');
    }
  });
};

const handleUpdateTrigger = (res, query) => {
  if (!UPDATE_SECRET) {
    res.statusCode = 403;
    res.end('更新接口未启用');
    return;
  }

  const token = typeof query === 'string' ? query : query.token;

  if (token !== UPDATE_SECRET) {
    res.statusCode = 401;
    res.end('无效的 token');
    return;
  }

  const child = spawn('bash', [UPDATE_SCRIPT], { cwd: path.dirname(UPDATE_SCRIPT) });
  child.on('close', (code) => {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.end(JSON.stringify({ success: code === 0, code }));
  });
  child.on('error', (err) => {
    res.statusCode = 500;
    res.end(JSON.stringify({ success: false, error: err.message }));
  });
};

const handleLogView = (res) => {
  const logPath = path.join(LOG_DIR, 'update.log');
  fs.readFile(logPath, 'utf8', (err, data) => {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.end(err ? '暂无日志' : data);
  });
};

const server = http.createServer((req, res) => {
  const parsed = url.parse(req.url, true);
  const pathname = parsed.pathname || '/';

  if (pathname === '/') {
    servePublic(res, 'index.html');
    return;
  }

  if (pathname === '/tools') {
    servePublic(res, 'tools.html');
    return;
  }

  if (pathname === '/other') {
    servePublic(res, 'other.html');
    return;
  }

  if (pathname === '/favorites') {
    servePublic(res, 'favorites.html');
    return;
  }

  if (pathname === '/download') {
    servePublic(res, 'download.html');
    return;
  }

  if (pathname.startsWith('/assets/')) {
    servePublic(res, pathname);
    return;
  }

  if (pathname.startsWith('/installers/')) {
    const rel = pathname.replace(/^\/installers\//, 'installers/');
    servePublic(res, rel);
    return;
  }

  if (pathname.startsWith('/packages')) {
    handlePackages(res, pathname);
    return;
  }

  // if (pathname.startsWith('/packages')) {
  //   res.statusCode = 404;
  //   res.setHeader('Content-Type', 'text/html; charset=utf-8');
  //   res.end('<h1>404 - 页面未找到</h1>');
  //   return;
  // }

  if (pathname === '/files') {
    const entries = readDirectorySafe(PUBLIC_DIR).map((dirent) => ({
      name: dirent.name,
      isDirectory: dirent.isDirectory(),
      size: dirent.isDirectory() ? 0 : fs.statSync(path.join(PUBLIC_DIR, dirent.name)).size
    }));
    const html = generateDirectoryListing({
      title: '公开资源',
      urlPath: '/files',
      entries
    });
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.end(html);
    return;
  }

  if (pathname === '/api/update-cache') {
    handleUpdateTrigger(res, parsed.query);
    return;
  }

  if (pathname === '/logs/update') {
    handleLogView(res);
    return;
  }

  const fallbackPath = path.join(PUBLIC_DIR, pathname.replace(/^\//, ''));
  if (fallbackPath.startsWith(PUBLIC_DIR) && fs.existsSync(fallbackPath) && fs.statSync(fallbackPath).isFile()) {
    serveFile(res, fallbackPath);
    return;
  }

  res.statusCode = 404;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.end('<h1>404 - 页面未找到</h1>');
});

server.listen(PORT, () => {
  console.log('🚀 kt-tools 文件服务器已启动');
  console.log(`📂 公共目录: ${PUBLIC_DIR}`);
  console.log(`📦 安装包目录: ${PACKAGE_DIR}`);
  console.log(`🌐 访问地址: http://0.0.0.0:${PORT}`);
  console.log('🔐 更新接口: /api/update-cache?token=<secret> (若设置 UPDATE_SECRET)');
});

process.on('SIGINT', () => {
  console.log('\n⛔ 服务器已停止');
  process.exit(0);
});
