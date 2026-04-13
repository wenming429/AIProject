# LumenIM 软件包离线部署套件
# LumenIM Offline Deployment Package Suite

版本: 1.0.0
更新日期: 2026-04-07

---

## 目录结构

```
software/
├── README.md              # 本文件 - 使用说明
├── PACKAGE_LIST.md        # 软件包清单 - 包含所有依赖的下载链接
├── INSTALL_GUIDE.md       # 安装指南 - 详细安装步骤
├── download-dependencies.ps1  # 自动下载脚本 (Windows PowerShell)
├── bin/                   # 下载的安装包存放目录
│   ├── go1.25.0.windows-amd64.msi
│   ├── node-v22.14.0-x64.msi
│   ├── mysql-8.0.40-winx64.zip
│   ├── Redis-x64-5.0.14.1.msi
│   ├── protoc-25.1-win64.zip
│   └── ...
└── scripts/
    ├── verify-installation.ps1  # 环境验证脚本
    └── quick-deploy.sh          # Linux 一键部署脚本
```

---

## 快速开始

### Windows 用户

**第一步：下载依赖包**

```powershell
cd software
.\download-dependencies.ps1 -Components All
```

**第二步：验证环境**

```powershell
.\scripts\verify-installation.ps1
```

**第三步：按安装指南安装**

打开 `INSTALL_GUIDE.md` 按照步骤安装各组件。

### Linux/macOS 用户

**第一步：执行一键部署**

```bash
cd software/scripts
chmod +x quick-deploy.sh
./quick-deploy.sh
```

**第二步：验证安装**

```bash
./quick-deploy.sh 6
```

---

## 软件包清单

详细的软件包信息、版本、下载链接请查看 `PACKAGE_LIST.md`。

### 核心依赖

| 组件 | 版本 | 用途 |
|------|------|------|
| Go | 1.25.0 | 后端运行环境 |
| Node.js | 22.14.0 | 前端构建环境 |
| pnpm | 10.0.0 | 包管理器 |

### 数据库

| 组件 | 版本 | 用途 |
|------|------|------|
| MySQL | 8.0.40 | 主数据库 |
| Redis | 5.0.14 | 缓存服务 |

### 开发工具

| 组件 | 版本 | 用途 |
|------|------|------|
| protoc | 25.1 | Proto 代码生成 |
| buf | 1.28.1 | Proto 工具链 |
| Git | 2.48.1 | 版本控制 |

---

## 常见问题

### Q1: 下载脚本执行失败？

```powershell
# 检查执行策略
Get-ExecutionPolicy

# 设置执行策略
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 重新运行
.\download-dependencies.ps1
```

### Q2: 部分文件下载失败？

默认跳过已存在的文件，如需重新下载：
```powershell
.\download-dependencies.ps1 -SkipExisting $false
```

### Q3: 如何手动下载？

访问 `PACKAGE_LIST.md` 获取所有下载链接。

### Q4: 需要代理？

```powershell
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
$env:HTTP_PROXY = "http://127.0.0.1:7890"
.\download-dependencies.ps1
```

---

## 故障排除

| 问题 | 解决方案 |
|------|----------|
| 权限不足 | 以管理员身份运行 PowerShell |
| 网络超时 | 配置代理或使用国内镜像 |
| 端口占用 | `netstat -ano \| findstr <端口号>` |
| 版本不匹配 | 参考 `PACKAGE_LIST.md` 中的推荐版本 |

---

## 联系与支持

- 项目地址: https://github.com/gzydong/go-chat
- 问题反馈: https://github.com/gzydong/go-chat/issues

---

*本套件由 AI 辅助生成，仅供 LumenIM 项目使用。*
