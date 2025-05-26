package shared

import "context"

type DBItem map[string]interface{}

type Repository interface {
	GetItem(ctx context.Context, key map[string]interface{}) (DBItem, error)
	UpdateItem(ctx context.Context, key map[string]interface{}, updates map[string]interface{}) error
}
