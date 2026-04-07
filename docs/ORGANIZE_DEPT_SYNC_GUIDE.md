# 组织机构数据同步 - 执行指南

## 📋 概述

本指南详细说明如何执行 `sync_organize_dept.js` 脚本，将业务主数据系统（SQL Server）中的 `UDMOrganization` 表同步到 `go_chat` 数据库（MySQL）的 `organize_dept` 表。

---

## 🎯 同步方案核心要点

### 字段映射关系

| organize_dept (目标) | UDMOrganization (源) | 说明 |
|---------------------|---------------------|------|
| `dept_id` | 新生成自增ID | GUID → INT 转换 |
| `parent_id` | `PARENTID` | 通过映射表转换 |
| `dept_name` | `FULLNAME` | 直接映射 |
| `short_name` | `SHORTNAME` | 直接映射 |
| `ancestors` | 计算生成 | 格式: `0/1/2/3` |
| `order_num` | `SORT` | 直接映射 |
| `status` | `ISVISIBLE` | 1→1, 0→2 |
| `is_deleted` | `ISDEL` | 0→2, 1→1 |

### ID转换机制

```
源数据 (UDMOrganization)          目标数据 (organize_dept)
┌─────────────────────────┐        ┌─────────────────────────┐
│ ID: xxx-001             │        │ dept_id: 1              │
│ PARENTID: null          │   →    │ parent_id: 0            │
│ FULLNAME: 集团总部       │        │ ancestors: 0/1          │
└─────────────────────────┘        └─────────────────────────┘
            │                                    │
            ▼                                    ▼
┌─────────────────────────┐        ┌─────────────────────────┐
│ ID: xxx-002             │        │ dept_id: 2              │
│ PARENTID: xxx-001       │   →    │ parent_id: 1            │
│ FULLNAME: 研发中心       │        │ ancestors: 0/1/2         │
└─────────────────────────┘        └─────────────────────────┘
```

---

## 🔧 环境准备

### 1. 安装 Node.js 依赖

```bash
cd d:\学习资料\AI_Projects\LumenIM\scripts
npm install mssql mysql2
```

### 2. 配置数据库连接

可通过以下两种方式配置：

**方式一：环境变量**
```powershell
# PowerShell
$env:SS_SERVER = "10.90.102.66"
$env:SS_DATABASE = "CFLDCN_PMS20230905"
$env:SS_USER = "sa"
$env:SS_PASSWORD = "YourPassword"

$env:MY_HOST = "localhost"
$env:MY_PORT = "3306"
$env:MY_USER = "root"
$env:MY_PASSWORD = "YourPassword"
$env:MY_DATABASE = "go_chat"
```

**方式二：直接修改脚本 CONFIG 对象**
```javascript
// 打开 sync_organize_dept.js，找到第 15-35 行，修改配置
const CONFIG = {
  sqlserver: {
    server: '10.90.102.66',
    database: 'CFLDCN_PMS20230905',
    user: 'sa',
    password: 'YourPassword',  // 修改为实际密码
    ...
  },
  mysql: {
    host: 'localhost',
    port: 3306,
    user: 'root',
    password: 'YourPassword',  // 修改为实际密码
    database: 'go_chat',
    ...
  }
};
```

---

## 🚀 执行步骤

### 步骤1：首次执行（全量同步）

```bash
cd d:\学习资料\AI_Projects\LumenIM\scripts
node sync_organize_dept.js --full
```

**预期输出：**
```
============================================================
🏢 UDMOrganization → Organize_Dept 同步程序
============================================================

📡 阶段1: 数据库连接...

[2026-04-05T12:35:00.000Z] [INFO] 正在连接 SQL Server...
[2026-04-05T12:35:01.000Z] [INFO] ✅ SQL Server 连接成功
[2026-04-05T12:35:01.000Z] [INFO] 正在连接 MySQL...
[2026-04-05T12:35:02.000Z] [INFO] ✅ MySQL 连接成功

🔍 阶段2: 表结构检查...

[INFO] 源表数据量: 150 条
[INFO] 目标表字段列表:
  - dept_id: int unsigned
  - parent_id: int unsigned
  ...

💾 阶段3: 备份目标表...

[INFO] 步骤4: 备份目标表...
[INFO] ✅ 已备份 organize_dept 表 → organize_dept_backup_20260405_123500
[INFO]    备份数据量: 50 条
[INFO] ✅ 备份记录已写入 _backup_history 表

🗄️ 阶段4: 准备同步环境...

[INFO] 步骤5: 创建ID映射表 _dept_id_mapping...
[INFO] ✅ 映射表 _dept_id_mapping 创建成功
[INFO] 步骤6: 全量同步模式: 将清空目标表
[INFO] ✅ 目标表清空完成

📥 阶段5: 执行数据同步...

[INFO] 将处理 150 条源数据
[INFO] ✅ ID映射完成，共 150 条记录
[INFO] ✅ 数据同步完成: 150 条记录

✅ 阶段6: 验证和报告...

[INFO] 目标表数据量: 150
[INFO] 映射表数据量: 150
[INFO] ✅ 所有 parent_id 关系验证通过
[INFO] ✅ ancestors 路径格式验证通过

📊 同步报告:
{
  "syncTime": "2026-04-05T12:35:10.000Z",
  "sourceCount": 150,
  "targetCount": 150,
  "successCount": 150,
  "errorCount": 0,
  "statistics": {...},
  "backup": {
    "backedUp": true,
    "backupSuffix": "_backup_20260405_123500",
    "rowCount": 50
  },
  "backupHistory": [...],
  "steps": [...],
  "duration": "12.50s"
}

============================================================
📊 同步执行结果汇总
============================================================
⏱️  执行耗时: 12.50 秒
📥  源数据量: 150 条
📤  目标写入: 150 条
💾  备份记录: 50 条
❌  错误数量: 0 条

📝 执行步骤:
   1. ✅ 检查源表结构 - ✅
   2. ✅ 检查目标表结构 - ✅
   3. ✅ 备份目标表 - ✅
   4. ✅ 创建ID映射表 - ✅
   5. ✅ 清空目标表 - ✅
   6. ✅ 提取源数据并生成ID映射 - ✅
   7. ✅ 同步数据到目标表 - ✅
   8. ✅ 数据验证 - ✅
   8. ✅ 生成同步报告 - ✅
============================================================
🎉 同步任务完成！
```

### 步骤2：后续执行（增量同步）

```bash
# 默认增量同步（仅同步最近1天更新的数据）
node sync_organize_dept.js

# 指定增量时间范围（脚本内可配置）
```

### 步骤3：模拟运行（不写入数据库）

```bash
node sync_organize_dept.js --dry-run
```

---

## 📊 执行结果解读

### 成功标志

| 指标 | 说明 | 正常值 |
|------|------|--------|
| `errorCount` | 错误数量 | 0 |
| `orphanCount` | 孤立记录数 | 0 |
| `invalidAncestorsCount` | 路径格式异常数 | 0 |

### 统计指标

| 字段 | 说明 |
|------|------|
| `total` | 目标表总记录数 |
| `rootCount` | 根部门数量 |
| `deletedCount` | 已删除记录数 |
| `disabledCount` | 已停用记录数 |
| `maxLevel` | 最大层级深度 |


---

## 💾 备份管理

### 自动备份机制

执行全量同步时，脚本会自动进行以下备份操作：

| 操作 | 说明 |
|------|------|
| 创建备份表 | `organize_dept_backup_YYYYMMDD_HHMMSS` |
| 备份映射表 | `_dept_id_mapping_backup_YYYYMMDD_HHMMSS` |
| 记录备份历史 | `_backup_history` 表 |
| 清理旧备份 | 自动保留最近5个备份 |

### 查看备份历史

```bash
# 查看备份历史记录
node sync_organize_dept.js --show-backups
```

**预期输出：**
```
📜 备份历史记录:
================================================================================
| 序号 | 原始表名           | 备份表名                     | 数据量 | 备份时间              | 备注 |
--------------------------------------------------------------------------------
|    1 | organize_dept     | organize_dept_backup_20260405_123500 |     50 | 2026-04-05 12:35:00 | 全量同步前备份 |
|    2 | organize_dept     | organize_dept_backup_20260401_090000 |     48 | 2026-04-01 09:00:00 | 全量同步前备份 |

📦 可用的备份表:
  - organize_dept_backup_20260405_123500 (50 条记录, 2026-04-05T12:35:00.000Z)
  - organize_dept_backup_20260401_090000 (48 条记录, 2026-04-01T09:00:00.000Z)
```

### 手动查看备份（SQL）

```sql
-- 查看所有备份历史
SELECT * FROM _backup_history ORDER BY backup_time DESC;

-- 查看备份表数据
SELECT * FROM organize_dept_backup_20260405_123500;

-- 查看可用的备份表
SELECT TABLE_NAME, TABLE_ROWS, CREATE_TIME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'go_chat' 
  AND TABLE_NAME LIKE 'organize_dept_backup_%'
ORDER BY CREATE_TIME DESC;
```

### 从备份恢复（开发中）

```bash
# 恢复功能开发中...
node sync_organize_dept.js --restore=organize_dept_backup_20260405_123500
```

---

## 🔍 查看映射表

同步完成后，可通过以下SQL查看ID映射关系：

```sql
-- 查看映射关系（前20条）
SELECT 
    m.source_id AS '源GUID',
    m.target_id AS '目标ID',
    d.dept_name AS '部门名称',
    d.parent_id AS '父部门ID',
    d.ancestors AS '层级路径'
FROM _dept_id_mapping m
JOIN organize_dept d ON m.target_id = d.dept_id
ORDER BY m.target_id
LIMIT 20;

-- 查看层级树结构
SELECT 
    dept_id,
    RPAD('', (LENGTH(ancestors) - LENGTH(REPLACE(ancestors, '/', ''))) * 4, '    ') AS indent,
    dept_name,
    parent_id,
    ancestors
FROM organize_dept
ORDER BY ancestors, order_num;
```

---

## ⚠️ 常见问题处理

### 问题1：连接 SQL Server 失败

```
[ERROR] ❌ SQL Server 连接失败: ConnectionError: Login failed for user 'sa'
```

**解决方案：**
1. 检查 `SS_USER` 和 `SS_PASSWORD` 配置
2. 确认 SQL Server 已启用 TCP/IP 协议
3. 检查防火墙是否允许 1433 端口

### 问题2：连接 MySQL 失败

```
[ERROR] ❌ MySQL 连接失败: ER_ACCESS_DENIED_ERROR: Access denied for user 'root'
```

**解决方案：**
1. 检查 `MY_USER` 和 `MY_PASSWORD` 配置
2. 确认用户有 go_chat 数据库的读写权限

### 问题3：parent_id 关联失败

```
[WARNING] ⚠️ 发现 5 条记录的 parent_id 在目标表中不存在
```

**可能原因：**
- 源数据中存在引用了已删除部门的情况
- 增量同步时，父部门尚未同步

**解决方案：**
1. 检查孤立记录的 `source_parent_id`
2. 确保增量同步时先同步父部门，或使用全量同步

### 问题4：数据量不匹配

```
源数据量: 150 条
目标写入: 140 条
```

**可能原因：**
- 源数据中 `IsDel = 1` 的记录被过滤
- 增量同步时 `UPDATETIME` 过滤条件

---

## 📝 脚本参数说明

| 参数 | 说明 | 示例 |
|------|------|------|
| `--full` | 全量同步（**先自动备份再清空**目标表） | `node sync_organize_dept.js --full` |
| `--dry-run` | 模拟运行（不写入数据库） | `node sync_organize_dept.js --dry-run` |
| `--show-backups` | 查看备份历史记录 | `node sync_organize_dept.js --show-backups` |
| `--restore=<表名>` | 从指定备份表恢复（开发中） | `node sync_organize_dept.js --restore=organize_dept_backup_20260405` |

---

## 🔄 定时同步配置（可选）

如需定时执行同步，可创建 Windows 任务计划或使用 node-cron：

```javascript
// 在脚本末尾添加定时任务
const cron = require('node-cron');

// 每天凌晨2点执行增量同步
cron.schedule('0 2 * * *', () => {
  console.log('开始定时增量同步...');
  main();
});
```

---

## 📁 相关文件

| 文件/表 | 说明 |
|---------|------|
| `scripts/sync_organize_dept.js` | 主同步脚本 |
| `docs/ORGANIZE_DEPT_SYNC_GUIDE.md` | 本执行指南 |
| `go_chat.organize_dept` | 目标表 |
| `go_chat._dept_id_mapping` | ID映射表（自动创建） |
| `go_chat._backup_history` | 备份历史记录表（自动创建） |
| `go_chat.organize_dept_backup_*` | 备份表（按时间戳自动命名） |
