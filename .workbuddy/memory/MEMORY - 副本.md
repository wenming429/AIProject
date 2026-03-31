# LumenIM 项目记忆

## 项目概况
- **项目名**: Lumen IM
- **类型**: 即时通讯系统
- **前端**: Vue3 + TypeScript + Vite
- **后端**: Go (go-chat)
- **数据库**: MySQL 8.0
- **缓存/队列**: Redis
- **对象存储**: MinIO
- **位置**: `d:\学习资料\AI_Projects\LumenIM\`

## 已配置服务
| 服务 | 端口 | 状态 | 备注 |
|------|------|------|------|
| MySQL | 3306 | ✅ 运行中 | 密码: wenming429 |
| Redis | 6379 | ✅ 运行中 | 安装目录: C:\Program Files\Redis |
| MinIO | 9000/9090 | ✅ 运行中 | 用户: minioadmin |
| 后端HTTP | 9501 | ✅ 运行中 | PID: 48820 |
| 后端WebSocket | 9502 | ✅ 运行中 | PID: 27192 |
| 前端 | 5173 | ✅ 运行中 | Vue3 + Vite |

## 重要配置
- **前端 WebSocket 地址**: `ws://localhost:9502` (在 `front/.env` 中配置)
- **后端 WebSocket 服务**: 独立运行在 9502 端口

## 快速命令
```bash
# 安装 Redis
winget install Memurai.MemuraiDeveloper

# 启动后端
cd d:\学习资料\AI_Projects\LumenIM\backend
.\lumenim.exe http

# 启动前端
cd d:\学习资料\AI_Projects\LumenIM\front
pnpm dev
```

## 测试数据
测试数据脚本: `d:\学习资料\AI_Projects\LumenIM\test_data.sql`

**用户列表 (密码均为 admin123)**:
| ID | 手机号 | 昵称 |
|----|--------|------|
| 4531 | 13800000001 | XiaoMing |
| 4540 | 13800000002 | XiaoHong |
| 4541 | 13800000003 | ZhangSan |
| 4542 | 13800000004 | LiSi |
| 4543 | 13800000005 | WangWu |
| 4544 | 13800000006 | ZhaoLiu |
| 4545 | 13800000007 | SunQi |
| 4546 | 13800000008 | ZhouBa |

**包含数据**:
- 8 个测试用户
- 10 个联系人分组 (多用户)
- 15 条好友关系
- 4 个聊天群组
- 17 个群成员记录
- 5 个会话记录
- 5 个表情包分组 + 11 个表情
- 1 个管理员账号
- 2 个机器人账号

**系统资源数据** (`system_data.sql`):
- 7 个部门 (组织架构)
- 8 个岗位
- 8 个用户组织关系
- 8 个文章标签
- 6 个文章分类
- 2 个群公告
- 4 条入群申请记录
- 1 个群投票
- 3 条用户收藏表情包

**组织架构**:
- Headquarters (XiaoMing)
  - Technology Dept (ZhangSan)
    - Frontend Team (LiSi)
    - Backend Team (WangWu)
  - Product Dept (XiaoHong)
    - UI Design Team (ZhaoLiu)
    - UX Research Team (SunQi)

## 项目文档
- `DEPLOYMENT_GUIDE.md` - 本地开发环境部署指南
- `DEPLOYMENT_PRODUCTION.md` - 正式环境私有化部署指南
- `DESKTOP_CLIENT.md` - 桌面客户端构建指南 (2026-03-29 新增)

## 桌面客户端 (Electron)
- **技术栈**: Electron ^33.4.0 + electron-builder ^25.1.8
- **可执行文件**: `front\release\win-unpacked\LumenIM.exe` (180MB)
- **启动命令**: 
  ```bash
  cd front
  pnpm run electron:dev     # 开发模式
  pnpm run electron:build:win  # 打包 Windows
  ```
- **核心文件**:
  - `electron/main.cjs` - 主进程 (窗口管理、托盘、通知)
  - `electron/preload.cjs` - 预加载脚本 (IPC 通信)
  - `electron-builder.json` - 打包配置
  - `.env.electron` - Electron 环境变量
- **打包注意**: Electron 二进制文件需要使用国内镜像下载 (ELECTRON_MIRROR)
- **打包成功时间**: 2026-03-29 (180MB exe, 272MB 总大小)

## 外部数据库同步 (UDM 表)
- **源库**: SQL Server 10.90.102.66 / CFLDCN_PMS20230905 (账号: sa)
- **目标库**: 本地 MySQL go_chat
- **同步脚本**: `scripts/sync_udm_to_mysql.js`
- **验证脚本**: `scripts/verify_udm_sync.js`
- **依赖包**: `mssql`, `mysql2` (安装在项目根 node_modules)
- **同步表清单** (12张，共 667,067 行):
  | 表名 | 行数 |
  |------|------|
  | UDMBUSINESSUNIT | 100 |
  | UDMBUSINESSUNIT_TEMP | 1 |
  | UDMJOB | 522,928 |
  | UDMJOB_TEMP | 306 |
  | UDMJOBINFO | 1,244 |
  | UDMJOBINFO_TEMP | 1 |
  | UDMORGANIZATION | 13,488 |
  | UDMORGANIZATION_TEMP | 6 |
  | UDMPOSITION | 24,495 |
  | UDMPOSITION_TEMP | 10 |
  | UDMUSER | 104,438 |
  | UDMUSER_TEMP | 50 |
- **首次同步时间**: 2026-03-30，耗时约 487s
- **重新同步**: 直接重跑脚本即可（会先 DROP 再重建表）

## 外部数据库同步 (Sys 表)
- **源库**: SQL Server 10.90.102.66 / CFLDCN_PMS20230905
- **目标库**: 本地 MySQL go_chat
- **同步脚本**: `scripts/sync_sys_tables.js`
- **检查脚本**: `scripts/inspect_sys_tables.js`
- **同步表清单** (2张，共 113,479 行):
  | 表名 | 行数 |
  |------|------|
  | SysDepartment | 9,083 |
  | SysUser | 104,396 |
- **首次同步时间**: 2026-03-30，耗时约 11s

## 数据库备注修复
- **问题**: 执行 lumenim.sql 时表/字段备注显示为乱码（如 "绠＄悊鍛樿〃"）
- **原因**: SQL 执行时字符集配置不正确导致 UTF-8 中文被误解读
- **修复脚本**: `scripts/fix_comments_v3.js`（解析 lumenim.sql 提取正确中文备注，用 ALTER TABLE 更新）
- **修复时间**: 2026-03-30
- **修复结果**: 28 张表备注 + 243 个字段备注全部恢复正常

## 主键类型迁移 (INT -> VARCHAR(36))
- **完成时间**: 2026-03-30
- **迁移表**: users, organize, organize_dept, organize_position
- **迁移脚本**: `scripts/migrate_organize_to_uuid.js`, `scripts/rebuild_organize.js`
- **迁移结果**: 所有四张表的主键和外键都已迁移到 VARCHAR(36)
- **UUID 生成函数**: deterministic UUID（基于命名空间的哈希）
- **验证脚本**: `scripts/verify_all_tables.js`

**迁移后的数据关联**:
- organize.user_id -> users.id
- organize.dept_id -> organize_dept.dept_id
- organize.position_id -> organize_position.position_id
