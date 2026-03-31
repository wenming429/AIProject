package contact

import (
	"context"
	"errors"
	"strconv"

	"github.com/gzydong/go-chat/api/pb/web/v1"
	"github.com/gzydong/go-chat/internal/pkg/core/middleware"
	"github.com/gzydong/go-chat/internal/repository/cache"
	"github.com/gzydong/go-chat/internal/repository/repo"
	message2 "github.com/gzydong/go-chat/internal/service/message"
	"github.com/samber/lo"
	"gorm.io/gorm"

	"github.com/gzydong/go-chat/internal/entity"
	"github.com/gzydong/go-chat/internal/service"
)

var _ web.IContactHandler = (*Contact)(nil)

type Contact struct {
	ContactRepo     *repo.Contact
	UsersRepo       *repo.Users
	OrganizeRepo    *repo.Organize
	TalkSessionRepo *repo.TalkSession
	ContactService  service.IContactService
	UserService     service.IUserService
	TalkListService service.ITalkSessionService
	Message         message2.IService
	UserClient      *cache.UserClient
}

func (c *Contact) List(ctx context.Context, _ *web.ContactListRequest) (*web.ContactListResponse, error) {
	list, err := c.ContactService.List(ctx, middleware.FormContextAuthId[entity.WebClaims](ctx))
	if err != nil {
		return nil, err
	}

	items := make([]*web.ContactListResponse_Item, 0, len(list))
	for _, item := range list {
		uid, _ := strconv.ParseInt(item.Id, 10, 32)
		gid, _ := strconv.ParseInt(item.GroupId, 10, 32)
		items = append(items, &web.ContactListResponse_Item{
			UserId:   int32(uid),
			Nickname: item.Nickname,
			Gender:   int32(item.Gender),
			Motto:    item.Motto,
			Avatar:   item.Avatar,
			Remark:   item.Remark,
			GroupId:  int32(gid),
		})
	}

	return &web.ContactListResponse{Items: items}, nil
}

func (c *Contact) Delete(ctx context.Context, in *web.ContactDeleteRequest) (*web.ContactDeleteResponse, error) {
	uid := middleware.FormContextAuthId[entity.WebClaims](ctx)
	friendId := strconv.FormatInt(int64(in.UserId), 10)
	if err := c.ContactService.Delete(ctx, uid, friendId); err != nil {
		return nil, err
	}

	_ = c.Message.CreatePrivateSysMessage(ctx, message2.CreatePrivateSysMessageOption{
		FromId:   friendId,
		ToFromId: uid,
		Content:  "你与对方已经解除了好友关系！",
	})

	if err := c.TalkListService.Delete(ctx, uid, entity.ChatPrivateMode, friendId); err != nil {
		return nil, err
	}

	return &web.ContactDeleteResponse{}, nil
}

func (c *Contact) EditRemark(ctx context.Context, in *web.ContactEditRemarkRequest) (*web.ContactEditRemarkResponse, error) {
	if err := c.ContactService.UpdateRemark(ctx, middleware.FormContextAuthId[entity.WebClaims](ctx), strconv.FormatInt(int64(in.UserId), 10), in.Remark); err != nil {
		return nil, err
	}

	return &web.ContactEditRemarkResponse{}, nil
}

func (c *Contact) Detail(ctx context.Context, in *web.ContactDetailRequest) (*web.ContactDetailResponse, error) {
	uid := middleware.FormContextAuthId[entity.WebClaims](ctx)
	friendId := strconv.FormatInt(int64(in.UserId), 10)

	user, err := c.UsersRepo.FindById(ctx, friendId)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, entity.ErrUserNotExist
		}

		return nil, err
	}

	userId, _ := strconv.ParseInt(user.Id, 10, 32)
	resp := &web.ContactDetailResponse{
		UserId:         int32(userId),
		Mobile:         lo.FromPtr(user.Mobile),
		Nickname:       user.Nickname,
		Avatar:         user.Avatar,
		Gender:         int32(user.Gender),
		Motto:          user.Motto,
		Email:          user.Email,
		Relation:       1, // 关系 1陌生人 2好友 3企业同事 4本人
		ContactRemark:  "",
		ContactGroupId: 0,
		OnlineStatus:   "N",
	}

	if user.Id == uid {
		resp.Relation = 4
		resp.OnlineStatus = "Y"
		return resp, nil
	}

	isQiYeMember, _ := c.OrganizeRepo.IsQiyeMember(ctx, uid, user.Id)
	if isQiYeMember {
		if c.UserClient.IsOnline(ctx, friendId) {
			resp.OnlineStatus = "Y"
		}

		resp.Relation = 3
		return resp, nil
	}

	contact, err := c.ContactRepo.FindByWhere(ctx, "user_id = ? and friend_id = ?", uid, user.Id)
	if err != nil && !errors.Is(err, gorm.ErrRecordNotFound) {
		return nil, err
	}

	resp.Relation = 1
	if err == nil && contact.Status == 1 && c.ContactRepo.IsFriend(ctx, uid, user.Id, true) {
		resp.Relation = 2
		gid, _ := strconv.ParseInt(contact.GroupId, 10, 32)
		resp.ContactGroupId = int32(gid)
		resp.ContactRemark = contact.Remark

		if c.UserClient.IsOnline(ctx, friendId) {
			resp.OnlineStatus = "Y"
		}
	}

	return resp, nil
}

func (c *Contact) Search(ctx context.Context, in *web.ContactSearchRequest) (*web.ContactSearchResponse, error) {
	user, err := c.UsersRepo.FindByMobile(ctx, in.Mobile)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return nil, entity.ErrUserNotExist
		}

		return nil, err
	}

	uid, _ := strconv.ParseInt(user.Id, 10, 32)
	return &web.ContactSearchResponse{
		UserId:   int32(uid),
		Mobile:   lo.FromPtr[string](user.Mobile),
		Nickname: user.Nickname,
		Avatar:   user.Avatar,
		Gender:   int32(user.Gender),
		Motto:    user.Motto,
	}, nil
}

func (c *Contact) ChangeGroup(ctx context.Context, in *web.ContactChangeGroupRequest) (*web.ContactChangeGroupResponse, error) {
	err := c.ContactService.MoveGroup(ctx, middleware.FormContextAuthId[entity.WebClaims](ctx), strconv.FormatInt(int64(in.UserId), 10), strconv.FormatInt(int64(in.GroupId), 10))
	if err != nil {
		return nil, err
	}

	return &web.ContactChangeGroupResponse{}, nil
}

func (c *Contact) OnlineStatus(ctx context.Context, in *web.ContactOnlineStatusRequest) (*web.ContactOnlineStatusResponse, error) {
	resp := &web.ContactOnlineStatusResponse{
		OnlineStatus: "N",
	}

	uid := middleware.FormContextAuthId[entity.WebClaims](ctx)
	friendId := strconv.FormatInt(int64(in.UserId), 10)
	ok := c.ContactRepo.IsFriend(ctx, uid, friendId, true)
	if ok && c.UserClient.IsOnline(ctx, friendId) {
		resp.OnlineStatus = "Y"
	}

	return resp, nil
}
