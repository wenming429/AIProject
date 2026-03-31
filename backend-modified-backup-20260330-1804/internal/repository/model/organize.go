package model

type Organize struct {
	Id         string   `gorm:"column:id;primaryKey" json:"id"`         // ID
	UserId     string   `gorm:"column:user_id;" json:"user_id"`         // 用户id
	DeptId     string   `gorm:"column:dept_id;" json:"dept_id"`         // 部门ID
	PositionId string   `gorm:"column:position_id;" json:"position_id"` // 岗位ID
	CreatedAt  int64    `gorm:"column:created_at;" json:"created_at"`    // 创建时间
	UpdatedAt  int64    `gorm:"column:updated_at;" json:"updated_at"`    // 更新时间
}

func (Organize) TableName() string {
	return "organize"
}
