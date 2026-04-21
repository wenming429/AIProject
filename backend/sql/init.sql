-- =====================================================
-- LumenIM Database Initialization Script
-- Database: go_chat
-- Version: 2.0.0
-- Updated: 2026-04-09
-- =====================================================

-- Create database
CREATE DATABASE IF NOT EXISTS `go_chat`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_general_ci;

USE `go_chat`;

-- =====================================================
-- SECTION 1: User Management Tables
-- =====================================================

-- ----------------------------
-- Table: users (User Table)
-- ----------------------------
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
    `id`            int unsigned    NOT NULL AUTO_INCREMENT COMMENT 'User ID',
    `username`     varchar(50)     NOT NULL DEFAULT '' COMMENT 'Login username',
    `mobile`        varchar(11)     NOT NULL DEFAULT '' COMMENT 'Mobile number',
    `nickname`      varchar(64)     NOT NULL DEFAULT '' COMMENT 'Nickname',
    `avatar`       varchar(255)    NOT NULL DEFAULT '' COMMENT 'Avatar URL',
    `gender`        tinyint unsigned NOT NULL DEFAULT '3' COMMENT 'Gender: 1=Male, 2=Female, 3=Unknown',
    `password`      varchar(255)    NOT NULL COMMENT 'Password (hashed)',
    `motto`         varchar(500)   NOT NULL DEFAULT '' COMMENT 'Personal motto',
    `email`         varchar(30)     NOT NULL DEFAULT '' COMMENT 'Email',
    `birthday`      varchar(10)    NOT NULL DEFAULT '' COMMENT 'Birthday (YYYY-MM-DD)',
    `status`        int             NOT NULL DEFAULT '1' COMMENT 'Status: 1=Normal, 2=Disabled, 3=Deleted',
    `is_robot`      tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Is robot: 1=Yes, 2=No',
    `created_at`    datetime        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at`    datetime        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_username` (`username`),
    UNIQUE KEY `uk_mobile` (`mobile`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`),
    KEY `idx_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='User Account Table';

-- ----------------------------
-- Table: admin (Admin Table)
-- ----------------------------
DROP TABLE IF EXISTS `admin`;
CREATE TABLE `admin` (
    `id`            int unsigned    NOT NULL AUTO_INCREMENT COMMENT 'Admin ID',
    `username`     varchar(20)      NOT NULL COMMENT 'Admin username',
    `password`      varchar(255)    NOT NULL COMMENT 'Password (hashed)',
    `avatar`       varchar(255)    NOT NULL DEFAULT '' COMMENT 'Avatar URL',
    `gender`        tinyint unsigned NOT NULL DEFAULT '3' COMMENT 'Gender: 1=Male, 2=Female, 3=Unknown',
    `mobile`        varchar(11)     NOT NULL DEFAULT '' COMMENT 'Mobile number',
    `email`         varchar(30)     NOT NULL DEFAULT '' COMMENT 'Email',
    `motto`         varchar(100)    NOT NULL DEFAULT '' COMMENT 'Personal motto',
    `last_login_at` datetime        NOT NULL COMMENT 'Last login time',
    `status`        tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Status: 1=Normal, 2=Disabled',
    `created_at`    datetime        NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at`    datetime        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_username` (`username`),
    UNIQUE KEY `uk_email` (`email`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Administrator Table';

-- ----------------------------
-- Table: organize (Organization Association Table)
-- ----------------------------
DROP TABLE IF EXISTS `organize`;
CREATE TABLE `organize` (
    `id`          int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Record ID',
    `user_id`     int unsigned NOT NULL COMMENT 'User ID',
    `dept_id`     int unsigned NOT NULL COMMENT 'Department ID',
    `position_id` int unsigned NOT NULL COMMENT 'Position ID',
    `created_at`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_id` (`user_id`),
    KEY `idx_dept_id` (`dept_id`),
    KEY `idx_position_id` (`position_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Organization Association Table';

-- ----------------------------
-- Table: organize_dept (Department Table)
-- ----------------------------
DROP TABLE IF EXISTS `organize_dept`;
CREATE TABLE `organize_dept` (
    `dept_id`    int              NOT NULL AUTO_INCREMENT COMMENT 'Department ID',
    `parent_id`  int              NOT NULL DEFAULT '0' COMMENT 'Parent department ID',
    `ancestors`  varchar(128)     NOT NULL DEFAULT '' COMMENT 'Ancestor path (e.g., 0,1,5)',
    `dept_name`  varchar(64)      NOT NULL DEFAULT '' COMMENT 'Department name',
    `order_num`  double           NOT NULL DEFAULT '1' COMMENT 'Display order',
    `leader`     varchar(64)      NOT NULL COMMENT 'Department leader',
    `phone`      varchar(11)      NOT NULL COMMENT 'Contact phone',
    `email`      varchar(64)      NOT NULL COMMENT 'Email',
    `status`     tinyint          NOT NULL DEFAULT '1' COMMENT 'Status: 1=Normal, 2=Disabled',
    `is_deleted` tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Is deleted: 1=Yes, 2=No',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`dept_id`),
    KEY `idx_parent_id` (`parent_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Department Table';

-- ----------------------------
-- Table: organize_position (Position Table)
-- ----------------------------
DROP TABLE IF EXISTS `organize_position`;
CREATE TABLE `organize_position` (
    `position_id` int              NOT NULL AUTO_INCREMENT COMMENT 'Position ID',
    `post_code`   varchar(32)      NOT NULL COMMENT 'Position code',
    `post_name`   varchar(64)      NOT NULL COMMENT 'Position name',
    `sort`        int unsigned     NOT NULL DEFAULT '1' COMMENT 'Display order',
    `status`      tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Status: 1=Normal, 2=Disabled',
    `remark`      varchar(255)     NOT NULL DEFAULT '' COMMENT 'Remark',
    `created_at`  datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at`  datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`position_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Position Table';

-- =====================================================
-- SECTION 2: Friend & Contact Tables
-- =====================================================

-- ----------------------------
-- Table: contact (Friend Relationship Table)
-- ----------------------------
DROP TABLE IF EXISTS `contact`;
CREATE TABLE `contact` (
    `id`         int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'Relation ID',
    `user_id`    int unsigned     NOT NULL DEFAULT '0' COMMENT 'User ID',
    `friend_id`  int unsigned     NOT NULL DEFAULT '0' COMMENT 'Friend User ID',
    `remark`     varchar(64)      NOT NULL DEFAULT '' COMMENT 'Friend remark',
    `status`     tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Friend status: 0=Pending, 1=Friend',
    `group_id`   int unsigned     NOT NULL DEFAULT '0' COMMENT 'Contact group ID',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_friend` (`user_id`, `friend_id`),
    KEY `idx_friend_id` (`friend_id`),
    KEY `idx_group_id` (`group_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Friend Relationship Table';

-- ----------------------------
-- Table: contact_apply (Friend Request Table)
-- ----------------------------
DROP TABLE IF EXISTS `contact_apply`;
CREATE TABLE `contact_apply` (
    `id`         int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Request ID',
    `user_id`    int unsigned NOT NULL COMMENT 'Applicant User ID',
    `friend_id`  int unsigned NOT NULL COMMENT 'Target User ID',
    `remark`     varchar(64)  NOT NULL DEFAULT '' COMMENT 'Request remark',
    `created_at` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Request time',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_friend_id` (`friend_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Friend Request Table';

-- ----------------------------
-- Table: contact_group (Contact Group Table)
-- ----------------------------
DROP TABLE IF EXISTS `contact_group`;
CREATE TABLE `contact_group` (
    `id`         int          NOT NULL AUTO_INCREMENT COMMENT 'Group ID',
    `user_id`    int unsigned NOT NULL COMMENT 'User ID',
    `name`       varchar(64)  NOT NULL COMMENT 'Group name',
    `sort`       int unsigned NOT NULL DEFAULT '1' COMMENT 'Display order',
    `num`        int unsigned NOT NULL DEFAULT '0' COMMENT 'Member count',
    `created_at` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_id_name` (`user_id`, `name`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Contact Group Table';

-- =====================================================
-- SECTION 3: Group Chat Tables
-- =====================================================

-- ----------------------------
-- Table: `group` (Group Table)
-- ----------------------------
DROP TABLE IF EXISTS `group`;
CREATE TABLE `group` (
    `id`         int unsigned      NOT NULL AUTO_INCREMENT COMMENT 'Group ID',
    `type`       tinyint unsigned  NOT NULL DEFAULT '1' COMMENT 'Group type: 1=Normal, 2=Enterprise',
    `name`       varchar(64)       NOT NULL DEFAULT '' COMMENT 'Group name',
    `profile`    varchar(128)      NOT NULL DEFAULT '' COMMENT 'Group description',
    `avatar`     varchar(255)      NOT NULL DEFAULT '' COMMENT 'Group avatar',
    `max_num`    smallint unsigned NOT NULL DEFAULT '200' COMMENT 'Max member count',
    `is_overt`   tinyint unsigned  NOT NULL DEFAULT '2' COMMENT 'Is public: 1=Yes, 2=No',
    `is_mute`    tinyint unsigned  NOT NULL DEFAULT '2' COMMENT 'Is all muted: 1=Yes, 2=No',
    `is_dismiss` tinyint unsigned  NOT NULL DEFAULT '2' COMMENT 'Is dismissed: 1=Yes, 2=No',
    `creator_id` int unsigned      NOT NULL COMMENT 'Creator ID (Owner ID)',
    `created_at` datetime          NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime          NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    KEY `idx_creator_id` (`creator_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`),
    KEY `idx_is_dismiss` (`is_dismiss`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Group Chat Table';

-- ----------------------------
-- Table: group_member (Group Member Table)
-- ----------------------------
DROP TABLE IF EXISTS `group_member`;
CREATE TABLE `group_member` (
    `id`         int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'Record ID',
    `group_id`   int unsigned     NOT NULL COMMENT 'Group ID',
    `user_id`    int unsigned     NOT NULL COMMENT 'User ID',
    `leader`     tinyint unsigned NOT NULL DEFAULT '3' COMMENT 'Role: 1=Owner, 2=Admin, 3=Member',
    `user_card`  varchar(64)      NOT NULL DEFAULT '' COMMENT 'Group nickname card',
    `is_quit`    tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Has quit: 1=Yes, 2=No',
    `is_mute`    tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Is muted: 1=Yes, 2=No',
    `join_time`  datetime                  DEFAULT NULL COMMENT 'Join time',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_group_id_user_id` (`group_id`, `user_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_leader` (`leader`),
    KEY `idx_is_quit` (`is_quit`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Group Member Table';

-- ----------------------------
-- Table: group_apply (Group Join Request Table)
-- ----------------------------
DROP TABLE IF EXISTS `group_apply`;
CREATE TABLE `group_apply` (
    `id`         int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'Request ID',
    `group_id`   int unsigned     NOT NULL COMMENT 'Group ID',
    `user_id`    int unsigned     NOT NULL COMMENT 'User ID',
    `status`     tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Status: 1=Pending, 2=Approved, 3=Rejected',
    `remark`     varchar(255)     NOT NULL DEFAULT '' COMMENT 'Remark',
    `reason`     varchar(255)     NOT NULL DEFAULT '' COMMENT 'Rejection reason',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    KEY `idx_group_id_user_id` (`group_id`, `user_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Group Join Request Table';

-- ----------------------------
-- Table: group_notice (Group Notice Table)
-- ----------------------------
DROP TABLE IF EXISTS `group_notice`;
CREATE TABLE `group_notice` (
    `id`            int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'Notice ID',
    `group_id`      int unsigned     NOT NULL COMMENT 'Group ID',
    `creator_id`    int unsigned     NOT NULL COMMENT 'Creator User ID',
    `modify_id`     int              NOT NULL COMMENT 'Modifier ID',
    `content`       longtext         NOT NULL COMMENT 'Notice content',
    `confirm_users` json                      DEFAULT NULL COMMENT 'Confirmed users list',
    `is_confirm`    tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Require confirmation: 1=Yes, 2=No',
    `created_at`    datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at`    datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `un_group_id` (`group_id`),
    KEY `idx_creator_id` (`creator_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Group Notice Table';

-- ----------------------------
-- Table: group_vote (Group Vote Table)
-- ----------------------------
DROP TABLE IF EXISTS `group_vote`;
CREATE TABLE `group_vote` (
    `id`            int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Vote ID',
    `group_id`      int unsigned NOT NULL COMMENT 'Group ID',
    `user_id`       int unsigned NOT NULL COMMENT 'Creator User ID',
    `title`         varchar(64)  NOT NULL COMMENT 'Vote title',
    `answer_mode`   int unsigned NOT NULL COMMENT 'Answer mode: 1=Single, 2=Multiple',
    `answer_option` json         NOT NULL COMMENT 'Answer options (JSON array)',
    `answer_num`    int unsigned NOT NULL DEFAULT '0' COMMENT 'Required answer count',
    `answered_num`  int unsigned NOT NULL DEFAULT '0' COMMENT 'Answered count',
    `is_anonymous`  int unsigned NOT NULL DEFAULT '2' COMMENT 'Anonymous: 1=Yes, 2=No',
    `status`        int unsigned NOT NULL DEFAULT '1' COMMENT 'Status: 1=Active, 2=Ended',
    `created_at`    datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at`    datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    KEY `idx_group_id` (`group_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Group Vote Table';

-- ----------------------------
-- Table: group_vote_answer (Group Vote Answer Table)
-- ----------------------------
DROP TABLE IF EXISTS `group_vote_answer`;
CREATE TABLE `group_vote_answer` (
    `id`         int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Answer ID',
    `vote_id`    int unsigned NOT NULL COMMENT 'Vote ID',
    `user_id`    int unsigned NOT NULL COMMENT 'User ID',
    `option`     char(1)      NOT NULL COMMENT 'Selected option (A/B/C/D/E/F)',
    `created_at` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Answer time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_vote_id_user_id` (`vote_id`, `user_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Group Vote Answer Table';

-- =====================================================
-- SECTION 4: Message Tables
-- =====================================================

-- ----------------------------
-- Table: talk_session (Chat Session Table)
-- ----------------------------
DROP TABLE IF EXISTS `talk_session`;
CREATE TABLE `talk_session` (
    `id`         int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'Session ID',
    `talk_mode`  tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Talk mode: 1=Private, 2=Group',
    `user_id`    int unsigned     NOT NULL DEFAULT '0' COMMENT 'User ID',
    `to_from_id` int unsigned     NOT NULL COMMENT 'Target ID (User ID or Group ID)',
    `is_top`     tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Is pinned: 1=Yes, 2=No',
    `is_disturb` tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Do not disturb: 1=Yes, 2=No',
    `is_delete`  tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Is deleted: 1=Yes, 2=No',
    `is_robot`   tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Is robot: 1=Yes, 2=No',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_id_receiver_id_talk_type` (`user_id`, `to_from_id`, `talk_mode`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_to_from_id` (`to_from_id`),
    KEY `idx_talk_mode` (`talk_mode`),
    KEY `idx_is_delete` (`is_delete`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Chat Session Table';

-- ----------------------------
-- Table: talk_user_message (Private Message Table)
-- ----------------------------
DROP TABLE IF EXISTS `talk_user_message`;
CREATE TABLE `talk_user_message` (
    `id`         bigint unsigned  NOT NULL AUTO_INCREMENT COMMENT 'Message ID',
    `msg_id`     varchar(64)      NOT NULL COMMENT 'Message UUID',
    `org_msg_id` varchar(64)      NOT NULL COMMENT 'Original message ID (for reply)',
    `sequence`   bigint           NOT NULL COMMENT 'Message sequence ID (for ordering)',
    `msg_type`   int unsigned     NOT NULL DEFAULT '1' COMMENT 'Message type: 1=Text, 2=Image, etc.',
    `user_id`    int unsigned     NOT NULL COMMENT 'Owner User ID',
    `from_id`    int unsigned     NOT NULL COMMENT 'Sender User ID',
    `to_from_id` int unsigned     NOT NULL COMMENT 'Receiver User ID',
    `is_revoked` tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Is recalled: 1=Yes, 2=No',
    `is_deleted` tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Is deleted: 1=Yes, 2=No',
    `extra`      json             NOT NULL COMMENT 'Extra data (JSON)',
    `quote`      json             NOT NULL COMMENT 'Quote message (JSON)',
    `send_time`  datetime         NOT NULL COMMENT 'Send time',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_msgid` (`msg_id`),
    UNIQUE KEY `uk_user_id_friend_id_sequence` (`user_id`, `to_from_id`, `sequence`),
    KEY `idx_from_id` (`from_id`),
    KEY `idx_to_from_id` (`to_from_id`),
    KEY `idx_is_revoked` (`is_revoked`),
    KEY `idx_is_deleted` (`is_deleted`),
    KEY `idx_org_msg_id` (`org_msg_id`),
    KEY `idx_send_time` (`send_time`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Private Message Table';

-- ----------------------------
-- Table: talk_group_message (Group Message Table)
-- ----------------------------
DROP TABLE IF EXISTS `talk_group_message`;
CREATE TABLE `talk_group_message` (
    `id`         bigint unsigned  NOT NULL AUTO_INCREMENT COMMENT 'Message ID',
    `msg_id`     varchar(64)      NOT NULL COMMENT 'Message UUID',
    `sequence`   bigint unsigned  NOT NULL COMMENT 'Message sequence ID (for ordering)',
    `msg_type`   int unsigned     NOT NULL DEFAULT '1' COMMENT 'Message type',
    `group_id`   int unsigned     NOT NULL COMMENT 'Group ID',
    `from_id`    int unsigned     NOT NULL COMMENT 'Sender User ID',
    `is_revoked` tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Is recalled: 1=Yes, 2=No',
    `extra`      json             NOT NULL COMMENT 'Extra data (JSON)',
    `quote`      json             NOT NULL COMMENT 'Quote message (JSON)',
    `send_time`  datetime         NOT NULL COMMENT 'Send time',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_msgid` (`msg_id`),
    UNIQUE KEY `uk_group_id_sequence` (`group_id`, `sequence`),
    KEY `idx_group_id` (`group_id`),
    KEY `idx_from_id` (`from_id`),
    KEY `idx_is_revoked` (`is_revoked`),
    KEY `idx_send_time` (`send_time`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Group Message Table';

-- ----------------------------
-- Table: talk_group_message_del (Group Message Delete Record Table)
-- ----------------------------
DROP TABLE IF EXISTS `talk_group_message_del`;
CREATE TABLE `talk_group_message_del` (
    `id`         int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Record ID',
    `user_id`    int unsigned NOT NULL COMMENT 'User ID',
    `group_id`   int unsigned NOT NULL COMMENT 'Group ID',
    `msg_id`     varchar(64)  NOT NULL COMMENT 'Message ID',
    `created_at` datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_id_msg_id` (`user_id`, `msg_id`),
    KEY `idx_group_id` (`group_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Group Message Delete Record Table';

-- =====================================================
-- SECTION 5: Article & Note Tables
-- =====================================================

-- ----------------------------
-- Table: article (Article Table)
-- ----------------------------
DROP TABLE IF EXISTS `article`;
CREATE TABLE `article` (
    `id`          int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'Article ID',
    `user_id`     int unsigned     NOT NULL COMMENT 'User ID',
    `class_id`    int unsigned     NOT NULL DEFAULT '0' COMMENT 'Category ID',
    `tags_id`     varchar(128)     NOT NULL DEFAULT '' COMMENT 'Tag IDs (comma separated)',
    `title`       varchar(255)     NOT NULL COMMENT 'Article title',
    `abstract`    varchar(255)     NOT NULL DEFAULT '' COMMENT 'Abstract',
    `image`       varchar(255)     NOT NULL DEFAULT '' COMMENT 'Cover image URL',
    `is_asterisk` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Is starred: 1=Yes, 2=No',
    `status`      tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Status: 1=Normal, 2=Deleted',
    `md_content`  longtext         NOT NULL COMMENT 'Markdown content',
    `created_at`  datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at`  datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    `deleted_at`  datetime                  DEFAULT NULL COMMENT 'Deleted time',
    PRIMARY KEY (`id`),
    KEY `idx_userid_classid_title` (`user_id`, `class_id`, `title`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_class_id` (`class_id`),
    KEY `idx_is_asterisk` (`is_asterisk`),
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Article Table';

-- ----------------------------
-- Table: article_class (Article Category Table)
-- ----------------------------
DROP TABLE IF EXISTS `article_class`;
CREATE TABLE `article_class` (
    `id`         int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'Category ID',
    `user_id`    int unsigned     NOT NULL COMMENT 'User ID',
    `class_name` varchar(64)      NOT NULL COMMENT 'Category name',
    `sort`       tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Display order',
    `is_default` tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Is default: 1=Yes, 2=No',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_id_class_name` (`user_id`, `class_name`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Article Category Table';

-- ----------------------------
-- Table: article_tag (Article Tag Table)
-- ----------------------------
DROP TABLE IF EXISTS `article_tag`;
CREATE TABLE `article_tag` (
    `id`         int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'Tag ID',
    `user_id`    int unsigned     NOT NULL COMMENT 'User ID',
    `tag_name`   varchar(20)      NOT NULL COMMENT 'Tag name',
    `sort`       tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Display order',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Article Tag Table';

-- ----------------------------
-- Table: article_annex (Article Attachment Table)
-- ----------------------------
DROP TABLE IF EXISTS `article_annex`;
CREATE TABLE `article_annex` (
    `id`            int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'File ID',
    `user_id`       int unsigned     NOT NULL COMMENT 'Uploader User ID',
    `article_id`    int unsigned     NOT NULL COMMENT 'Article ID',
    `drive`         tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Drive: 1=Local, 2=COS',
    `suffix`        varchar(10)      NOT NULL DEFAULT '' COMMENT 'File extension',
    `size`          bigint unsigned  NOT NULL DEFAULT '0' COMMENT 'File size (bytes)',
    `path`          varchar(500)    NOT NULL COMMENT 'File path',
    `original_name` varchar(100)     NOT NULL DEFAULT '' COMMENT 'Original file name',
    `status`        tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Status: 1=Normal, 2=Deleted',
    `created_at`    datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at`    datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    `deleted_at`    datetime                  DEFAULT NULL COMMENT 'Deleted time',
    PRIMARY KEY (`id`),
    KEY `idx_userid_articleid` (`user_id`, `article_id`),
    KEY `idx_article_id` (`article_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Article Attachment Table';

-- ----------------------------
-- Table: article_history (Article History Table)
-- ----------------------------
DROP TABLE IF EXISTS `article_history`;
CREATE TABLE `article_history` (
    `id`         int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'History ID',
    `user_id`    int unsigned     NOT NULL COMMENT 'User ID',
    `article_id` int unsigned     NOT NULL COMMENT 'Article ID',
    `content`    longtext         NOT NULL COMMENT 'Markdown content snapshot',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    PRIMARY KEY (`id`),
    KEY `idx_user_id_article_id` (`user_id`, `article_id`),
    KEY `idx_article_id` (`article_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Article History Table';

-- =====================================================
-- SECTION 6: Emoticon Tables
-- =====================================================

-- ----------------------------
-- Table: emoticon (Emoticon Pack Table)
-- ----------------------------
DROP TABLE IF EXISTS `emoticon`;
CREATE TABLE `emoticon` (
    `id`         int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'Emoticon Pack ID',
    `name`       varchar(64)      NOT NULL COMMENT 'Pack name',
    `icon`       varchar(255)     NOT NULL DEFAULT '' COMMENT 'Pack icon URL',
    `status`     tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Status: 1=Normal, 2=Disabled',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_name` (`name`),
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Emoticon Pack Table';

-- ----------------------------
-- Table: emoticon_item (Emoticon Item Table)
-- ----------------------------
DROP TABLE IF EXISTS `emoticon_item`;
CREATE TABLE `emoticon_item` (
    `id`          int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Emoticon ID',
    `emoticon_id` int unsigned NOT NULL COMMENT 'Pack ID (0=User uploaded)',
    `user_id`     int unsigned NOT NULL COMMENT 'User ID (0=System pack)',
    `describe`    varchar(64)  NOT NULL DEFAULT '' COMMENT 'Description',
    `url`         varchar(255) NOT NULL COMMENT 'Emoticon URL',
    `created_at`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    KEY `idx_emoticon_id` (`emoticon_id`),
    KEY `idx_user_id` (`user_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Emoticon Item Table';

-- ----------------------------
-- Table: users_emoticon (User Favorite Emoticons Table)
-- ----------------------------
DROP TABLE IF EXISTS `users_emoticon`;
CREATE TABLE `users_emoticon` (
    `id`           int unsigned NOT NULL AUTO_INCREMENT COMMENT 'Record ID',
    `user_id`      int unsigned NOT NULL COMMENT 'User ID',
    `emoticon_ids` json         NOT NULL COMMENT 'Favorite emoticon IDs (JSON array)',
    `created_at`   datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_user_id` (`user_id`),
    KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='User Favorite Emoticons Table';

-- =====================================================
-- SECTION 7: Robot & File Tables
-- =====================================================

-- ----------------------------
-- Table: robot (Chat Robot Table)
-- ----------------------------
DROP TABLE IF EXISTS `robot`;
CREATE TABLE `robot` (
    `id`         int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'Robot ID',
    `user_id`    int unsigned     NOT NULL COMMENT 'Associated User ID',
    `robot_name` varchar(64)      NOT NULL DEFAULT '' COMMENT 'Robot name',
    `describe`   varchar(255)     NOT NULL DEFAULT '' COMMENT 'Description',
    `logo`       varchar(255)     NOT NULL DEFAULT '' COMMENT 'Robot logo URL',
    `is_talk`    tinyint unsigned NOT NULL DEFAULT '2' COMMENT 'Can send messages: 1=Yes, 2=No',
    `status`     tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Status: 1=Normal, 2=Disabled, 3=Deleted',
    `type`       tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Robot type',
    `created_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at` datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    UNIQUE KEY `uk_type` (`type`),
    UNIQUE KEY `uk_user_id` (`user_id`),
    KEY `idx_status` (`status`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='Chat Robot Table';

-- ----------------------------
-- Table: file_upload (File Upload Table)
-- ----------------------------
DROP TABLE IF EXISTS `file_upload`;
CREATE TABLE `file_upload` (
    `id`            int unsigned     NOT NULL AUTO_INCREMENT COMMENT 'File Record ID',
    `type`          tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'File type: 1=Merged, 2=Split',
    `drive`         tinyint unsigned NOT NULL DEFAULT '1' COMMENT 'Drive: 1=Local, 2=COS',
    `upload_id`     varchar(128)     NOT NULL DEFAULT '' COMMENT 'Upload session ID (hash)',
    `user_id`       int unsigned     NOT NULL DEFAULT '0' COMMENT 'Uploader User ID',
    `original_name` varchar(64)      NOT NULL DEFAULT '' COMMENT 'Original file name',
    `split_index`   int unsigned     NOT NULL DEFAULT '0' COMMENT 'Current chunk index',
    `split_num`     int unsigned     NOT NULL DEFAULT '0' COMMENT 'Total chunks',
    `path`          varchar(255)     NOT NULL DEFAULT '' COMMENT 'Storage path',
    `file_ext`      varchar(16)      NOT NULL DEFAULT '' COMMENT 'File extension',
    `file_size`     int unsigned     NOT NULL COMMENT 'File size (bytes)',
    `is_delete`     tinyint unsigned NOT NULL DEFAULT '0' COMMENT 'Is deleted: 1=Yes, 2=No',
    `attr`          json             NOT NULL COMMENT 'Extra attributes (JSON)',
    `created_at`    datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Created time',
    `updated_at`    datetime         NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Updated time',
    PRIMARY KEY (`id`),
    KEY `idx_user_id_upload_id` (`user_id`, `upload_id`),
    KEY `idx_upload_id` (`upload_id`),
    KEY `idx_created_at` (`created_at`),
    KEY `idx_updated_at` (`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
    COMMENT='File Upload Table';

-- =====================================================
-- SECTION 8: Initial Data
-- =====================================================

-- ----------------------------
-- 8.1 Admin Account (密码: admin123)
-- ----------------------------
-- bcrypt hash for "admin123" (cost=10)
INSERT INTO `admin` (`username`, `password`, `avatar`, `gender`, `mobile`, `email`, `motto`, `last_login_at`, `status`) VALUES
('admin', '$2a$10$N9qo8uLOickgx2ZMRZoMye9jTzp0VJTzpHjHjHjHjHjHjHjHjHjHi', '', 1, '', 'admin@example.com', 'System Administrator', NOW(), 1);

-- ----------------------------
-- 8.2 Test Users (密码: user123)
-- ----------------------------
-- bcrypt hash for "user123" (cost=10)
INSERT INTO `users` (`username`, `mobile`, `nickname`, `avatar`, `gender`, `password`, `motto`, `email`, `birthday`, `status`, `is_robot`) VALUES
('test001', '13800000001', '测试用户001', '', 1, '$2a$10$N9qo8uLOickgx2ZMRZoMye9jTzp0VJTzpHjHjHjHjHjHjHjHjHjHi', '这是测试用户001', '', '1990-01-01', 1, 2),
('test002', '13800000002', '测试用户002', '', 2, '$2a$10$N9qo8uLOickgx2ZMRZoMye9jTzp0VJTzpHjHjHjHjHjHjHjHjHjHi', '这是测试用户002', '', '1991-02-02', 1, 2),
('test003', '13800000003', '测试用户003', '', 1, '$2a$10$N9qo8uLOickgx2ZMRZoMye9jTzp0VJTzpHjHjHjHjHjHjHjHjHjHi', '这是测试用户003', '', '1992-03-03', 1, 2);

-- ----------------------------
-- 8.3 Robot Account (密码: robot123)
-- ----------------------------
INSERT INTO `users` (`username`, `mobile`, `nickname`, `avatar`, `gender`, `password`, `motto`, `email`, `birthday`, `status`, `is_robot`) VALUES
('robot001', '13800000000', '小智助手', '', 3, '$2a$10$N9qo8uLOickgx2ZMRZoMye9jTzp0VJTzpHjHjHjHjHjHjHjHjHjHi', '您好，我是智能助手，有什么可以帮助您的吗？', '', '', 1, 1);

INSERT INTO `robot` (`id`, `user_id`, `robot_name`, `describe`, `logo`, `is_talk`, `status`, `type`) VALUES
(1, (SELECT id FROM `users` WHERE username='robot001'), '小智助手', '智能对话机器人，可以回答问题和聊天', '', 1, 1, 1);

-- ----------------------------
-- 8.4 Emoticon Packs
-- ----------------------------
INSERT INTO `emoticon` (`id`, `name`, `icon`, `status`) VALUES
(1, 'Emoji', '/static/emoticon/emoji.png', 1),
(2, 'Stickers', '/static/emoticon/stickers.png', 1);

-- Emoji items (16 emojis)
INSERT INTO `emoticon_item` (`emoticon_id`, `user_id`, `describe`, `url`) VALUES
(1, 0, '微笑', '/static/emoticon/emoji/1.png'),
(1, 0, '大笑', '/static/emoticon/emoji/2.png'),
(1, 0, '大哭', '/static/emoticon/emoji/3.png'),
(1, 0, '爱心', '/static/emoticon/emoji/4.png'),
(1, 0, '点赞', '/static/emoticon/emoji/5.png'),
(1, 0, '差评', '/static/emoticon/emoji/6.png'),
(1, 0, '生气', '/static/emoticon/emoji/7.png'),
(1, 0, '惊讶', '/static/emoticon/emoji/8.png'),
(1, 0, '思考', '/static/emoticon/emoji/9.png'),
(1, 0, '挥手', '/static/emoticon/emoji/10.png'),
(1, 0, '鼓掌', '/static/emoticon/emoji/11.png'),
(1, 0, 'OK', '/static/emoticon/emoji/12.png'),
(1, 0, '飞吻', '/static/emoticon/emoji/13.png'),
(1, 0, '玫瑰', '/static/emoticon/emoji/14.png'),
(1, 0, '火焰', '/static/emoticon/emoji/15.png'),
(1, 0, '100分', '/static/emoticon/emoji/16.png');

-- ----------------------------
-- 8.5 Organization Structure
-- ----------------------------
INSERT INTO `organize_position` (`position_id`, `post_code`, `post_name`, `sort`, `status`, `remark`) VALUES
(1, 'CEO', '首席执行官', 1, 1, '公司最高管理者'),
(2, 'CTO', '首席技术官', 2, 1, '技术总监'),
(3, 'COO', '首席运营官', 3, 1, '运营总监'),
(4, 'MGR', '部门经理', 4, 1, '部门管理者'),
(5, 'DEV', '开发工程师', 5, 1, '软件开发人员'),
(6, 'TEST', '测试工程师', 6, 1, '软件测试人员'),
(7, 'OP', '运维工程师', 7, 1, '运维人员'),
(8, 'HR', '人事专员', 8, 1, '人力资源');

INSERT INTO `organize_dept` (`dept_id`, `parent_id`, `ancestors`, `dept_name`, `order_num`, `leader`, `phone`, `email`, `status`) VALUES
(1, 0, '0', '总公司', 1, 'CEO', '13800000001', 'hq@company.com', 1),
(2, 1, '0,1', '技术部', 1, 'CTO', '13800000002', 'tech@company.com', 1),
(3, 1, '0,1', '运营部', 2, 'COO', '13800000003', 'op@company.com', 1),
(4, 1, '0,1', '人事部', 3, 'HR', '13800000004', 'hr@company.com', 1),
(5, 2, '0,1,2', '前端组', 1, 'MGR', '13800000005', 'fe@company.com', 1),
(6, 2, '0,1,2', '后端组', 2, 'MGR', '13800000006', 'be@company.com', 1),
(7, 2, '0,1,2', '测试组', 3, 'MGR', '13800000007', 'qa@company.com', 1),
(8, 3, '0,1,3', '客服组', 1, 'MGR', '13800000008', 'cs@company.com', 1),
(9, 3, '0,1,3', '市场组', 2, 'MGR', '13800000009', 'mkt@company.com', 1);

-- User-Organization mapping
INSERT INTO `organize` (`user_id`, `dept_id`, `position_id`) VALUES
(1, 1, 1),
(2, 2, 2),
(3, 3, 3),
(4, 4, 8);

-- ----------------------------
-- 8.6 Default Contact Groups
-- ----------------------------
INSERT INTO `contact_group` (`user_id`, `name`, `sort`, `num`) VALUES
(1, '我的好友', 1, 0),
(1, '同事', 2, 0),
(1, '家人', 3, 0),
(1, '同学', 4, 0),
(2, '我的好友', 1, 0),
(2, '同事', 2, 0),
(3, '我的好友', 1, 0),
(3, '同事', 2, 0);

-- ----------------------------
-- 8.7 Sample Friends
-- ----------------------------
INSERT INTO `contact` (`user_id`, `friend_id`, `remark`, `status`, `group_id`) VALUES
(1, 2, '技术部同事', 1, 2),
(1, 3, '运营部同事', 1, 2),
(2, 1, 'CEO', 1, 2),
(2, 3, '运营部同事', 1, 2),
(3, 1, 'CEO', 1, 2),
(3, 2, '技术部同事', 1, 2);

-- ----------------------------
-- 8.8 Sample Groups
-- ----------------------------
INSERT INTO `group` (`id`, `type`, `name`, `profile`, `avatar`, `max_num`, `is_overt`, `creator_id`) VALUES
(1, 1, 'LumenIM 官方群', 'LumenIM 开源即时通讯系统官方交流群', '', '', 500, 1, 1),
(2, 1, '技术交流群', '技术讨论、问题交流', '', '', 200, 1, 2),
(3, 2, '公司内部群', '公司内部沟通群', '', '', 100, 2, 1);

-- Group members
INSERT INTO `group_member` (`group_id`, `user_id`, `leader`, `user_card`, `is_quit`) VALUES
(1, 1, 1, '群主', 2),
(1, 2, 2, '管理员', 2),
(1, 3, 3, '成员', 2),
(2, 2, 1, '群主', 2),
(2, 3, 2, '管理员', 2),
(3, 1, 1, '群主', 2),
(3, 2, 2, '成员', 2),
(3, 3, 2, '成员', 2);

-- Group notice for official group
INSERT INTO `group_notice` (`group_id`, `creator_id`, `modify_id`, `content`, `is_confirm`) VALUES
(1, 1, 1, '欢迎加入 LumenIM 官方交流群！请遵守群规，友好交流。', 2);

-- ----------------------------
-- 8.9 User Favorite Emoticons
-- ----------------------------
INSERT INTO `users_emoticon` (`user_id`, `emoticon_ids`) VALUES
(1, '[1,2,3,4,5]'),
(2, '[1,2,3]'),
(3, '[1,4,5]');

-- =====================================================
-- SECTION 9: Optimizations
-- =====================================================

-- Add comments for important indexes
-- Message tables should be partitioned by time in production
-- Consider adding foreign key constraints for production use

-- =====================================================
-- Script Complete
-- =====================================================
