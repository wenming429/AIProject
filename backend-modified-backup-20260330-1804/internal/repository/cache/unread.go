package cache

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// 未读消息过期时间 - 14天
const unreadExpireAt = 14 * 24 * time.Hour

type UnreadStorage struct {
	redis *redis.Client
}

func NewUnreadStorage(rds *redis.Client) *UnreadStorage {
	return &UnreadStorage{rds}
}

// Incr 消息未读数自增
// @params uid     用户ID
// @params mode    对话模式 1私信 2群聊
// @params sender  发送者ID(群ID)
func (u *UnreadStorage) Incr(ctx context.Context, uid string, mode int, sender string) {
	pipe := u.redis.Pipeline()
	u.PipeIncr(ctx, pipe, uid, mode, sender)
	_, _ = pipe.Exec(ctx)
}

// PipeIncr 消息未读数自增
// @params uid     用户ID
// @params mode    对话模式 1私信 2群聊
// @params sender  发送者ID(群ID)
func (u *UnreadStorage) PipeIncr(ctx context.Context, pipe redis.Pipeliner, uid string, mode int, sender string) {
	name := u.name(uid, mode, sender)
	pipe.Incr(ctx, name)
	pipe.Expire(ctx, name, unreadExpireAt)
}

// Get 获取消息未读数
// @params uid     用户ID
// @params mode    对话模式 1私信 2群聊
// @params sender  发送者ID(群ID)
func (u *UnreadStorage) Get(ctx context.Context, uid string, mode int, sender string) int {
	i, err := u.redis.Get(ctx, u.name(uid, mode, sender)).Int()
	if err != nil {
		return 0
	}

	return i
}

// Del 删除消息未读数
// @params uid     用户ID
// @params mode    对话模式 1私信 2群聊
// @params sender  发送者ID(群ID)
func (u *UnreadStorage) Del(ctx context.Context, uid string, mode int, sender string) {
	u.redis.Del(ctx, u.name(uid, mode, sender))
}

// Reset 消息未读数重置
// @params uid     用户ID
// @params mode    对话模式 1私信 2群聊
// @params sender  发送者ID(群ID)
func (u *UnreadStorage) Reset(ctx context.Context, uid string, mode int, sender string) {
	u.Del(ctx, uid, mode, sender)
}

// 未读数缓存
// mode int, uid, sender string
// im:unread:uid:mode_sender
func (u *UnreadStorage) name(uid string, mode int, sender string) string {
	return fmt.Sprintf("im:unread:%s:%d_%s", uid, mode, sender)
}
