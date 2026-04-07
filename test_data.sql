-- ============================================
-- LumenIM Test Data Initialization Script
-- Date: 2026-03-29
-- ============================================

-- 1. Create test users (password: admin123, bcrypt hash)
INSERT INTO users (mobile, nickname, avatar, gender, password, motto, status, is_robot, created_at, updated_at) VALUES
('13800000001', 'XiaoMing', '', 1, '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, 2, NOW(), NOW()),
('13800000002', 'XiaoHong', '', 2, '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, 2, NOW(), NOW()),
('13800000003', 'ZhangSan', '', 1, '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, 2, NOW(), NOW()),
('13800000004', 'LiSi', '', 1, '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, 2, NOW(), NOW()),
('13800000005', 'WangWu', '', 1, '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, 2, NOW(), NOW()),
('13800000006', 'ZhaoLiu', '', 2, '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, 2, NOW(), NOW()),
('13800000007', 'SunQi', '', 1, '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, 2, NOW(), NOW()),
('13800000008', 'ZhouBa', '', 2, '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, 2, NOW(), NOW()),
('13800000009', 'shulifang', '', 1, '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, 2, NOW(), NOW()),
('13800000010', 'ningxiaoying', '', 2, '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, 2, NOW(), NOW())
ON DUPLICATE KEY UPDATE nickname=VALUES(nickname);

-- 2. Create contact groups
INSERT INTO contact_group (user_id, name, sort, num, created_at, updated_at) VALUES
(4531, 'Colleagues', 1, 3, NOW(), NOW()),
(4531, 'Friends', 2, 2, NOW(), NOW()),
(4531, 'Family', 3, 1, NOW(), NOW()),
(4532, 'Classmates', 1, 2, NOW(), NOW()),
(4532, 'Friends', 2, 3, NOW(), NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- 3. Create friend relationships (user 4531 with others)
INSERT INTO contact (user_id, friend_id, remark, status, group_id, created_at, updated_at) VALUES
(4531, 4532, 'XiaoHong', 1, 2, NOW(), NOW()),
(4531, 4533, 'ZhangSan', 1, 1, NOW(), NOW()),
(4531, 4534, 'LiSi', 1, 1, NOW(), NOW()),
(4531, 4535, 'WangWu', 1, 2, NOW(), NOW()),
(4531, 4536, 'ZhaoLiu', 1, 3, NOW(), NOW()),
-- Bidirectional friendship
(4532, 4531, 'XiaoMing', 1, 2, NOW(), NOW()),
(4533, 4531, 'XiaoMing', 1, 1, NOW(), NOW()),
(4534, 4531, 'XiaoMing', 1, 1, NOW(), NOW()),
(4535, 4531, 'XiaoMing', 1, 2, NOW(), NOW()),
(4536, 4531, 'XiaoMing', 1, 1, NOW(), NOW())
ON DUPLICATE KEY UPDATE remark=VALUES(remark);

-- 4. Create chat groups
INSERT INTO `group` (type, name, profile, avatar, max_num, is_overt, is_mute, is_dismiss, creator_id, created_at, updated_at) VALUES
(1, 'LumenIM Dev Group', 'Lumen IM Instant Messaging Tech Discussion', '', 200, 1, 2, 2, 4531, NOW(), NOW()),
(1, 'Frontend Tech Group', 'Vue3 / React / TypeScript Discussion', '', 200, 1, 2, 2, 4531, NOW(), NOW()),
(1, 'Go Language Lovers', 'Go Language Learning and Practice', '', 200, 1, 2, 2, 4532, NOW(), NOW()),
(1, 'Casual Chat Group', 'Relaxed Chat After Work', '', 100, 2, 2, 2, 4533, NOW(), NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- 5. Add group members
INSERT INTO group_member (group_id, user_id, leader, user_card, is_quit, is_mute, join_time, created_at, updated_at) VALUES
-- LumenIM Dev Group members
(1, 4531, 1, 'Owner', 2, 2, NOW(), NOW(), NOW()),
(1, 4532, 2, 'Admin', 2, 2, NOW(), NOW(), NOW()),
(1, 4533, 3, '', 2, 2, NOW(), NOW(), NOW()),
(1, 4534, 3, '', 2, 2, NOW(), NOW(), NOW()),
(1, 4535, 3, '', 2, 2, NOW(), NOW(), NOW()),
-- Frontend Tech Group members
(2, 4531, 1, 'Owner', 2, 2, NOW(), NOW(), NOW()),
(2, 4533, 2, 'Frontend Pro', 2, 2, NOW(), NOW(), NOW()),
(2, 4536, 3, '', 2, 2, NOW(), NOW(), NOW()),
(2, 4538, 3, '', 2, 2, NOW(), NOW(), NOW()),
-- Go Language Lovers members
(3, 4532, 1, 'Owner', 2, 2, NOW(), NOW(), NOW()),
(3, 4534, 2, 'Gopher', 2, 2, NOW(), NOW(), NOW()),
(3, 4537, 3, '', 2, 2, NOW(), NOW(), NOW()),
-- Casual Chat Group members
(4, 4533, 1, 'Pro', 2, 2, NOW(), NOW(), NOW()),
(4, 4535, 3, '', 2, 2, NOW(), NOW(), NOW()),
(4, 4536, 3, '', 2, 2, NOW(), NOW(), NOW()),
(4, 4537, 3, '', 2, 2, NOW(), NOW(), NOW()),
(4, 4538, 3, '', 2, 2, NOW(), NOW(), NOW())
ON DUPLICATE KEY UPDATE user_card=VALUES(user_card);

-- 6. Create session list (user 4531 sessions)
INSERT INTO talk_session (talk_mode, user_id, to_from_id, is_top, is_disturb, is_delete, is_robot, created_at, updated_at) VALUES
(1, 4531, 4532, 1, 2, 2, 2, NOW(), NOW()),
(1, 4531, 4533, 2, 2, 2, 2, NOW(), NOW()),
(1, 4531, 4534, 2, 1, 2, 2, NOW(), NOW()),
(2, 4531, 1, 1, 2, 2, 2, NOW(), NOW()),
(2, 4531, 2, 2, 2, 2, 2, NOW(), NOW())
ON DUPLICATE KEY UPDATE is_top=VALUES(is_top);

-- 7. Emoticon groups
INSERT INTO emoticon (name, icon, status, created_at, updated_at) VALUES
('Smile', 'smile', 1, NOW(), NOW()),
('Emoji', 'emoji', 1, NOW(), NOW()),
('Heart', 'heart', 1, NOW(), NOW()),
('Gesture', 'gesture', 1, NOW(), NOW()),
('Animal', 'animal', 1, NOW(), NOW())
ON DUPLICATE KEY UPDATE name=VALUES(name);

-- 8. Emoticon items
INSERT INTO emoticon_item (emoticon_id, user_id, `describe`, url, created_at, updated_at) VALUES
(1, 0, 'smile', '/static/emoticon/face1.png', NOW(), NOW()),
(1, 0, 'laugh', '/static/emoticon/face2.png', NOW(), NOW()),
(1, 0, 'cute', '/static/emoticon/face3.png', NOW(), NOW()),
(2, 0, 'happy', '/static/emoticon/emotion1.png', NOW(), NOW()),
(2, 0, 'excited', '/static/emoticon/emotion2.png', NOW(), NOW()),
(3, 0, 'red heart', '/static/emoticon/heart1.png', NOW(), NOW()),
(3, 0, 'pink heart', '/static/emoticon/heart2.png', NOW(), NOW()),
(4, 0, 'thumbs up', '/static/emoticon/hand1.png', NOW(), NOW()),
(4, 0, 'applause', '/static/emoticon/hand2.png', NOW(), NOW()),
(5, 0, 'cat', '/static/emoticon/cat.png', NOW(), NOW()),
(5, 0, 'dog', '/static/emoticon/dog.png', NOW(), NOW())
ON DUPLICATE KEY UPDATE `describe`=VALUES(`describe`);

-- 9. Admin account
INSERT INTO admin (username, password, avatar, gender, mobile, email, motto, last_login_at, status, created_at, updated_at) VALUES
('admin', '$2a$10$MDkzvCBC4rSxfUFR81lZGu3EqiYBLRP4t6UoYoWmcqovZZc4PkDTW', '', 1, '13800000000', 'admin@lumenim.com', 'System Admin', NOW(), 1, NOW(), NOW())
ON DUPLICATE KEY UPDATE motto=VALUES(motto);

-- 10. Robot accounts
INSERT INTO robot (user_id, robot_name, `describe`, logo, is_talk, status, type, created_at, updated_at) VALUES
(4537, 'Assistant', 'Smart Chat Bot', '', 1, 1, 1, NOW(), NOW()),
(4538, 'Weather Bot', 'Weather Query Bot', '', 1, 1, 2, NOW(), NOW())
ON DUPLICATE KEY UPDATE robot_name=VALUES(robot_name);
