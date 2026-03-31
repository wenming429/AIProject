package cache

import (
	"context"
	"fmt"

	"github.com/gzydong/go-chat/internal/pkg/jsonutil"
	"github.com/redis/go-redis/v9"
)

const lastMessageCacheKey = "im:message:last_message"

type MessageStorage struct {
	redis *redis.Client
}

type LastCacheMessage struct {
	Content  string `json:"content"`
	Datetime string `json:"datetime"`
}

func NewMessageStorage(rds *redis.Client) *MessageStorage {
	return &MessageStorage{rds}
}

func (m *MessageStorage) Set(ctx context.Context, talkType int, sender string, receive string, message *LastCacheMessage) error {
	text := jsonutil.Encode(message)

	return m.redis.HSet(ctx, lastMessageCacheKey, m.name(talkType, sender, receive), text).Err()
}

func (m *MessageStorage) Get(ctx context.Context, talkType int, sender string, receive string) (*LastCacheMessage, error) {

	res, err := m.redis.HGet(ctx, lastMessageCacheKey, m.name(talkType, sender, receive)).Result()
	if err != nil {
		return nil, err
	}

	msg := &LastCacheMessage{}
	if err = jsonutil.Unmarshal(res, msg); err != nil {
		return nil, err
	}

	return msg, nil
}

func (m *MessageStorage) MGet(ctx context.Context, fields []string) ([]*LastCacheMessage, error) {

	res := m.redis.HMGet(ctx, lastMessageCacheKey, fields...)

	items := make([]*LastCacheMessage, 0)
	for _, item := range res.Val() {
		if val, ok := item.(string); ok {
			msg := &LastCacheMessage{}
			if err := jsonutil.Unmarshal(val, msg); err != nil {
				return nil, err
			}

			items = append(items, msg)
		}
	}

	return items, nil
}

func (m *MessageStorage) name(talkType int, sender string, receive string) string {
	return fmt.Sprintf("%d_%s_%s", talkType, sender, receive)
}
