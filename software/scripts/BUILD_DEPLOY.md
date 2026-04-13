# LumenIM 本地打包与远程部署脚本

**版本**: 1.1.0
**日期**: 2026-04-09
**功能**: 本地打包前后端 → 安全传输 → 远程服务器部署

---

## 快速开始

### Windows 环境

#### 方式一：PowerShell（推荐）

```powershell
# 进入脚本目录
cd d:/学习资料/AI_Projects/LumenIM/software/scripts

# 仅打包
.\build-deploy.ps1 -BuildOnly

# 打包并上传
.\build-deploy.ps1 -Upload -ServerIP 192.168.23.131

# 完整部署
.\build-deploy.ps1 -Deploy -ServerIP 192.168.23.131 -ServerUser root
```

#### 方式二：批处理脚本

```cmd
# 仅打包
.\run-deploy.bat --build-only

# 完整部署
.\run-deploy.bat --deploy --server-ip=192.168.23.131 --server-user=root
```

### Linux/macOS 环境

```bash
cd ~/LumenIM/software/scripts

# 仅打包
./build-deploy.sh --build-only

# 完整部署
./build-deploy.sh --deploy --server-ip=192.168.23.131 --server-user=root
```

---

## 文件清单

| 文件 | 说明 | 平台 |
|------|------|------|
| `build-deploy.ps1` | PowerShell 部署脚本 | Windows |
| `build-deploy.sh` | Bash 部署脚本 | Linux/macOS |
| `run-deploy.bat` | Windows 一键部署批处理 | Windows |
| `deploy-config.json` | 配置文件模板 | 通用 |
| `BUILD_DEPLOY.md` | 本文档 | 通用 |

---

## 功能特性

| 功能 | 说明 |
|------|------|
| 前端打包 | pnpm build → dist 目录 |
| 后端打包 | go build → 二进制 + 配置 |
| 压缩传输 | tar.gz 压缩后 SCP 传输 |
| SSH 认证 | 支持密码/密钥认证 |
| 部署验证 | 自动检查服务状态 |
| 回滚支持 | 保留最近 3 个版本备份 |
| 日志记录 | 完整操作日志 |
| 错误处理 | 失败自动回滚 |

---

## 配置文件

创建 `deploy-config.json` 或直接在脚本中修改：

```json
{
    "server": {
        "host": "192.168.23.131",
        "port": 22,
        "user": "root",
        "auth": "key",
        "keyPath": "~/.ssh/id_rsa",
        "password": ""
    },
    "paths": {
        "localProject": ".",
        "remoteDeploy": "/var/www/lumenim",
        "backupDir": "/var/lib/lumenim/backups"
    },
    "build": {
        "buildBackend": true,
        "buildFrontend": true,
        "cleanBefore": true
    },
    "network": {
        "bindIP": "192.168.23.131",
        "domain": "mylumenim.cfldcn.com",
        "apiPort": 9501,
        "httpPort": 80
    }
}
```

---

## 使用示例

### 示例 1：仅打包（不上传）

```powershell
.\build-deploy.ps1 -BuildOnly
```

### 示例 2：打包 + 上传到服务器（不部署）

```powershell
.\build-deploy.ps1 -Upload -ServerIP 192.168.23.131
```

### 示例 3：完整部署流程

```powershell
.\build-deploy.ps1 -Deploy -ServerIP 192.168.23.131 -ServerUser root
```

### 示例 4：指定分支部署

```powershell
.\build-deploy.ps1 -Deploy -ServerIP 192.168.23.131 -Branch main
```

### 示例 5：使用密码认证

```powershell
.\build-deploy.ps1 -Deploy -ServerIP 192.168.23.131 -AuthType password -Password "mypassword"
```

### 示例 6：回滚到上一个版本

```powershell
.\build-deploy.ps1 -Rollback -ServerIP 192.168.23.131
```

---

## 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `-ServerIP` | 服务器 IP | 192.168.23.131 |
| `-ServerUser` | SSH 用户名 | root |
| `-ServerPort` | SSH 端口 | 22 |
| `-AuthType` | 认证方式: key/password | key |
| `-KeyPath` | SSH 密钥路径 | ~/.ssh/id_rsa |
| `-Password` | SSH 密码（密码认证时） | - |
| `-RemotePath` | 远程部署路径 | /var/www/lumenim |
| `-Branch` | Git 分支 | main |
| `-BuildOnly` | 仅打包，不上传 | false |
| `-Upload` | 打包并上传，不部署 | false |
| `-Deploy` | 完整部署 | false |
| `-Rollback` | 回滚到上一版本 | false |
| `-SkipBackup` | 跳过备份 | false |
| `-Verbose` | 详细输出 | false |

---

## 部署流程

```
┌─────────────────────────────────────────────────────────────┐
│                     本地 Windows                             │
├─────────────────────────────────────────────────────────────┤
│  1. 环境检查 (Go, Node, Git)                                │
│  2. 备份旧版本 (如有)                                        │
│  3. 拉取最新代码                                             │
│  4. 构建后端 (go build)                                      │
│  5. 构建前端 (pnpm build)                                    │
│  6. 打包 (tar.gz)                                           │
│  7. SCP 上传到服务器                                         │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                     远程 Ubuntu 服务器                        │
├─────────────────────────────────────────────────────────────┤
│  8. 备份旧版本                                              │
│  9. 解压到部署目录                                           │
│ 10. 配置 config.yaml                                        │
│ 11. 配置 Nginx                                              │
│ 12. 重启服务                                                 │
│ 13. 健康检查                                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## 输出文件

| 文件 | 说明 |
|------|------|
| `deploy-package/lumenim-backend.tar.gz` | 后端部署包 |
| `deploy-package/lumenim-frontend.tar.gz` | 前端部署包 |
| `deploy-package/deploy-*.log` | 部署日志 |
| `deploy-package/backup/lumenim-backup-*.tar.gz` | 服务器备份 |

---

## 故障排查

### 1. SSH 连接失败

```powershell
# 测试连接
ssh -p 22 root@192.168.23.131 "echo ok"

# 检查密钥权限 (Windows)
icacls $env:USERPROFILE\.ssh\id_rsa /inheritance:r /grant:r "$env:USERNAME:R"
```

### 2. 构建失败

```powershell
# 检查 Go 版本
go version

# 检查 Node 版本
node -v

# 检查 pnpm
pnpm -v
```

### 3. 服务启动失败

```bash
# SSH 登录服务器后检查
journalctl -u lumenim-backend -n 50
systemctl status lumenim-backend
```

---

## 安全建议

1. **使用密钥认证**: 避免密码明文传输
2. **限制备份数量**: 默认保留 3 个版本
3. **日志脱敏**: 生产环境移除敏感日志
4. **权限最小化**: 部署用户使用非 root 账号

---

## 更新日志

- v1.0.0 (2026-04-09): 初始版本
