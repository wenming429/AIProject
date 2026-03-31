-- ============================================
-- LumenIM 通讯录和系统资源初始化脚本
-- 补充通讯录分组、组织架构、文章标签等
-- ============================================

-- 1. 补充联系人分组 (已有5个，再添加一些)
INSERT INTO `contact_group` (`user_id`, `name`, `sort`, `num`, `created_at`, `updated_at`) VALUES
(4531, 'Work Friends', 6, 0, NOW(), NOW()),
(4531, 'School Friends', 7, 0, NOW(), NOW()),
(4531, 'Online Friends', 8, 0, NOW(), NOW()),
(4540, 'Colleagues', 1, 0, NOW(), NOW()),
(4540, 'School Mates', 2, 0, NOW(), NOW());

-- 2. 组织架构 - 部门表
INSERT INTO `organize_dept` (`dept_id`, `parent_id`, `ancestors`, `dept_name`, `order_num`, `leader`, `phone`, `email`, `status`, `is_deleted`, `created_at`, `updated_at`) VALUES
(1, 0, '0', 'Headquarters', 1, 'XiaoMing', '13800000001', 'admin@lumenim.com', 1, 2, NOW(), NOW()),
(2, 1, '0,1', 'Technology Dept', 1, 'ZhangSan', '13800000003', 'tech@lumenim.com', 1, 2, NOW(), NOW()),
(3, 1, '0,1', 'Product Dept', 2, 'XiaoHong', '13800000002', 'product@lumenim.com', 1, 2, NOW(), NOW()),
(4, 2, '0,1,2', 'Frontend Team', 1, 'LiSi', '13800000004', 'frontend@lumenim.com', 1, 2, NOW(), NOW()),
(5, 2, '0,1,2', 'Backend Team', 2, 'WangWu', '13800000005', 'backend@lumenim.com', 1, 2, NOW(), NOW()),
(6, 3, '0,1,3', 'UI Design Team', 1, 'ZhaoLiu', '13800000006', 'design@lumenim.com', 1, 2, NOW(), NOW()),
(7, 3, '0,1,3', 'UX Research Team', 2, 'SunQi', '13800000007', 'ux@lumenim.com', 1, 2, NOW(), NOW());

-- 3. 组织架构 - 岗位表
INSERT INTO `organize_position` (`position_id`, `post_code`, `post_name`, `sort`, `status`, `remark`, `created_at`, `updated_at`) VALUES
(1, 'CEO', 'CEO', 1, 1, 'Chief Executive Officer', NOW(), NOW()),
(2, 'CTO', 'CTO', 2, 1, 'Chief Technology Officer', NOW(), NOW()),
(3, 'TECH_LEAD', 'Tech Lead', 3, 1, 'Technical Team Lead', NOW(), NOW()),
(4, 'SENIOR_DEV', 'Senior Developer', 4, 1, 'Senior Software Developer', NOW(), NOW()),
(5, 'JUNIOR_DEV', 'Developer', 5, 1, 'Software Developer', NOW(), NOW()),
(6, 'DESIGNER', 'Designer', 6, 1, 'UI/UX Designer', NOW(), NOW()),
(7, 'PM', 'Product Manager', 7, 1, 'Product Manager', NOW(), NOW()),
(8, 'QA', 'QA Engineer', 8, 1, 'Quality Assurance', NOW(), NOW());

-- 4. 用户组织关系
INSERT INTO `organize` (`user_id`, `dept_id`, `position_id`, `created_at`, `updated_at`) VALUES
(4531, 1, 2, NOW(), NOW()),  -- XiaoMing - CTO
(4540, 3, 7, NOW(), NOW()),  -- XiaoHong - Product Manager
(4541, 2, 3, NOW(), NOW()),  -- ZhangSan - Tech Lead
(4542, 4, 5, NOW(), NOW()),  -- LiSi - Developer
(4543, 5, 5, NOW(), NOW()),  -- WangWu - Developer
(4544, 6, 6, NOW(), NOW()),  -- ZhaoLiu - Designer
(4545, 7, 6, NOW(), NOW()),  -- SunQi - Designer
(4546, 6, 6, NOW(), NOW()); -- ZhouBa - Designer

-- 5. 文章标签
INSERT INTO `article_tag` (`user_id`, `tag_name`, `sort`, `created_at`, `updated_at`) VALUES
(4531, 'Tech', 1, NOW(), NOW()),
(4531, 'Design', 2, NOW(), NOW()),
(4531, 'Life', 3, NOW(), NOW()),
(4531, 'Work', 4, NOW(), NOW()),
(4531, 'Study', 5, NOW(), NOW()),
(4540, 'Fashion', 1, NOW(), NOW()),
(4540, 'Travel', 2, NOW(), NOW()),
(4541, 'Coding', 1, NOW(), NOW());

-- 6. 文章分类
INSERT INTO `article_class` (`user_id`, `class_name`, `sort`, `is_default`, `created_at`, `updated_at`) VALUES
(4531, 'Tech Notes', 2, 2, NOW(), NOW()),
(4531, 'Design Inspiration', 3, 2, NOW(), NOW()),
(4531, 'Daily Thoughts', 4, 2, NOW(), NOW()),
(4540, 'Work Log', 1, 2, NOW(), NOW()),
(4541, 'Code Snippets', 1, 2, NOW(), NOW());

-- 7. 群公告
INSERT INTO `group_notice` (`group_id`, `creator_id`, `modify_id`, `content`, `confirm_users`, `is_confirm`, `created_at`, `updated_at`) VALUES
(1, 4531, 4531, 'Welcome to LumenIM Dev Group! This is our technical discussion group. Please keep discussions relevant to technology.', '[]', 2, NOW(), NOW()),
(2, 4531, 4541, 'Frontend Tech Group - Share your frontend knowledge here!', '[]', 2, NOW(), NOW());

-- 8. 入群申请记录
INSERT INTO `group_apply` (`group_id`, `user_id`, `status`, `remark`, `reason`, `created_at`, `updated_at`) VALUES
(1, 4542, 2, 'I want to learn Go', '', NOW(), NOW()),
(1, 4543, 2, 'Interested in IM systems', '', NOW(), NOW()),
(2, 4544, 2, 'Frontend developer here', '', NOW(), NOW()),
(2, 4546, 2, 'Designer interested in frontend', '', NOW(), NOW());

-- 9. 用户收藏表情包
INSERT INTO `users_emoticon` (`user_id`, `emoticon_ids`, `created_at`) VALUES
(4531, '[1,2,3]', NOW()),
(4540, '[2,4,5]', NOW()),
(4541, '[1,3]', NOW());

-- 10. 群投票
INSERT INTO `group_vote` (`group_id`, `user_id`, `title`, `answer_mode`, `answer_option`, `answer_num`, `answered_num`, `is_anonymous`, `status`, `created_at`, `updated_at`) VALUES
(1, 4531, 'Weekly Tech Sharing Topic', 1, '["Go","Vue.js","React","DevOps"]', 4, 3, 2, 1, NOW(), NOW());

-- 群投票详情
INSERT INTO `group_vote_answer` (`vote_id`, `user_id`, `option`, `created_at`) VALUES
(1, 4541, 'A', NOW()),
(1, 4542, 'B', NOW()),
(1, 4543, 'A', NOW());

-- 11. 补充更多好友关系 - 跨用户
-- XiaoMing(4531) 添加更多好友
INSERT INTO `contact` (`user_id`, `friend_id`, `remark`, `status`, `group_id`, `created_at`, `updated_at`) VALUES
(4531, 4546, 'Designer Zhou', 1, 1, NOW(), NOW());

-- XiaoHong(4540) 的好友
INSERT INTO `contact` (`user_id`, `friend_id`, `remark`, `status`, `group_id`, `created_at`, `updated_at`) VALUES
(4540, 4544, 'UI Designer', 1, 9, NOW(), NOW()),
(4540, 4545, 'UX Researcher', 1, 9, NOW(), NOW());

-- ZhangSan(4541) 的好友
INSERT INTO `contact` (`user_id`, `friend_id`, `remark`, `status`, `group_id`, `created_at`, `updated_at`) VALUES
(4541, 4542, 'Frontend dev', 1, 2, NOW(), NOW()),
(4541, 4543, 'Backend dev', 1, 2, NOW(), NOW());

-- 12. 更新联系人分组人数统计
UPDATE `contact_group` SET `num` = (
    SELECT COUNT(*) FROM `contact` WHERE `group_id` = `contact_group`.`id`
) WHERE `id` IN (1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
