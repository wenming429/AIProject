# LumenIM 软件包清单
# LumenIM Software Package List
# 版本: 1.0.0
# 更新日期: 2026-04-07

## 一、核心运行时环境

### 1. Go 语言环境
| 包名 | 版本 | 下载链接 | 适用系统 | 备注 |
|------|------|----------|----------|------|
| go1.25.0.windows-amd64.msi | 1.25.0 | https://go.dev/dl/go1.25.0.windows-amd64.msi | Windows x64 | 主要后端运行环境 |
| go1.25.0.linux-amd64.tar.gz | 1.25.0 | https://go.dev/dl/go1.25.0.linux-amd64.tar.gz | Linux x64 | 服务器部署 |
| go1.25.0.darwin-amd64.pkg | 1.25.0 | https://go.dev/dl/go1.25.0.darwin-amd64.pkg | macOS x64 | 开发环境 |

### 2. Node.js 环境
| 包名 | 版本 | 下载链接 | 适用系统 | 备注 |
|------|------|----------|----------|------|
| node-v22.14.0-x64.msi | 22.14.0 | https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi | Windows x64 | 前端构建环境 |
| node-v22.14.0-linux-x64.tar.xz | 22.14.0 | https://nodejs.org/dist/v22.14.0/node-v22.14.0-linux-x64.tar.xz | Linux x64 | 服务器部署 |
| node-v22.14.0.pkg | 22.14.0 | https://nodejs.org/dist/v22.14.0/node-v22.14.0.pkg | macOS | 开发环境 |

### 3. pnpm 包管理器
| 包名 | 版本 | 下载链接 | 备注 |
|------|------|----------|------|
| pnpm-windows-x64.exe | 10.0.0 | https://github.com/pnpm/pnpm/releases/download/v10.0.0/pnpm-windows-x64.exe | Windows 二进制 |
| pnpm-linux-x64 | 10.0.0 | https://github.com/pnpm/pnpm/releases/download/v10.0.0/pnpm-linux-x64 | Linux 二进制 |

---

## 二、数据库相关

### 4. MySQL 8.0
| 包名 | 版本 | 下载链接 | 适用系统 | 备注 |
|------|------|----------|----------|------|
| mysql-8.0.40-winx64.msi | 8.0.40 | https://dev.mysql.com/downloads/mysql/8.0.html | Windows x64 | 主数据库 |
| mysql-8.0.40-linux-glibc2.28-x86_64.tar.gz | 8.0.40 | https://dev.mysql.com/get/Downloads/MySQL-8.0/mysql-8.0.40-linux-glibc2.28-x86_64.tar.gz | Linux x64 | 服务器部署 |

### 5. Redis
| 包名 | 版本 | 下载链接 | 适用系统 | 备注 |
|------|------|----------|----------|------|
| Redis-x64-5.0.14.1.msi | 5.0.14 | https://github.com/tporadowski/redis/releases/download/v5.0.14.1/Redis-x64-5.0.14.1.msi | Windows x64 | 缓存服务 |
| redis-7.4.3.tar.gz | 7.4.3 | https://github.com/redis/redis/archive/refs/tags/7.4.3.tar.gz | Linux | 服务器部署 |

---

## 三、Protocol Buffers 工具链

### 6. Protocol Buffers 编译器
| 包名 | 版本 | 下载链接 | 适用系统 | 备注 |
|------|------|----------|----------|------|
| protoc-25.1-win64.zip | 25.1 | https://github.com/protocolbuffers/protobuf/releases/download/v25.1/protoc-25.1-win64.zip | Windows x64 | Proto 代码生成 |
| protoc-25.1-linux-x86_64.zip | 25.1 | https://github.com/protocolbuffers/protobuf/releases/download/v25.1/protoc-25.1-linux-x86_64.zip | Linux x64 | 服务器部署 |

### 7. Go Protobuf 插件
| 包名 | 版本 | 安装命令 | 备注 |
|------|------|----------|------|
| protoc-gen-go | v1.36.11 | `go install google.golang.org/protobuf/cmd/protoc-gen-go@latest` | Go 代码生成 |
| protoc-gen-validate | v1.2.1 | `go install github.com/envoyproxy/protoc-gen-validate@latest` | 验证逻辑生成 |
| protoc-gen-bff | 自定义 | 项目内置 | BFF 代码生成 |

### 8. Buf CLI
| 包名 | 版本 | 下载链接 | 备注 |
|------|------|----------|------|
| buf-Windows-x86_64.exe | 1.28.1 | https://github.com/bufbuild/buf/releases/download/v1.28.1/buf-Windows-x86_64.exe | Windows |
| buf-Darwin-x86_64 | 1.28.1 | https://github.com/bufbuild/buf/releases/download/v1.28.1/buf-Darwin-x86_64 | macOS |
| buf-Linux-x86_64 | 1.28.1 | https://github.com/bufbuild/buf/releases/download/v1.28.1/buf-Linux-x86_64 | Linux |

---

## 四、开发工具

### 9. Git 版本控制
| 包名 | 版本 | 下载链接 | 适用系统 | 备注 |
|------|------|----------|----------|------|
| Git-2.48.1-64-bit.exe | 2.48.1 | https://github.com/git-for-windows/git/releases/download/v2.48.1.windows.1/Git-2.48.1-64-bit.exe | Windows | 代码仓库 |
| git-*.*.*-x86_64.tar.gz | 最新 | https://github.com/git/git/archive/refs/tags/v2.48.1.tar.gz | Linux | 服务器部署 |

### 10. Docker (可选)
| 包名 | 版本 | 下载链接 | 备注 |
|------|------|----------|------|
| Docker Desktop Installer.exe | 最新 | https://docs.docker.com/desktop/install/windows-install/ | Windows | 容器化部署 |
| docker-*.*.*.tgz | 最新 | https://download.docker.com/linux/static/stable/x86_64/ | Linux | 服务器部署 |

### 11. Make 工具
| 包名 | 版本 | 下载链接 | 适用系统 | 备注 |
|------|------|----------|----------|------|
| make-4.4.1-minimal.zip | 4.4.1 | https://sourceforge.net/projects/gnuwin32/files/make/3.81/make-3.81-bin.zip | Windows | 构建工具 |

### 12. Chocolatey (Windows 包管理器)
| 包名 | 安装命令 | 备注 |
|------|----------|------|
| Chocolatey | `Set-ExecutionPolicy Bypass -Scope Process -File https://chocolatey.org/install.ps1` | Windows 包管理 |

---

## 五、前端 Electron 桌面应用

### 13. Electron
| 包名 | 版本 | 下载链接 | 备注 |
|------|------|----------|------|
| electron-v33.4.0-linux-x64.tar.gz | 33.4.0 | https://cdn.npm.taobao.org/dist/electron/v33.4.0/electron-v33.4.0-linux-x64.tar.gz | Linux |
| electron-v33.4.0-darwin-arm64.zip | 33.4.0 | https://cdn.npm.taobao.org/dist/electron/v33.4.0/electron-v33.4.0-darwin-arm64.zip | macOS ARM64 |
| electron-v33.4.0-darwin-x64.zip | 33.4.0 | https://cdn.npm.taobao.org/dist/electron/v33.4.0/electron-v33.4.0-darwin-x64.zip | macOS x64 |
| electron-*.*.*-win32-x64.zip | 33.4.0 | 由 npm 自动下载 | Windows |

---

## 六、项目 Go 依赖包 (go.mod)

### 核心框架
| 包名 | 版本 | 说明 |
|------|------|------|
| github.com/gin-gonic/gin | v1.11.0 | HTTP Web 框架 |
| github.com/golang-jwt/jwt/v5 | v5.3.0 | JWT 认证 |
| github.com/redis/go-redis/v9 | v9.16.0 | Redis 客户端 |
| gorm.io/driver/mysql | v1.6.0 | MySQL 驱动 |
| gorm.io/gorm | v1.31.0 | ORM 框架 |

### 认证相关
| 包名 | 版本 | 说明 |
|------|------|------|
| github.com/pquerna/otp | v1.5.0 | TOTP 认证 |
| github.com/mojocn/base64Captcha | v1.3.8 | 验证码 |
| golang.org/x/oauth2 | v0.30.0 | OAuth2 支持 |

### 工具库
| 包名 | 版本 | 说明 |
|------|------|------|
| github.com/google/uuid | v1.6.0 | UUID 生成 |
| github.com/bwmarrin/snowflake | v0.3.0 | 分布式 ID |
| github.com/samber/lo | v1.52.0 | 工具库 |

### 消息队列
| 包名 | 版本 | 说明 |
|------|------|------|
| github.com/nsqio/go-nsq | v1.1.0 | NSQ 客户端 |

### 对象存储
| 包名 | 版本 | 说明 |
|------|------|------|
| github.com/minio/minio-go/v7 | v7.0.95 | MinIO 客户端 |

### Protobuf
| 包名 | 版本 | 说明 |
|------|------|------|
| google.golang.org/protobuf | v1.36.10 | Protobuf 支持 |
| github.com/envoyproxy/protoc-gen-validate | v1.2.1 | 验证支持 |
| buf.build/gen/go/bufbuild/protovalidate/protocolbuffers/go | v1.36.10 | Protovalidate |

---

## 七、项目前端依赖 (package.json)

### 核心依赖
| 包名 | 版本 | 说明 |
|------|------|------|
| vue | ^3.5.16 | Vue 3 框架 |
| vue-router | ^4.5.1 | 路由管理 |
| pinia | ^3.0.2 | 状态管理 |
| naive-ui | ^2.41.0 | UI 组件库 |
| core-js | ^3.39.0 | JavaScript 兼容 |
| crypto-js | ^4.2.0 | 加密库 |
| jsencrypt | ^3.3.2 | RSA 加密 |

### 音视频
| 包名 | 版本 | 说明 |
|------|------|------|
| js-audio-recorder | ^1.0.7 | 录音功能 |
| xgplayer | ^3.0.21 | 视频播放器 |

### 编辑器
| 包名 | 版本 | 说明 |
|------|------|------|
| quill | ^2.0.3 | 富文本编辑器 |
| md-editor-v3 | ^5.6.1 | Markdown 编辑器 |
| vue-cropper | ^1.1.3 | 图片裁剪 |

### 开发依赖
| 包名 | 版本 | 说明 |
|------|------|------|
| vite | ^6.3.5 | 构建工具 |
| typescript | ~5.2.0 | TypeScript |
| electron | ^33.4.0 | 桌面应用 |
| electron-builder | ^25.1.8 | 打包工具 |

---

## 八、文件哈希校验

下载完成后，可使用以下命令校验文件完整性：

### Windows (PowerShell)
```powershell
# 计算 SHA256 哈希
Get-FileHash -Path "文件路径" -Algorithm SHA256
```

### Linux/macOS
```bash
# 计算 SHA256 哈希
sha256sum 文件路径
# 或
shasum -a 256 文件路径
```

---

## 九、下载优先级建议

### 初次安装（必须）
1. go1.25.0.*.msi/tar.gz - Go 运行环境
2. node-v22.*.*-x64.msi/pkg - Node.js 运行环境
3. mysql-8.0.*.*.msi/tar.gz - MySQL 数据库
4. Redis-x64-*.msi 或 redis-*.tar.gz - Redis 缓存
5. protoc-*.zip - Protocol Buffers 编译器
6. Git-*.exe 或 git-*.tar.gz - Git 版本控制

### 开发环境（推荐）
7. pnpm - 包管理器
8. buf - Proto 代码生成辅助工具
9. Docker Desktop (可选) - 容器化开发

### 生产部署（可选）
10. docker-compose - 容器编排
11. Make 工具 - 自动化构建

---

## 十、注意事项

1. **版本兼容性**：请确保 Go 版本 >= 1.25，Node.js 版本 >= 22
2. **系统架构**：根据您的操作系统选择对应架构（x64/arm64）
3. **网络环境**：如无法访问外网，请使用内网镜像源或提前下载离线包
4. **权限要求**：Windows 安装需要管理员权限，Linux/macOS 使用 sudo

---

*文档生成时间：2026-04-07*
*项目地址：https://github.com/gzydong/go-chat*
