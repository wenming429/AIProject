package contact

import (
	"context"
	"strconv"

	"github.com/gzydong/go-chat/api/pb/web/v1"
	"github.com/gzydong/go-chat/internal/entity"
	"github.com/gzydong/go-chat/internal/pkg/core/middleware"
	"github.com/gzydong/go-chat/internal/pkg/timeutil"
	"github.com/gzydong/go-chat/internal/repository/repo"
	"github.com/gzydong/go-chat/internal/service"
	"github.com/gzydong/go-chat/internal/service/message"
)

var _ web.IContactApplyHandler = (*Apply)(nil)

type Apply struct {
	ContactRepo         *repo.Contact
	ContactApplyService service.IContactApplyService
	UserService         service.IUserService
	ContactService      service.IContactService
	MessageService      message.IService
}

func (a Apply) Create(ctx context.Context, in *web.ContactApplyCreateRequest) (*web.ContactApplyCreateResponse, error) {
	uid := middleware.FormContextAuthId[entity.WebClaims](ctx)
	friendId := strconv.FormatInt(int64(in.UserId), 10)

	if a.ContactRepo.IsFriend(ctx, uid, friendId, false) {
		return nil, nil
	}

	if err := a.ContactApplyService.Create(ctx, &service.ContactApplyCreateOpt{
		UserId:   uid,
		Remarks:  in.Remark,
		FriendId: friendId,
	}); err != nil {
		return nil, err
	}

	return &web.ContactApplyCreateResponse{}, nil
}

func (a Apply) Accept(ctx context.Context, in *web.ContactApplyAcceptRequest) (*web.ContactApplyAcceptResponse, error) {
	uid := middleware.FormContextAuthId[entity.WebClaims](ctx)
	applyInfo, err := a.ContactApplyService.Accept(ctx, &service.ContactApplyAcceptOpt{
		Remarks: in.Remark,
		ApplyId: strconv.FormatInt(int64(in.ApplyId), 10),
		UserId:  uid,
	})

	if err != nil {
		return nil, err
	}

	_ = a.MessageService.CreatePrivateSysMessage(ctx, message.CreatePrivateSysMessageOption{
		FromId:   uid,
		ToFromId: applyInfo.UserId,
		Content:  "你们已成为好友，可以开始聊天咯！",
	})

	_ = a.MessageService.CreatePrivateSysMessage(ctx, message.CreatePrivateSysMessageOption{
		FromId:   applyInfo.UserId,
		ToFromId: uid,
		Content:  "你们已成为好友，可以开始聊天咯！",
	})

	return &web.ContactApplyAcceptResponse{}, nil
}

func (a Apply) Decline(ctx context.Context, in *web.ContactApplyDeclineRequest) (*web.ContactApplyDeclineResponse, error) {
	uid := middleware.FormContextAuthId[entity.WebClaims](ctx)

	if err := a.ContactApplyService.Decline(ctx, &service.ContactApplyDeclineOpt{
		UserId:  uid,
		Remarks: in.Remark,
		ApplyId: strconv.FormatInt(int64(in.ApplyId), 10),
	}); err != nil {
		return nil, err
	}

	return &web.ContactApplyDeclineResponse{}, nil
}

func (a Apply) List(ctx context.Context, req *web.ContactApplyListRequest) (*web.ContactApplyListResponse, error) {
	uid := middleware.FormContextAuthId[entity.WebClaims](ctx)

	list, err := a.ContactApplyService.List(ctx, uid)
	if err != nil {
		return nil, err
	}

	items := make([]*web.ContactApplyListResponse_Item, 0, len(list))
	for _, item := range list {
		uid, _ := strconv.ParseInt(item.UserId, 10, 32)
		fid, _ := strconv.ParseInt(item.FriendId, 10, 32)
		items = append(items, &web.ContactApplyListResponse_Item{
			Id:        int32(item.Id),
			UserId:    int32(uid),
			FriendId:  int32(fid),
			Remark:    item.Remark,
			Nickname:  item.Nickname,
			Avatar:    item.Avatar,
			CreatedAt: timeutil.FormatDatetime(item.CreatedAt),
		})
	}

	a.ContactApplyService.ClearApplyUnreadNum(ctx, uid)

	return &web.ContactApplyListResponse{Items: items}, nil
}

func (a Apply) UnreadNum(ctx context.Context, req *web.ContactApplyUnreadNumRequest) (*web.ContactApplyUnreadNumResponse, error) {
	uid := middleware.FormContextAuthId[entity.WebClaims](ctx)
	return &web.ContactApplyUnreadNumResponse{Num: int32(a.ContactApplyService.GetApplyUnreadNum(ctx, uid))}, nil
}
