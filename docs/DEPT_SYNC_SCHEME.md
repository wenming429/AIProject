# UDMOrganization → OrganizeDept 数据同步方案

> 文档版本: v1.0
> 更新时间: 2026-04-05

---

## 一、数据源与目标表结构

### 1.1 源表：SQL Server UDMOrganization

```sql
-- 假设的源表结构（实际以业务系统为准）
CREATE TABLE UDMOrganization (
    ID              VARCHAR(36) PRIMARY KEY,      -- 部门ID
    PARENTID        VARCHAR(36) NULL,              -- 父部门ID
    FULLNAME        VARCHAR(300) NOT NULL,         -- 部门全名
    SHORTNAME       VARCHAR(50) NULL,               -- 部门简称
    FULLPATHCODE    VARCHAR(500) NULL,              -- 完整路径编码
    SORT            INT DEFAULT 1,                  -- 排序
    ISDEL           INT DEFAULT 0,                 -- 是否删除 (0=正常,1=删除)
    CREATETIME      DATETIME NULL,                 -- 创建时间
    UPDATETIME      DATETIME NULL,                 -- 更新时间
    CREATEUSERID    VARCHAR(36) NULL,              -- 创建人
    UPDATEUSERID    VARCHAR(36) NULL               -- 更新人
);
```

### 1.2 目标表：MySQL organize_dept

```sql
CREATE TABLE `organize_dept` (
    `dept_id`    INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '部门ID',
    `parent_id`  INT UNSIGNED NOT NULL DEFAULT '0' COMMENT '父部门ID',
    `dept_name`  VARCHAR(64) NOT NULL DEFAULT '' COMMENT '部门名称',
    `short_name` VARCHAR(50) DEFAULT NULL COMMENT '部门简称',
    `ancestors`  VARCHAR(128) NOT NULL DEFAULT '' COMMENT '祖级列表',
    `order_num`  INT UNSIGNED NOT NULL DEFAULT '1' COMMENT '显示顺序',
    `leader`     VARCHAR(64) NOT NULL COMMENT '负责人',
    `phone`      VARCHAR(11) NOT NULL COMMENT '联系电话',
    `email`      VARCHAR(64) NOT NULL COMMENT '邮箱',
    `status`     TINYINT NOT NULL DEFAULT '1' COMMENT '部门状态[1:正常;2:停用]',
    `is_deleted` TINYINT UNSIGNED NOT NULL DEFAULT '2' COMMENT '是否删除[1:是;2:否;]',
    `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
    PRIMARY KEY (`dept_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='部门表';
```

---

## 二、字段映射设计

| 目标字段 | 源字段 | 数据类型转换 | 说明 |
|---------|--------|-------------|------|
| `dept_id` | 自增生成 | VARCHAR(36) → INT UNSIGNED | 目标表使用自增ID |
| `parent_id` | PARENTID | VARCHAR(36) → INT UNSIGNED | 通过映射表转换 |
| `dept_name` | FULLNAME | VARCHAR(300) → VARCHAR(64) | 截断处理 |
| `short_name` | SHORTNAME | VARCHAR(50) → VARCHAR(50) | 直接映射 |
| `ancestors` | FULLPATHCODE | VARCHAR(500) → VARCHAR(128) | ID映射后重建 |
| `order_num` | SORT | INT → INT UNSIGNED | 直接映射 |
| `status` | ISDEL | INT → TINYINT | 0→1, 其他→2 |
| `is_deleted` | ISDEL | INT → TINYINT | 0→2, 1→1 |
| `created_at` | CREATETIME | DATETIME → DATETIME | 格式统一 |
| `updated_at` | UPDATETIME | DATETIME → DATETIME | 格式统一 |

### 2.1 ID转换映射表设计

```sql
-- 创建ID映射表（临时）
CREATE TABLE `_dept_id_mapping` (
    `source_id`    VARCHAR(36) NOT NULL COMMENT '源系统部门ID',
    `target_id`    INT UNSIGNED NOT NULL COMMENT '目标系统部门ID',
    `fullpathcode` VARCHAR(500) DEFAULT NULL COMMENT '转换后的路径编码',
    `fullname`     VARCHAR(300) DEFAULT NULL COMMENT '部门全名',
    `created_at`   DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`source_id`),
    KEY `idx_target_id` (`target_id`),
    KEY `idx_fullpathcode` (`fullpathcode`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

---

## 三、同步策略

### 3.1 同步模式

| 模式 | 说明 | 适用场景 |
|-----|------|---------|
| **全量同步** | 清空目标表数据，重新导入 | 初次部署、数据严重不一致 |
| **增量同步** | 基于更新时间字段同步变化数据 | 日常维护、数据一致性要求高 |
| **混合同步** | 全量同步后切换增量同步 | 最佳实践 |

### 3.2 同步流程图

```
┌─────────────────────────────────────────────────────────────────┐
│                        同步流程                                   │
└─────────────────────────────────────────────────────────────────┘

    ┌─────────────────┐
    │  1. 连接数据库   │
    └────────┬────────┘
             ▼
    ┌─────────────────┐
    │  2. 创建ID映射表 │
    └────────┬────────┘
             ▼
    ┌─────────────────┐
    │  3. 读取源数据   │◄──────────────┐
    │  (按路径排序)    │               │
    └────────┬────────┘               │
             ▼                        │
    ┌─────────────────┐               │
    │  4. 批量插入     │               │ 循环处理
    │  生成target_id   │               │ 每条记录
    └────────┬────────┘               │
             ▼                        │
    ┌─────────────────┐               │
    │  5. 更新parent_id│───────────────┘
    │  (基于ID映射)    │
    └────────┬────────┘
             ▼
    ┌─────────────────┐
    │  6. 重建ancestors│
    │  (使用target_id) │
    └────────┬────────┘
             ▼
    ┌─────────────────┐
    │  7. 数据验证     │
    └────────┬────────┘
             ▼
    ┌─────────────────┐
    │  8. 记录同步时间 │
    │  9. 清理临时表   │
    └─────────────────┘
```

---

## 四、数据一致性保障机制

### 4.1 事务保障

```sql
-- 所有操作在事务中执行
START TRANSACTION;

-- 批量插入
INSERT INTO organize_dept (...) VALUES (...);
INSERT INTO organize_dept (...) VALUES (...);

-- 更新父子关系
UPDATE organize_dept SET parent_id = ? WHERE dept_id = ?;

-- 提交或回滚
COMMIT;
-- 或
-- ROLLBACK;
```

### 4.2 唯一性约束

```sql
-- 确保不存在重复的源ID
INSERT IGNORE INTO `_dept_id_mapping` (source_id, target_id)
SELECT ID, @id:=@id+1 FROM UDMOrganization, (SELECT @id:=0) t;
```

### 4.3 层级关系验证

```sql
-- 检查孤儿记录
SELECT d.* FROM organize_dept d
WHERE d.parent_id != 0
AND d.parent_id NOT IN (
    SELECT dept_id FROM organize_dept 
    WHERE is_deleted = 2
);

-- 检查循环引用
SELECT * FROM organize_dept
WHERE FIND_IN_SET(dept_id, ancestors) > 0;
```

### 4.4 数据校验清单

- [ ] 记录总数一致
- [ ] 有效记录数正确
- [ ] 父子关系完整
- [ ] 无孤儿节点
- [ ] 无循环引用
- [ ] ancestors 路径正确

---

## 五、ID转换核心逻辑

### 5.1 双通道插入法

```
原始ID:     A(顶级)  →  B(属于A)  →  C(属于B)  →  D(属于C)
                    │           │           │
                    ▼           ▼           ▼
源FULLPATH: ''      A           A/B         A/B/C
                    │           │           │
                    ▼           ▼           ▼
target_id:  1        2           3           4
                    │           │           │
                    ▼           ▼           ▼
新ancestors: 0/1     0/1/2       0/1/2/3     0/1/2/3/4
```

### 5.2 映射表存储

```sql
-- 源数据
ID       PARENTID  FULLPATHCODE
10001    NULL      ''
10002    10001     '10001'
10003    10002     '10001/10002'

-- 插入后映射表
source_id    target_id    fullpathcode
10001        1           0/1
10002        2           0/1/2
10003        3           0/1/2/3

-- 更新 parent_id
UPDATE organize_dept d
JOIN _dept_id_mapping m ON d.dept_id = m.target_id
JOIN _dept_id_mapping pm ON pm.source_id = (SELECT PARENTID FROM UDMOrganization WHERE ID = m.source_id)
SET d.parent_id = pm.target_id
WHERE m.source_id IN (SELECT ID FROM UDMOrganization WHERE PARENTID IS NOT NULL);
```

---

## 六、增量同步SQL实现

### 6.1 获取增量数据

```sql
-- 获取指定时间后的更新数据
SELECT 
    ID, PARENTID, FULLNAME, SHORTNAME,
    FULLPATHCODE, SORT, ISDEL, 
    CREATETIME, UPDATETIME
FROM UDMOrganization
WHERE UPDATETIME > '2026-04-05 00:00:00'
ORDER BY UPDATETIME;
```

### 6.2 处理增量数据

```sql
-- 增量同步存储过程
DELIMITER //

CREATE PROCEDURE sync_dept_incremental(IN last_sync_time DATETIME)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERROR: Sync failed' AS result;
    END;
    
    START TRANSACTION;
    
    -- 处理新增和更新
    INSERT INTO organize_dept (
        dept_name, short_name, ancestors, order_num,
        status, is_deleted, created_at, updated_at
    )
    SELECT 
        FULLNAME, SHORTNAME, FULLPATHCODE, SORT,
        1 AS status, 2 AS is_deleted,
        CREATETIME, UPDATETIME
    FROM UDMOrganization
    WHERE UPDATETIME > last_sync_time
    AND ID NOT IN (SELECT source_id FROM _dept_id_mapping)
    ON DUPLICATE KEY UPDATE
        dept_name = VALUES(dept_name),
        short_name = VALUES(short_name),
        order_num = VALUES(order_num),
        updated_at = VALUES(updated_at);
    
    -- 处理删除（如果需要）
    UPDATE organize_dept d
    JOIN _dept_id_mapping m ON d.dept_id = m.target_id
    JOIN UDMOrganization o ON o.ID = m.source_id
    SET d.is_deleted = 1
    WHERE o.ISDEL = 1;
    
    -- 记录同步时间
    INSERT INTO sync_log (table_name, last_sync_time) 
    VALUES ('organize_dept', NOW())
    ON DUPLICATE KEY UPDATE last_sync_time = NOW();
    
    COMMIT;
    
    SELECT CONCAT('OK: ', ROW_COUNT(), ' rows synced') AS result;
END //

DELIMITER ;

-- 调用增量同步
CALL sync_dept_incremental('2026-04-05 00:00:00');
```

---

## 七、完整同步脚本

### 7.1 完整SQL脚本

```sql
-- ============================================
-- UDMOrganization -> OrganizeDept 完整同步
-- ============================================

-- Step 1: 创建临时ID映射表
DROP TABLE IF EXISTS `_dept_id_mapping`;
CREATE TABLE `_dept_id_mapping` (
    `source_id`    VARCHAR(36) NOT NULL,
    `target_id`    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `fullname`     VARCHAR(300) DEFAULT NULL,
    `parent_source_id` VARCHAR(36) DEFAULT NULL,
    `ancestors`    VARCHAR(500) DEFAULT NULL,
    PRIMARY KEY (`source_id`),
    KEY `idx_target_id` (`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Step 2: 清空目标表（可选，全量同步时）
-- TRUNCATE TABLE `organize_dept`;

-- Step 3: 设置ID自增起始值
ALTER TABLE `organize_dept` AUTO_INCREMENT = 1;

-- Step 4: 批量插入基础数据
INSERT INTO `organize_dept` (
    dept_name, short_name, ancestors, order_num,
    status, is_deleted, created_at, updated_at
)
SELECT 
    o.FULLNAME AS dept_name,
    o.SHORTNAME AS short_name,
    COALESCE(o.FULLPATHCODE, '') AS ancestors,
    COALESCE(o.SORT, 1) AS order_num,
    1 AS status,
    CASE WHEN o.ISDEL = 1 THEN 1 ELSE 2 END AS is_deleted,
    COALESCE(o.CREATETIME, NOW()) AS created_at,
    COALESCE(o.UPDATETIME, NOW()) AS updated_at
FROM UDMOrganization o
WHERE o.ISDEL = 0
ORDER BY o.FULLPATHCODE, o.SORT;

-- Step 5: 生成ID映射
INSERT INTO `_dept_id_mapping` (source_id, target_id, fullname, parent_source_id, ancestors)
SELECT 
    o.ID AS source_id,
    d.dept_id AS target_id,
    o.FULLNAME AS fullname,
    o.PARENTID AS parent_source_id,
    COALESCE(o.FULLPATHCODE, '') AS ancestors
FROM UDMOrganization o
JOIN `organize_dept` d ON d.dept_name = o.FULLNAME 
    AND COALESCE(d.updated_at, d.created_at) = COALESCE(o.UPDATETIME, o.CREATETIME, NOW())
WHERE o.ISDEL = 0;

-- Step 6: 更新父子关系
UPDATE `organize_dept` d
JOIN `_dept_id_mapping` m ON d.dept_id = m.target_id
LEFT JOIN `_dept_id_mapping` pm ON pm.source_id = m.parent_source_id
SET d.parent_id = COALESCE(pm.target_id, 0)
WHERE m.parent_source_id IS NOT NULL;

-- Step 7: 重建ancestors路径
UPDATE `organize_dept` d
JOIN `_dept_id_mapping` m ON d.dept_id = m.target_id
LEFT JOIN `_dept_id_mapping` pm ON pm.target_id = d.parent_id
SET d.ancestors = CONCAT(COALESCE(pm.ancestors, '0'), '/', d.dept_id)
WHERE d.parent_id != 0;

-- 顶级部门的ancestors
UPDATE `organize_dept`
SET ancestors = CONCAT('0/', dept_id)
WHERE parent_id = 0 AND ancestors NOT LIKE '0/%';

-- Step 8: 验证数据
SELECT 
    COUNT(*) AS total,
    SUM(parent_id = 0) AS root_depts,
    SUM(parent_id != 0) AS child_depts
FROM `organize_dept` WHERE is_deleted = 2;

-- Step 9: 查看层级结构
SELECT 
    dept_id, 
    parent_id, 
    dept_name, 
    ancestors,
    LEVEL
FROM (
    SELECT 
        dept_id,
        parent_id,
        dept_name,
        ancestors,
        (LENGTH(ancestors) - LENGTH(REPLACE(ancestors, '/', ''))) AS LEVEL
    FROM `organize_dept`
    WHERE is_deleted = 2
) t
ORDER BY ancestors
LIMIT 20;

-- Step 10: 清理（保留映射表用于后续增量同步）
-- DROP TABLE IF EXISTS `_dept_id_mapping`;
```

---

## 八、调度策略建议

### 8.1 增量同步调度

| 同步类型 | 调度周期 | 说明 |
|---------|---------|------|
| 全量同步 | 每周日凌晨2点 | 数据量较小时使用 |
| 增量同步 | 每小时 | 实时性要求高 |
| 增量同步 | 每日凌晨 | 实时性要求一般 |

### 8.2 监控告警

```sql
-- 同步异常检测
SELECT 
    m.source_id,
    d.dept_name,
    m.fullname AS source_name,
    CASE 
        WHEN d.dept_id IS NULL THEN '仅源系统存在'
        WHEN d.is_deleted = 1 THEN '仅目标系统已删除'
        ELSE '数据不一致'
    END AS status
FROM _dept_id_mapping m
LEFT JOIN `organize_dept` d ON d.dept_id = m.target_id
WHERE d.dept_id IS NULL 
   OR d.dept_name != m.fullname
   OR d.is_deleted = 1;
```

---

## 九、注意事项

1. **ID转换不可逆**: 源系统varchar(36)转目标系统int自增，映射关系必须保存
2. **路径依赖**: ancestors字段依赖ID映射，必须在插入后重建
3. **事务完整性**: 批量操作必须在事务中执行，确保数据一致性
4. **增量时间戳**: 源表必须有UPDATETIME字段支持增量同步
5. **并发控制**: 同步过程中应锁定相关表或使用互斥机制
6. **数据回滚**: 建议同步前备份目标表数据

---

*文档由 LumenIM 项目提供*
