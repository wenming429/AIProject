package entity

const (
	SubEventImMessage         = "sub.im.message"          // 对话消息通知
	SubEventImMessageKeyboard = "sub.im.message.keyboard" // 键盘输入事件通知
	SubEventImMessageRevoke   = "sub.im.message.revoke"   // 聊天消息撤销通知
	SubEventContactStatus     = "sub.im.contact.status"   // 用户在线状态通知
	SubEventContactApply      = "sub.im.contact.apply"    // 好友申请消息通知
	SubEventGroupJoin         = "sub.im.group.join"       // 邀请加入群聊通知
	SubEventGroupApply        = "sub.im.group.apply"      // 入群申请通知
)

type SubscribeMessage struct {
	Event   string `json:"event"`   // 事件
	Payload string `json:"payload"` // json 字符串
}

type SubEventImMessagePayload struct {
	TalkMode int    `json:"talk_mode"` // 1 单聊 2 群聊
	Message  string `json:"message"`   // json 字符串
}

type SubEventGroupJoinPayload struct {
	Type    int      `json:"type"` // 1 加入 2 退出
	GroupId string   `json:"group_id"`
	Uids    []string `json:"uids"`
}

type SubEventGroupApplyPayload struct {
	GroupId string `json:"group_id"`
	UserId  string `json:"user_id"`
	ApplyId string `json:"apply_id"`
}

type SubEventContactApplyPayload struct {
	ApplyId string `json:"apply_id"`
	Type    int    `json:"type"`
}

type SubEventImMessageKeyboardPayload struct {
	FromId   string `json:"from_id"`
	ToFromId string `json:"to_from_id"`
}

type SubEventContactStatusPayload struct {
	Status int    `json:"status"` // 1:上线 2:下线
	UserId string `json:"user_id"`
}

type SubEventTalkRevokePayload struct {
	TalkMode int    `json:"talk_mode"` // 1单聊 2群聊
	MsgId    string `json:"msg_id"`    // 消息ID
	Remark   string `json:"remark"`
}
