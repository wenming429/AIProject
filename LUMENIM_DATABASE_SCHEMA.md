# LumenIM go_chat 数据库表结构说明文档

> 文档更新时间：2026-04-05

---

## 一、用户相关表

### 1.1 users - 用户表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 用户ID，主键 |
| **mobile** | varchar(11) | '' | 手机号，唯一键 |
| nickname | varchar(64) | '' | 用户昵称 |
| avatar | varchar(255) | '' | 用户头像 |
| gender | tinyint unsigned | 3 | 性别[1:男;2:女;3:未知] |
| password | varchar(255) | - | 用户密码 |
| motto | varchar(500) | '' | 用户座右铭 |
| email | varchar(30) | '' | 用户邮箱 |
| birthday | varchar(10) | '' | 生日 |
| status | int | 1 | 状态[1:正常;2:停用;3:注销] |
| is_robot | tinyint unsigned | 2 | 是否机器人[1:是;2:否] |
| created_at | datetime | CURRENT_TIMESTAMP | 注册时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 主键(id)，唯一键(uk_mobile)

---

### 1.2 admin - 管理员表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 用户ID，主键 |
| **username** | varchar(20) | - | 用户昵称，唯一键 |
| password | varchar(255) | - | 用户密码 |
| avatar | varchar(255) | '' | 用户头像 |
| gender | tinyint unsigned | 3 | 性别[1:男;2:女;3:未知] |
| mobile | varchar(11) | '' | 手机号 |
| email | varchar(30) | '' | 用户邮箱 |
| motto | varchar(100) | '' | 用户座右铭 |
| last_login_at | datetime | - | 最后一次登录时间 |
| status | tinyint unsigned | 1 | 状态[1:正常;2:停用] |
| created_at | datetime | CURRENT_TIMESTAMP | 注册时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

---

### 1.3 organize - 组织表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 主键ID |
| **user_id** | int unsigned | - | 用户ID |
| **dept_id** | int unsigned | - | 部门ID |
| **position_id** | int unsigned | - | 岗位ID |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

---

### 1.4 organize_dept - 部门表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| **dept_id** | int | AUTO_INCREMENT | 部门ID，主键 |
| **parent_id** | int | 0 | 父部门ID |
| **ancestors** | varchar(128) | '' | 祖级列表 |
| **dept_name** | varchar(64) | '' | 部门名称 |
| **order_num** | int unsigned | 1 | 显示顺序 |
| leader | varchar(64) | - | 负责人 |
| phone | varchar(11) | - | 联系电话 |
| email | varchar(64) | - | 邮箱 |
| status | tinyint | 1 | 状态[1:正常;2:停用] |
| is_deleted | tinyint unsigned | 2 | 是否删除[1:是;2:否] |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

---

### 1.5 organize_position - 岗位信息表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| **position_id** | int | AUTO_INCREMENT | 岗位ID，主键 |
| **post_code** | varchar(32) | - | 岗位编码 |
| **post_name** | varchar(64) | - | 岗位名称 |
| sort | int unsigned | 1 | 显示顺序 |
| status | tinyint unsigned | 1 | 状态[1:正常;2:停用] |
| remark | varchar(255) | '' | 备注 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

---

## 二、好友关系表

### 2.1 contact - 用户好友关系表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| **id** | int unsigned | AUTO_INCREMENT | 关系ID，主键 |
| **user_id** | int unsigned | 0 | 用户ID |
| **friend_id** | int unsigned | 0 | 好友ID |
| remark | varchar(64) | '' | 好友的备注 |
| status | tinyint unsigned | 0 | 好友状态[0:否;1:是] |
| group_id | int unsigned | 0 | 分组ID |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 联合唯一键(uk_user_friend: user_id + friend_id)

---

### 2.2 contact_apply - 用户添加好友申请表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 申请ID，主键 |
| user_id | int unsigned | - | 申请人ID |
| friend_id | int unsigned | - | 被申请人ID |
| remark | varchar(64) | '' | 申请备注 |
| created_at | datetime | CURRENT_TIMESTAMP | 申请时间 |

**索引：** idx_user_id, idx_friend_id

---

### 2.3 contact_group - 联系人分组

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int | AUTO_INCREMENT | 主键ID |
| user_id | int unsigned | - | 用户ID |
| name | varchar(64) | - | 分组名称 |
| sort | int unsigned | 1 | 排序 |
| num | int unsigned | 0 | 成员总数 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 联合唯一键(uk_user_id_name: user_id + name)

---

## 三、群聊相关表

### 3.1 group - 聊天群

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 群ID，主键 |
| type | tinyint unsigned | 1 | 群类型[1:普通群;2:企业群] |
| **name** | varchar(64) | '' | 群名称 |
| profile | varchar(128) | '' | 群介绍 |
| avatar | varchar(255) | '' | 群头像 |
| max_num | smallint unsigned | 200 | 最大群成员数量 |
| is_overt | tinyint unsigned | 2 | 是否公开可见[1:是;2:否] |
| is_mute | tinyint unsigned | 2 | 是否全员禁言[1:是;2:否] |
| is_dismiss | tinyint unsigned | 2 | 是否已解散[1:是;2:否] |
| creator_id | int unsigned | - | 创建者ID(群主ID) |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

---

### 3.2 group_member - 群聊成员

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 主键ID |
| group_id | int unsigned | - | 群组ID |
| user_id | int unsigned | - | 用户ID |
| leader | tinyint unsigned | 3 | 成员属性[1:群主;2:管理员;3:普通成员] |
| user_card | varchar(64) | '' | 群名片 |
| is_quit | tinyint unsigned | 2 | 是否退群[1:是;2:否] |
| is_mute | tinyint unsigned | 2 | 是否禁言[1:是;2:否] |
| join_time | datetime | NULL | 入群时间 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 联合唯一键(uk_group_id_user_id: group_id + user_id)

---

### 3.3 group_apply - 入群申请

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 主键ID |
| group_id | int unsigned | - | 群组ID |
| user_id | int unsigned | - | 用户ID |
| status | tinyint unsigned | 1 | 申请状态[1:待审核;2:已通过;3:不通过] |
| remark | varchar(255) | '' | 备注信息 |
| reason | varchar(255) | '' | 拒绝原因 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 联合索引(idx_group_id_user_id: group_id + user_id)

---

### 3.4 group_notice - 群组公告表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 公告ID |
| group_id | int unsigned | - | 群组ID，唯一键 |
| creator_id | int unsigned | - | 创建者用户ID |
| modify_id | int | - | 修改者ID |
| content | longtext | - | 公告内容 |
| confirm_users | json | NULL | 已确认成员 |
| is_confirm | tinyint unsigned | 1 | 是否需群成员确认公告[1:是;2:否] |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 联合主键(id, modify_id)，唯一键(un_group_id: group_id)

---

### 3.5 group_vote - 群投票表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 投票ID，主键 |
| group_id | int unsigned | - | 群组ID |
| user_id | int unsigned | - | 用户ID(创建人) |
| title | varchar(64) | - | 投票标题 |
| answer_mode | int unsigned | - | 答题模式[1:单选;2:多选] |
| answer_option | json | - | 答题选项 |
| answer_num | int unsigned | 0 | 应答人数 |
| answered_num | int unsigned | 0 | 已答人数 |
| is_anonymous | int unsigned | 2 | 匿名投票[1:是;2:否] |
| status | int unsigned | 1 | 投票状态[1:投票中;2:已完成] |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** idx_groupid

---

### 3.6 group_vote_answer - 投票详情统计表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 答题ID，主键 |
| vote_id | int unsigned | - | 投票ID |
| user_id | int unsigned | - | 用户ID |
| option | char(1) | - | 投票选项[A、B、C、D、E、F] |
| created_at | datetime | CURRENT_TIMESTAMP | 答题时间 |

**索引：** 联合索引(idx_vote_id_user_id: vote_id + user_id)

---

## 四、消息相关表

### 4.1 talk_session - 会话列表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 聊天列表ID，主键 |
| talk_mode | tinyint unsigned | 1 | 聊天类型[1:私信;2:群聊] |
| user_id | int unsigned | 0 | 用户ID |
| to_from_id | int unsigned | - | 接收者ID(用户ID或群ID) |
| is_top | tinyint unsigned | 2 | 是否置顶[1:是;2:否] |
| is_disturb | tinyint unsigned | 2 | 消息免打扰[1:是;2:否] |
| is_delete | tinyint unsigned | 2 | 是否删除[1:是;2:否] |
| is_robot | tinyint unsigned | 2 | 是否机器人[1:是;2:否] |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 联合唯一键(uk_user_id_receiver_id_talk_type: user_id + to_from_id + talk_mode)

---

### 4.2 talk_user_message - 私有消息记录表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | bigint unsigned | AUTO_INCREMENT | 聊天记录ID，主键 |
| msg_id | varchar(64) | - | 消息ID，唯一键 |
| org_msg_id | varchar(64) | - | 原消息ID |
| sequence | bigint | - | 消息时序ID(消息排序) |
| msg_type | int unsigned | 1 | 消息类型 |
| user_id | int unsigned | - | 用户ID |
| from_id | int unsigned | - | 消息发送者ID |
| to_from_id | int unsigned | - | 接收者ID |
| is_revoked | tinyint unsigned | 2 | 是否撤回[1:是;2:否] |
| is_deleted | tinyint unsigned | 2 | 是否删除[1:是;2:否] |
| extra | json | - | 消息扩展字段 |
| quote | json | - | 引用消息 |
| send_time | datetime | - | 发送时间 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 联合唯一键(uk_user_id_friend_id_sequence: user_id + to_from_id + sequence)，唯一键(uk_msgid: msg_id)

---

### 4.3 talk_group_message - 群聊消息记录表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | bigint unsigned | AUTO_INCREMENT | 聊天记录ID，主键 |
| msg_id | varchar(64) | - | 消息ID，唯一键 |
| sequence | bigint unsigned | - | 消息时序ID(消息排序) |
| msg_type | int unsigned | 1 | 消息类型 |
| group_id | int unsigned | - | 群组ID |
| from_id | int unsigned | - | 消息发送者ID |
| is_revoked | tinyint unsigned | 2 | 是否撤回[1:是;2:否] |
| extra | json | - | 消息扩展字段 |
| quote | json | - | 引用消息 |
| send_time | datetime | - | 发送时间 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 联合唯一键(uk_group_id_sequence: group_id + sequence)，唯一键(uk_msgid: msg_id)

---

### 4.4 talk_group_message_del - 群聊消息删除记录表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 主键ID |
| user_id | int unsigned | - | 用户ID |
| group_id | int unsigned | - | 群ID |
| msg_id | varchar(64) | - | 聊天记录ID |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |

**索引：** 联合唯一键(uk_user_id_msg_id: user_id + msg_id)

---

## 五、文章/笔记相关表

### 5.1 article - 用户文章表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 文章ID，主键 |
| user_id | int unsigned | - | 用户ID |
| class_id | int unsigned | 0 | 分类ID |
| tags_id | varchar(128) | '' | 笔记关联标签 |
| title | varchar(255) | - | 文章标题 |
| abstract | varchar(255) | '' | 文章摘要 |
| image | varchar(255) | '' | 文章首图 |
| is_asterisk | tinyint unsigned | 1 | 是否星标文章[1:是;2:否] |
| status | tinyint unsigned | 1 | 笔记状态[1:正常;2:已删除] |
| md_content | longtext | - | markdown内容 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |
| deleted_at | datetime | NULL | 删除时间 |

**索引：** 联合索引(idx_userid_classid_title: user_id + class_id + title)

---

### 5.2 article_class - 文章分类表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 文章分类ID，主键 |
| user_id | int unsigned | - | 用户ID |
| class_name | varchar(64) | - | 分类名 |
| sort | tinyint unsigned | 1 | 排序 |
| is_default | tinyint unsigned | 1 | 默认分类[1:是;2:否] |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 联合唯一键(uk_user_id_class_name: user_id + class_name)

---

### 5.3 article_tag - 文章标签表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 标签ID，主键 |
| user_id | int unsigned | - | 用户ID |
| tag_name | varchar(20) | - | 标签名 |
| sort | tinyint unsigned | 1 | 排序 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

---

### 5.4 article_annex - 文章附件信息表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 文件ID，主键 |
| user_id | int unsigned | - | 上传文件的用户ID |
| article_id | int unsigned | - | 笔记ID |
| drive | tinyint unsigned | 1 | 文件驱动[1:local;2:cos] |
| suffix | varchar(10) | '' | 文件后缀名 |
| size | bigint unsigned | 0 | 文件大小 |
| path | varchar(500) | - | 文件地址(相对地址) |
| original_name | varchar(100) | '' | 原文件名 |
| status | tinyint unsigned | 1 | 附件状态[1:正常;2:已删除] |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |
| deleted_at | datetime | NULL | 删除时间 |

**索引：** 联合索引(idx_userid_articleid: user_id + article_id)

---

### 5.5 article_history - 笔记历史记录表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 主键ID |
| user_id | int unsigned | - | 用户ID |
| article_id | int unsigned | - | 笔记ID |
| content | longtext | - | markdown内容 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |

**索引：** 联合索引(idx_user_id_article_id: user_id + article_id)

---

## 六、表情包相关表

### 6.1 emoticon - 表情包分组

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 表情分组ID，主键 |
| name | varchar(64) | - | 分组名称 |
| icon | varchar(255) | '' | 分组图标 |
| status | tinyint unsigned | 0 | 分组状态[1:正常;2:已禁用] |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

**索引：** 唯一键(uk_name: name)

---

### 6.2 emoticon_item - 表情包详情表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 表情包详情ID，主键 |
| emoticon_id | int unsigned | - | 表情分组ID(0:用户自定义上传) |
| user_id | int unsigned | - | 用户ID(0:代码系统表情包) |
| describe | varchar(64) | '' | 表情描述 |
| url | varchar(255) | - | 图片链接 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

---

### 6.3 users_emoticon - 用户收藏表情包

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 表情包收藏ID，主键 |
| user_id | int unsigned | - | 用户ID，唯一键 |
| emoticon_ids | json | - | 表情包ID |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |

---

## 七、其他表

### 7.1 robot - 聊天机器人表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 机器人ID，主键 |
| user_id | int unsigned | - | 关联用户ID |
| robot_name | varchar(64) | '' | 机器人名称 |
| describe | varchar(255) | '' | 描述信息 |
| logo | varchar(255) | '' | 机器人logo |
| is_talk | tinyint unsigned | 2 | 可发送消息[1:是;2:否] |
| status | tinyint unsigned | 0 | 状态[1:正常;2:已禁用;3:已删除] |
| type | tinyint unsigned | 0 | 机器人类型 |
| created_at | datetime | CURRENT_TIMESTAMP | 创建时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 更新时间 |

---

### 7.2 file_upload - 文件拆分数据表

| 字段名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| id | int unsigned | AUTO_INCREMENT | 临时文件ID，主键 |
| type | tinyint unsigned | 1 | 文件属性[1:合并文件;2:拆分文件] |
| drive | tinyint unsigned | 1 | 驱动类型[1:local;2:cos] |
| upload_id | varchar(128) | '' | 临时文件hash名 |
| user_id | int unsigned | 0 | 上传的用户ID |
| original_name | varchar(64) | '' | 原文件名 |
| split_index | int unsigned | 0 | 当前索引块 |
| split_num | int unsigned | 0 | 总上传索引块 |
| path | varchar(255) | '' | 临时保存路径 |
| file_ext | varchar(16) | '' | 文件后缀名 |
| file_size | int unsigned | - | 文件大小 |
| is_delete | tinyint unsigned | 0 | 文件是否删除[1:是;2:否] |
| attr | json | - | 额外参数json |
| created_at | datetime | CURRENT_TIMESTAMP | 更新时间 |
| updated_at | datetime | CURRENT_TIMESTAMP | 创建时间 |

---

## 八、表关系图

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              用户模块                                        │
│  ┌─────────┐     ┌──────────┐     ┌─────────────┐     ┌──────────────────┐  │
│  │  users  │────▶│ organize │────▶│organize_dept│     │ organize_position │  │
│  └─────────┘     └──────────┘     └─────────────┘     └──────────────────┘  │
│       │                                                                    │
│       ▼                                                                    │
│  ┌─────────┐     ┌──────────┐     ┌─────────────┐     ┌──────────────────┐  │
│  │  admin  │     │  contact │◀───▶│contact_apply│     │  contact_group   │  │
│  └─────────┘     └──────────┘     └─────────────┘     └──────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              消息模块                                        │
│  ┌──────────────┐     ┌─────────────────┐     ┌────────────────────────┐   │
│  │talk_session  │────▶│talk_user_message│     │talk_group_message_del │   │
│  └──────────────┘     └─────────────────┘     └────────────────────────┘   │
│         │                      │                                                    │
│         │                      ▼                                                    │
│         │              ┌─────────────────┐                                        │
│         └─────────────▶│talk_group_message│                                       │
│                         └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                              群聊模块                                         │
│  ┌─────────┐     ┌──────────────┐     ┌─────────────┐     ┌───────────────┐ │
│  │  group  │◀───▶│ group_member │     │ group_apply │     │  group_notice │ │
│  └─────────┘     └──────────────┘     └─────────────┘     └───────────────┘ │
│       │                                                                 │      │
│       ▼                                                                 ▼      │
│  ┌───────────┐     ┌─────────────┐                                           │
│  │group_vote │◀───▶│group_vote_answer│                                       │
│  └───────────┘     └─────────────┘                                           │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                             文章/笔记模块                                     │
│  ┌─────────┐     ┌────────────────┐     ┌─────────────────┐               │
│  │ article │◀───▶│ article_annex  │     │ article_history │               │
│  └────┬────┘     └────────────────┘     └─────────────────┘               │
│       │                                                                        │
│       ├──▶┌──────────────┐                                                    │
│       └──▶│ article_class│◀──────▶│ article_tag │                         │
│            └──────────────┘                                                    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                             表情包模块                                       │
│  ┌─────────────┐     ┌─────────────────┐     ┌──────────────────────┐      │
│  │  emoticon   │◀───▶│  emoticon_item  │     │   users_emoticon    │      │
│  └─────────────┘     └─────────────────┘     └──────────────────────┘      │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 九、索引设计总结

### 主键索引
- 所有表均使用自增主键 `id` 或联合主键

### 唯一索引
- `users.mobile` - 手机号唯一
- `admin.username` - 用户名唯一
- `contact(user_id, friend_id)` - 防止重复好友关系
- `group_member(group_id, user_id)` - 防止重复群成员
- `talk_user_message(user_id, to_from_id, sequence)` - 确保消息顺序
- `talk_group_message(group_id, sequence)` - 确保群消息顺序

### 常规索引
- `created_at`, `updated_at` - 几乎所有表都包含，用于排序和查询
- `user_id` - 用户相关查询
- `group_id` - 群组相关查询

---

## 十、存储引擎与字符集

- **存储引擎**: InnoDB
- **字符集**: utf8mb4
- **排序规则**: utf8mb4_general_ci
- **支持Emoji**: 是 (utf8mb4支持4字节UTF-8字符)

---

*文档由 LumenIM 项目自动生成*
