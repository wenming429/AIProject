# UDMOrganization → OrganizeDept 数据同步方案（基于ID映射）

> 更新时间: 2026-04-05

---

## 一、ID映射同步原理

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ID 映射同步机制                                    │
└─────────────────────────────────────────────────────────────────────────────┘

  SQL Server (UDMOrganization)              MySQL (organize_dept)
  ┌──────────────────────────┐            ┌──────────────────────────┐
  │ ID (GUID)                │            │ dept_id (INT AUTO)      │
  │ ├─ xxx-001             │            │ ├─ 1                    │
  │ ├─ xxx-002 (父)        │            │ ├─ 2 (父)                │
  │ └─ xxx-003              │            │ └─ 3                    │
  └──────────────────────────┘            └──────────────────────────┘
           │                                        │
           ▼                                        ▼
  ┌──────────────────────────┐            ┌──────────────────────────┐
  │ _dept_id_mapping         │            │ 父子关系通过parent_id      │
  │ source_id → target_id   │            │ 关联                      │
  │ xxx-001→1, xxx-002→2...│            │                          │
  └──────────────────────────┘            └──────────────────────────┘
```

---

## 二、完整同步SQL脚本

### Step 1: 创建ID映射表

```sql
-- 创建部门ID映射表
DROP TABLE IF EXISTS `_dept_id_mapping`;
CREATE TABLE `_dept_id_mapping` (
    `source_id`      VARCHAR(36) NOT NULL COMMENT '源系统GUID',
    `target_id`      INT UNSIGNED NOT NULL COMMENT '目标系统自增ID',
    `parent_source`  VARCHAR(36) DEFAULT NULL COMMENT '源系统父部门GUID',
    `fullname`       VARCHAR(300) DEFAULT NULL COMMENT '部门全名',
    `fullpathcode`   VARCHAR(500) DEFAULT NULL COMMENT '完整路径编码',
    `created_at`     DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`source_id`),
    KEY `idx_target_id` (`target_id`),
    KEY `idx_parent_source` (`parent_source`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='部门ID映射表';
```

### Step 2: 同步数据（核心逻辑）

```sql
-- ================================================================
-- UDMOrganization → OrganizeDept 同步脚本
-- ================================================================

-- 1. 清空目标表和映射表（首次全量同步）
TRUNCATE TABLE `organize_dept`;
TRUNCATE TABLE `_dept_id_mapping`;

-- 重置自增ID
ALTER TABLE `organize_dept` AUTO_INCREMENT = 1;

-- 2. 插入基础数据
-- 关键：按 FULLPATHCODE 排序确保父节点先处理

INSERT INTO `organize_dept` (
    dept_name, short_name, order_num, status, is_deleted,
    created_at, updated_at
)
SELECT 
    o.FULLNAME,
    o.SHORTNAME,
    COALESCE(o.SORT, 1),
    1,  -- status: 正常
    CASE WHEN o.ISDEL = 1 THEN 1 ELSE 2 END,  -- is_deleted
    COALESCE(o.CREATETIME, NOW()),
    COALESCE(o.UPDATETIME, NOW())
FROM `UDMOrganization` o
WHERE o.ISDEL = 0
ORDER BY o.FULLPATHCODE, o.SORT;

-- 3. 生成ID映射关系
-- 注意：假设FULLNAME唯一，或者需要添加其他唯一条件

INSERT INTO `_dept_id_mapping` (source_id, target_id, parent_source, fullname, fullpathcode)
SELECT 
    o.ID,
    d.dept_id,
    o.PARENTID,
    o.FULLNAME,
    o.FULLPATHCODE
FROM `UDMOrganization` o
INNER JOIN `organize_dept` d 
    ON d.dept_name = o.FULLNAME 
    AND d.is_deleted = CASE WHEN o.ISDEL = 1 THEN 1 ELSE 2 END
WHERE o.ISDEL = 0;

-- 4. 更新父子关系
UPDATE `organize_dept` d
INNER JOIN `_dept_id_mapping` m ON d.dept_id = m.target_id
LEFT JOIN `_dept_id_mapping` pm ON pm.source_id = m.parent_source
SET d.parent_id = IFNULL(pm.target_id, 0)
WHERE m.parent_source IS NOT NULL;

-- 5. 重建 ancestors 路径
-- 5.1 顶级部门
UPDATE `organize_dept`
SET ancestors = CONCAT('0/', dept_id)
WHERE parent_id = 0 AND ancestors = '';

-- 5.2 子部门
UPDATE `organize_dept` d
INNER JOIN `_dept_id_mapping` m ON d.dept_id = m.target_id
INNER JOIN `_dept_id_mapping` pm ON pm.target_id = d.parent_id
SET d.ancestors = CONCAT(pm.ancestors, '/', d.dept_id)
WHERE d.parent_id > 0;

-- 6. 验证结果
SELECT '同步完成' AS status;
SELECT COUNT(*) AS total_depts FROM `organize_dept`;
SELECT SUM(parent_id = 0) AS root_count, SUM(parent_id > 0) AS child_count FROM `organize_dept`;
```

---

## 三、增量同步存储过程

```sql
DELIMITER //

DROP PROCEDURE IF EXISTS `sync_dept_incremental` //

CREATE PROCEDURE `sync_dept_incremental`(IN last_sync_time DATETIME)
BEGIN
    DECLARE v_count INT DEFAULT 0;

    START TRANSACTION;

    -- 1. 新增数据
    INSERT INTO `organize_dept` (
        dept_name, short_name, order_num, status, is_deleted,
        created_at, updated_at
    )
    SELECT 
        o.FULLNAME,
        o.SHORTNAME,
        COALESCE(o.SORT, 1),
        1,
        2,
        COALESCE(o.CREATETIME, NOW()),
        COALESCE(o.UPDATETIME, NOW())
    FROM `UDMOrganization` o
    LEFT JOIN `_dept_id_mapping` m ON m.source_id = o.ID
    WHERE o.UPDATETIME > last_sync_time
      AND o.ISDEL = 0
      AND m.source_id IS NULL;

    -- 2. 记录新增映射
    INSERT INTO `_dept_id_mapping` (source_id, target_id, parent_source, fullname, fullpathcode)
    SELECT 
        o.ID,
        d.dept_id,
        o.PARENTID,
        o.FULLNAME,
        o.FULLPATHCODE
    FROM `UDMOrganization` o
    INNER JOIN `organize_dept` d ON d.dept_name = o.FULLNAME
    WHERE o.UPDATETIME > last_sync_time
      AND o.ISDEL = 0
      AND NOT EXISTS (
          SELECT 1 FROM `_dept_id_mapping` m WHERE m.source_id = o.ID
      );

    -- 3. 更新数据
    UPDATE `organize_dept` d
    INNER JOIN `_dept_id_mapping` m ON d.dept_id = m.target_id
    INNER JOIN `UDMOrganization` o ON o.ID = m.source_id
    SET 
        d.dept_name = o.FULLNAME,
        d.short_name = o.SHORTNAME,
        d.order_num = COALESCE(o.SORT, 1),
        d.updated_at = COALESCE(o.UPDATETIME, NOW())
    WHERE o.UPDATETIME > last_sync_time
      AND o.ISDEL = 0;

    -- 4. 处理删除
    UPDATE `organize_dept` d
    INNER JOIN `_dept_id_mapping` m ON d.dept_id = m.target_id
    INNER JOIN `UDMOrganization` o ON o.ID = m.source_id
    SET d.is_deleted = 1
    WHERE o.ISDEL = 1;

    -- 5. 更新父子关系
    UPDATE `organize_dept` d
    INNER JOIN `_dept_id_mapping` m ON d.dept_id = m.target_id
    LEFT JOIN `_dept_id_mapping` pm ON pm.source_id = m.parent_source
    SET d.parent_id = IFNULL(pm.target_id, 0)
    WHERE m.parent_source IS NOT NULL
      AND (d.parent_id != IFNULL(pm.target_id, 0) OR d.parent_id = 0);

    -- 6. 重建 ancestors
    UPDATE `organize_dept` d
    INNER JOIN `_dept_id_mapping` m ON d.dept_id = m.target_id
    INNER JOIN `_dept_id_mapping` pm ON pm.target_id = d.parent_id
    SET d.ancestors = CONCAT(pm.ancestors, '/', d.dept_id)
    WHERE d.parent_id > 0;

    GET DIAGNOSTICS v_count = ROW_COUNT();

    COMMIT;

    SELECT CONCAT('增量同步完成，影响 ', v_count, ' 条记录') AS result;
END //

DELIMITER ;

-- 调用增量同步
CALL sync_dept_incremental('2026-04-05 00:00:00');
```

---

## 四、数据验证SQL

```sql
-- 1. 总览统计
SELECT 
    (SELECT COUNT(*) FROM `organize_dept`) AS 总记录数,
    (SELECT COUNT(*) FROM `organize_dept` WHERE is_deleted = 2) AS 有效部门,
    (SELECT COUNT(*) FROM `organize_dept` WHERE parent_id = 0) AS 顶级部门,
    (SELECT COUNT(*) FROM `organize_dept` WHERE is_deleted = 1) AS 已删除;

-- 2. 孤儿记录检测
SELECT d.* FROM `organize_dept` d
WHERE d.parent_id != 0
AND d.parent_id NOT IN (SELECT dept_id FROM `organize_dept` WHERE is_deleted = 2);

-- 3. 循环引用检测
SELECT * FROM `organize_dept`
WHERE FIND_IN_SET(dept_id, ancestors) > 0;

-- 4. ID映射验证
SELECT 
    m.source_id AS 源GUID,
    m.target_id AS 目标ID,
    d.dept_name,
    d.parent_id,
    d.ancestors
FROM `_dept_id_mapping` m
LEFT JOIN `organize_dept` d ON d.dept_id = m.target_id
ORDER BY d.ancestors
LIMIT 20;

-- 5. 层级结构预览
SELECT 
    dept_id,
    parent_id,
    dept_name,
    REPEAT('  ', LENGTH(ancestors) - LENGTH(REPLACE(ancestors, '/', '')) - 1) AS 层级,
    ancestors
FROM `organize_dept`
WHERE is_deleted = 2
ORDER BY ancestors
LIMIT 30;
```

---

## 五、字段映射表

| organize_dept | UDMOrganization | 数据类型转换 | 说明 |
|---------------|----------------|-------------|------|
| `dept_id` | **自增生成** | INT UNSIGNED | 新生成的自增主键 |
| `parent_id` | `PARENTID` → 映射转换 | INT UNSIGNED | 通过 `_dept_id_mapping` 表转换 |
| `dept_name` | `FULLNAME` | VARCHAR(64) | 直接映射 |
| `short_name` | `SHORTNAME` | VARCHAR(50) | 直接映射 |
| `ancestors` | `FULLPATHCODE` → 重建 | VARCHAR(128) | 使用 target_id 重建 |
| `order_num` | `SORT` | INT UNSIGNED | 直接映射 |
| `leader` | - | - | 空 |
| `phone` | - | - | 空 |
| `email` | - | - | 空 |
| `status` | - | - | 固定值 1 |
| `is_deleted` | `ISDEL` | TINYINT | 0→2, 1→1 |
| `created_at` | `CREATETIME` | DATETIME | 格式统一 |
| `updated_at` | `UPDATETIME` | DATETIME | 格式统一 |

---

## 六、同步要点总结

| 步骤 | 操作 | 说明 |
|------|------|------|
| 1 | 创建 `_dept_id_mapping` | 存储 GUID → INT 映射 |
| 2 | 按 `FULLPATHCODE` 排序插入 | 确保父节点先处理 |
| 3 | 生成 ID 映射关系 | source_id ↔ target_id |
| 4 | 更新 `parent_id` | 基于映射表关联 |
| 5 | 重建 `ancestors` | 0/父ID/子ID/... 格式 |
| 6 | 数据验证 | 检查孤儿记录和循环引用 |

---

*文档由 LumenIM 项目提供*
