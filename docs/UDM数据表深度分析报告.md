# UDM数据表深度分析报告

## 一、表概览

| 表名 | 中文名 | 记录数 | 主键类型 | 说明 |
|------|--------|--------|----------|------|
| `udmorganization` | 组织架构表 | 13,488 | VARCHAR(38) | 部门/组织树形结构 |
| `udmbusinessunit` | 业务单元表 | 100 | VARCHAR(38) | 公司/业务单元 |
| `udmuser` | 用户/员工表 | 104,438 | VARCHAR(38) | 员工基本信息 |
| `udmjob` | 任职关系表 | 522,928 | VARCHAR(38) | 员工-组织-岗位任职记录 |
| `udmjobinfo` | 职位信息表 | 1,244 | VARCHAR(38) | 职位（职务）定义 |
| `udmposition` | 岗位表 | 24,495 | VARCHAR(38) | 岗位（职位在组织中的实例） |

---

## 二、详细表结构

### 1. udmorganization（组织架构表）

| 字段名 | 数据类型 | 约束 | 说明 |
|--------|----------|------|------|
| ID | VARCHAR(38) | **PK, NOT NULL** | 组织唯一标识(GUID) |
| PARENTID | VARCHAR(38) | NULL | 父级组织ID（自引用） |
| SETID | VARCHAR(15) | NULL | 集合标识 |
| DEPTID | VARCHAR(38) | NULL | 部门ID |
| FULLNAME | VARCHAR(90) | NULL | 组织全称 |
| SHORTNAME | VARCHAR(90) | NULL | 组织简称 |
| EFFECTIVEDATE | DATETIME(3) | NULL | 生效日期 |
| EFFECTIVESTATUS | VARCHAR(1) | NULL | 生效状态(I=无效,A=有效?) |
| ISINTREE | VARCHAR(3) | NULL | 是否在树中 |
| MANAGERID | VARCHAR(36) | NULL | 管理者用户ID |
| MANAGERPOSITIONID | VARCHAR(36) | NULL | 管理者岗位ID |
| DEPARTMENTCLASS | VARCHAR(3) | NULL | 部门分类 |
| DATASOURCE | INT | NULL | 数据来源(0=原系统,1=新导入) |
| FULLPATHCODE | VARCHAR(500) | NULL | 层级路径编码(如:0/1/2/3) |
| FULLPATHTEXT | VARCHAR(500) | NULL | 层级路径文本 |
| INNERORDER | DOUBLE | NULL | 显示排序 |
| DICTORGTYPE | VARCHAR(38) | NULL | 组织类型字典 |
| MASTERDATA_BATCHTIME | DATETIME(3) | NULL | 主数据批次时间 |
| MASTERDATA_DATASTATUS | VARCHAR(1) | NULL | 主数据状态 |
| MASTERDATA_RESULT | VARCHAR(50) | NULL | 主数据结果 |

**索引：** PRIMARY (ID)

---

### 2. udmbusinessunit（业务单元表）

| 字段名 | 数据类型 | 约束 | 说明 |
|--------|----------|------|------|
| ID | VARCHAR(38) | **PK, NOT NULL** | 业务单元唯一标识 |
| BUSINESS_UNIT | VARCHAR(38) | NULL | 上级业务单元ID |
| BUNAME | VARCHAR(180) | NULL | 业务单元名称 |
| ORDERBY | VARCHAR(30) | NULL | 排序 |
| MASTERDATA_BATCHTIME | DATETIME(3) | NULL | 主数据批次时间 |
| MASTERDATA_DATASTATUS | VARCHAR(1) | NULL | 主数据状态 |
| MASTERDATA_RESULT | VARCHAR(50) | NULL | 主数据结果 |

**索引：** PRIMARY (ID)

---

### 3. udmuser（用户/员工表）

| 字段名 | 数据类型 | 约束 | 说明 |
|--------|----------|------|------|
| ID | VARCHAR(38) | **PK, NOT NULL** | 用户唯一标识 |
| EEMPLOYEEID | VARCHAR(38) | NULL | 员工工号 |
| FIRSTNAME | VARCHAR(90) | NULL | 名 |
| LASTNAME | VARCHAR(90) | NULL | 姓 |
| FULLNAME | VARCHAR(180) | NULL | 姓名 |
| GENDER | VARCHAR(3) | NULL | 性别 |
| BIRTHDAY | DATETIME(3) | NULL | 生日 |
| EMAIL | VARCHAR(250) | NULL | 邮箱 |
| HOMEADDRESS | VARCHAR(7) | NULL | 家庭地址 |
| HOMEPHONE | VARCHAR(72) | NULL | 家庭电话 |
| OFFICEPHONE | VARCHAR(72) | NULL | 办公电话 |
| PHONE | VARCHAR(72) | NULL | 手机号 |
| LOGINNAME | VARCHAR(90) | **MUL** | 登录名(有索引) |
| COUNTRYCODE | VARCHAR(9) | NULL | 国家代码 |
| IDCARDTYPE | VARCHAR(18) | NULL | 证件类型 |
| IDCARDNUMBER | VARCHAR(18) | NULL | 证件号码 |
| ORDERBY | VARCHAR(30) | NULL | 排序 |
| HIRETIME | DATETIME(3) | NULL | 入职时间 |
| HIREAREA | VARCHAR(90) | NULL | 入职区域 |
| DICTPERSONTYPE | INT | NULL | 人员类型字典 |
| DICTPERSONPUSHTO | VARCHAR(50) | NULL | 推送目标 |
| DATASOURCE | INT | NULL | 数据来源 |
| HX_CQT_SW | VARCHAR(1) | NULL | 华夏幸福字段 |
| HX_CDL_SW | VARCHAR(1) | NULL | 华夏幸福字段 |
| HX_YEAR | VARCHAR(4) | NULL | 年份 |
| REG_REGION | VARCHAR(5) | NULL | 地区编码 |
| REG_REGION_DESCR | VARCHAR(60) | NULL | 地区描述 |
| MASTERDATA_BATCHTIME | DATETIME(3) | NULL | 主数据批次时间 |
| MASTERDATA_DATASTATUS | VARCHAR(1) | NULL | 主数据状态 |
| MASTERDATA_RESULT | VARCHAR(50) | NULL | 主数据结果 |

**索引：** 
- PRIMARY (ID)
- idx_udmuser_loginname (LOGINNAME)

---

### 4. udmjob（任职关系表 - 核心关联表）

| 字段名 | 数据类型 | 约束 | 说明 |
|--------|----------|------|------|
| ID | VARCHAR(38) | **PK, NOT NULL** | 任职记录唯一标识 |
| USERID | VARCHAR(38) | NULL | 用户ID (→udmuser.ID) |
| JOBORDER | DOUBLE | NULL | 任职排序 |
| EFFECTIVEDATE | DATETIME(3) | NULL | 生效日期 |
| EFFECTIVENUMBER | DOUBLE | NULL | 生效人数 |
| ORGANIZATIONID | VARCHAR(38) | NULL | 组织ID (→udmorganization.ID) |
| ORGANIZATIONNAME | VARCHAR(90) | NULL | 组织名称 |
| JOBINFOID | VARCHAR(38) | NULL | 职位信息ID (→udmjobinfo.ID) |
| JOBINFONAME | VARCHAR(90) | NULL | 职位名称 |
| POSITIONID | VARCHAR(38) | NULL | 岗位ID (→udmposition.ID) |
| POSITIONNAME | VARCHAR(90) | NULL | 岗位名称 |
| JOBINDICATE | VARCHAR(3) | NULL | 任职指示 |
| JOBACTION | VARCHAR(9) | NULL | 任职操作 |
| JOBACTIONREASON | VARCHAR(9) | NULL | 操作原因 |
| DATASTATUS | INT | NULL | 数据状态 |
| DICTPOSITIONSTATUS | VARCHAR(1) | NULL | 岗位状态字典 |
| LOCATIONCODE | VARCHAR(30) | NULL | 地点编码 |
| LOCATIONNAME | VARCHAR(90) | NULL | 地点名称 |
| MANAGERID | VARCHAR(36) | NULL | 上级用户ID (→udmuser.ID) |
| MANAGERPOSITIONID | VARCHAR(36) | NULL | 上级岗位ID (→udmposition.ID) |
| EMPLOYEECLASS | VARCHAR(9) | NULL | 员工类别 |
| EMPLOYEECATALOG | VARCHAR(9) | NULL | 员工目录 |
| MAINBUSINESS | VARCHAR(6) | NULL | 主营业 |
| STOCKSEQUE | VARCHAR(18) | NULL | 股票序列 |
| STOCKSEQUEDESCR | VARCHAR(90) | NULL | 股票序列描述 |
| STOCKRANK | VARCHAR(18) | NULL | 股票级别 |
| STOCKRANKDESCR | VARCHAR(90) | NULL | 股票级别描述 |
| DATASOURCE | INT | NULL | 数据来源 |
| EMPLOYEEJOINT | VARCHAR(1) | NULL | 员工关节 |
| EMPLOYEEJOINTD | VARCHAR(30) | NULL | 员工关节描述 |
| MASTERDATA_BATCHTIME | DATETIME(3) | NULL | 主数据批次时间 |
| MASTERDATA_DATASTATUS | VARCHAR(1) | NULL | 主数据状态 |
| MASTERDATA_RESULT | VARCHAR(50) | NULL | 主数据结果 |

**索引：** PRIMARY (ID)

---

### 5. udmjobinfo（职位信息表）

| 字段名 | 数据类型 | 约束 | 说明 |
|--------|----------|------|------|
| ID | VARCHAR(38) | **PK, NOT NULL** | 职位唯一标识 |
| SETID | VARCHAR(38) | NULL | 集合ID |
| JOBCODE | VARCHAR(38) | NULL | 职位代码 |
| JOBINFONAME | VARCHAR(90) | NULL | 职位名称 |
| JOBINFONAMESHORT | VARCHAR(90) | NULL | 职位简称 |
| EFFECTIVEDATE | DATETIME(3) | NULL | 生效日期 |
| EFFECTIVESTATUS | VARCHAR(3) | NULL | 生效状态 |
| MASTERDATA_BATCHTIME | DATETIME(3) | NULL | 主数据批次时间 |
| MASTERDATA_DATASTATUS | VARCHAR(1) | NULL | 主数据状态 |
| MASTERDATA_RESULT | VARCHAR(50) | NULL | 主数据结果 |

**索引：** PRIMARY (ID)

---

### 6. udmposition（岗位表）

| 字段名 | 数据类型 | 约束 | 说明 |
|--------|----------|------|------|
| ID | VARCHAR(38) | **PK, NOT NULL** | 岗位唯一标识 |
| POSITIONID | VARCHAR(38) | NULL | 岗位代码 |
| POSITIONNAME | VARCHAR(90) | NULL | 岗位名称 |
| JOBINFOID | VARCHAR(38) | NULL | 职位信息ID (→udmjobinfo.ID) |
| ORGANIZATIONID | VARCHAR(38) | NULL | 组织ID (→udmorganization.ID) |
| EFFECTIVEDATE | DATETIME(3) | NULL | 生效日期 |
| EFFECTIVESTATUS | VARCHAR(3) | NULL | 生效状态 |
| MASTERDATA_BATCHTIME | DATETIME(3) | NULL | 主数据批次时间 |
| MASTERDATA_DATASTATUS | VARCHAR(1) | NULL | 主数据状态 |
| MASTERDATA_RESULT | VARCHAR(50) | NULL | 主数据结果 |

**索引：** PRIMARY (ID)

---

## 三、表关系图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              数据模型关系图                                  │
└─────────────────────────────────────────────────────────────────────────────┘

                          ┌─────────────────────┐
                          │   udmbusinessunit   │
                          │    (业务单元表)       │
                          │  ┌───────────────┐  │
                          │  │ ID (PK)       │  │
                          │  │ BUSINESS_UNIT │──┼──→ 递归引用
                          │  └───────────────┘  │
                          └─────────┬───────────┘
                                    │
                                    ▼
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│    udmjobinfo       │    │  udmorganization    │    │    udmuser          │
│   (职位信息表)       │    │   (组织架构表)        │    │    (用户/员工表)      │
│ ┌───────────────┐   │    │ ┌───────────────┐   │    │ ┌───────────────┐   │
│ │ ID (PK)       │◀──┼────┼─│ JOBINFOID     │   │    │ │ ID (PK)       │   │
│ └───────────────┘   │    │ └───────────────┘   │    │ │ LOGINNAME (Idx)│  │
│                     │    │       ▲             │    │ └───────────────┘   │
└─────────────────────┘    │       │             │    └─────────┬─────────┘
                           │ ┌─────┴───────────┐ │              │
                           │ │ ID (PK)         │ │              │
                           │ │ PARENTID ────────┼─┘              │
                           │ │ DEPTID           │ │              │
                           │ │ FULLPATHCODE     │ │              │
                           │ │ INNERORDER       │ │              │
                           │ └─────────┬────────┘ │              │
                           └───────────┼──────────┘              │
                                       │                          │
                          ┌────────────┼──────────────────────────┘
                          │            │
                          ▼            ▼
              ┌───────────────────────┐
              │       udmposition      │
              │        (岗位表)         │
              │ ┌─────────────────┐   │
              │ │ ID (PK)         │   │
              │ │ ORGANIZATIONID ─┼───┤
              │ │ JOBINFOID ──────┼───┤
              │ └─────────────────┘   │
              └───────────┬────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                      udmjob (任职关系表)                      │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ ID (PK)                                              │  │
│  │ USERID ──────────────────────────────┐              │  │
│  │ ORGANIZATIONID ──────────────────────┤              │  │
│  │ JOBINFOID ───────────────────────────┤              │  │
│  │ POSITIONID ───────────────────────────┤              │  │
│  │ MANAGERID ────────────────────────────┤              │  │
│  │ MANAGERPOSITIONID ─────────────────────┘              │  │
│  └─────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘

图例：
──▶  外键引用关系
◀──  反向引用
────  多表关联
```

---

## 四、关联关系详解

### 4.1 一对一/一对多关系

| 源表 | 目标表 | 关联字段 | 关系类型 | 说明 |
|------|--------|----------|----------|------|
| udmjob.USERID | udmuser.ID | VARCHAR(38) | **N:1** | 任职记录 → 员工 |
| udmjob.ORGANIZATIONID | udmorganization.ID | VARCHAR(38) | **N:1** | 任职记录 → 组织 |
| udmjob.JOBINFOID | udmjobinfo.ID | VARCHAR(38) | **N:1** | 任职记录 → 职位 |
| udmjob.POSITIONID | udmposition.ID | VARCHAR(38) | **N:1** | 任职记录 → 岗位 |
| udmjob.MANAGERID | udmuser.ID | VARCHAR(36) | **N:1** | 上级用户引用 |
| udmjob.MANAGERPOSITIONID | udmposition.ID | VARCHAR(36) | **N:1** | 上级岗位引用 |
| udmposition.JOBINFOID | udmjobinfo.ID | VARCHAR(38) | **N:1** | 岗位 → 职位 |
| udmposition.ORGANIZATIONID | udmorganization.ID | VARCHAR(38) | **N:1** | 岗位 → 组织 |

### 4.2 自引用关系

| 表名 | 字段 | 引用自身 | 说明 |
|------|------|----------|------|
| udmorganization | PARENTID | ID | 组织树形层级结构 |
| udmbusinessunit | BUSINESS_UNIT | ID | 业务单元层级结构 |

---

## 五、数据流转逻辑

### 5.1 主数据模型层次

```
业务单元 (udmbusinessunit)
    │
    │ 1:N
    ▼
组织架构 (udmorganization) ←──────┐
    │                              │
    │ 1:N                          │
    ▼                              │
岗位 (udmposition)                 │
    │                              │
    │ N:1                          │
    └──────────────────────────────┘
    │
    ▼
职位 (udmjobinfo)
    │
    │ 1:N
    ▼
任职记录 (udmjob) ──────────→ 用户 (udmuser)
```

### 5.2 人员任职关系模型

```
┌──────────┐     N:1     ┌────────────────┐     N:1     ┌────────────────┐
│ udmuser  │◀────────────│     udmjob     │───────────▶│udmorganization │
│  员工    │   任职记录   │   (任职关系)    │            │     组织       │
└──────────┘             └───────┬────────┘            └────────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            │                   │                   │
            ▼                   ▼                   ▼
     ┌────────────┐      ┌────────────┐      ┌────────────┐
     │udmjobinfo  │      │udmposition │      │  udmuser   │
     │   职位     │      │    岗位    │      │ 上级用户   │
     └────────────┘      └────────────┘      └────────────┘
                                │
                                ▼
                         ┌────────────┐
                         │udmposition │
                         │ 上级岗位   │
                         └────────────┘
```

---

## 六、数据统计分析

### 6.1 数据来源分布

| 表名 | DATASOURCE=0 (原系统) | DATASOURCE=1 (新导入) | 说明 |
|------|----------------------|----------------------|------|
| udmuser | 94,987 (91%) | 9,451 (9%) | 员工数据 |
| udmjob | 512,209 (98%) | 10,719 (2%) | 任职记录 |
| udmorganization | 12,990 (96%) | 498 (4%) | 组织架构 |

### 6.2 关键比例分析

| 指标 | 数值 | 说明 |
|------|------|------|
| 用户/任职比 | 1:5 | 每个用户平均有5条任职记录 |
| 职位/岗位比 | 1:20 | 每个职位平均对应20个岗位 |
| 组织/岗位比 | 1:2 | 每个组织平均有2个岗位 |

---

## 七、业务含义

### 7.1 数据模型解读

| 概念 | 表 | 说明 |
|------|-----|------|
| **职位 (JobInfo)** | udmjobinfo | 职务定义，如"项目经理"、"工程师" |
| **岗位 (Position)** | udmposition | 职位在具体组织中的实例 |
| **任职 (Job)** | udmjob | 员工在特定时间担任某岗位的记录 |
| **组织 (Organization)** | udmorganization | 部门/子公司树形结构 |
| **业务单元 (BusinessUnit)** | udmbusinessunit | 业务分类 |

### 7.2 主数据管理字段

所有表都包含以下主数据管理字段：

| 字段 | 说明 |
|------|------|
| MASTERDATA_BATCHTIME | 批次处理时间 |
| MASTERDATA_DATASTATUS | 数据状态标识 |
| MASTERDATA_RESULT | 处理结果描述 |

---

## 八、同步到业务表的建议

基于此数据模型，建议同步以下业务表：

| UDM源表 | 目标业务表 | 同步策略 |
|---------|-----------|----------|
| udmuser | sys_admin / chat_user | 按 LOGINNAME 唯一键同步 |
| udmorganization | organize_dept | 按 FULLPATHCODE 层级同步 |
| udmjobinfo | organize_position | 按 ID 直接同步 |
| udmposition | organize_position | 关联 organization_id |
| udmjob | organize_position | 关联 user_id 和 position_id |

---

*报告生成时间: 2026-04-05*