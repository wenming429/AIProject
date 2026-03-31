package entity

import "strconv"

const (
	JwtIssuerWeb   = "web"
	JwtIssuerAdmin = "admin"
)

type WebClaims struct {
	UserId string `json:"user_id"`
}

func (w WebClaims) GetAuthID() string {
	return w.UserId
}

type AdminClaims struct {
	AdminId int `json:"admin_id"`
}

func (a AdminClaims) GetAuthID() string {
	return strconv.Itoa(a.AdminId)
}
