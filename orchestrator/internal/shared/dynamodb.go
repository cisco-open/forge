package shared

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/feature/dynamodb/attributevalue"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb"
	"github.com/aws/aws-sdk-go-v2/service/dynamodb/types"
)

type DynamoDBRepository struct {
	client    *dynamodb.Client
	tableName string
}

func NewDynamoDBRepository(client *dynamodb.Client, tableName string) *DynamoDBRepository {
	return &DynamoDBRepository{
		client:    client,
		tableName: tableName,
	}
}

// convert generic key map[string]interface{} to dynamodb.AttributeValue map
func toDynamoKey(key map[string]interface{}) (map[string]types.AttributeValue, error) {
	av, err := attributevalue.MarshalMap(key)
	if err != nil {
		return nil, err
	}
	return av, nil
}

func (r *DynamoDBRepository) GetItem(ctx context.Context, key map[string]interface{}) (DBItem, error) {
	dynamoKey, err := toDynamoKey(key)
	if err != nil {
		return nil, fmt.Errorf("marshal key: %w", err)
	}

	out, err := r.client.GetItem(ctx, &dynamodb.GetItemInput{
		TableName: &r.tableName,
		Key:       dynamoKey,
	})
	if err != nil {
		return nil, err
	}
	if out.Item == nil {
		return nil, fmt.Errorf("item not found")
	}

	var item DBItem
	if err := attributevalue.UnmarshalMap(out.Item, &item); err != nil {
		return nil, err
	}
	return item, nil
}

func (r *DynamoDBRepository) UpdateItem(ctx context.Context, key map[string]interface{}, updates map[string]interface{}) error {
	dynamoKey, err := toDynamoKey(key)
	if err != nil {
		return err
	}

	exprValues := map[string]types.AttributeValue{}
	updateExpr := "SET "
	i := 0
	for k, v := range updates {
		placeholder := fmt.Sprintf(":val%d", i)
		if i > 0 {
			updateExpr += ", "
		}
		updateExpr += fmt.Sprintf("%s = %s", k, placeholder)

		av, err := attributevalue.Marshal(v)
		if err != nil {
			return err
		}
		exprValues[placeholder] = av
		i++
	}

	_, err = r.client.UpdateItem(ctx, &dynamodb.UpdateItemInput{
		TableName:                 &r.tableName,
		Key:                       dynamoKey,
		UpdateExpression:          &updateExpr,
		ExpressionAttributeValues: exprValues,
	})

	return err
}
