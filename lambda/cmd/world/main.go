// Package main implements the world Lambda function handler.
package main

import (
	"context"
	"net/http"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
)

func handler(_ context.Context, _ events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) { //nolint:gocritic,unused // Lambda handler signature requires value type and blank identifiers
	return events.APIGatewayProxyResponse{
		StatusCode: http.StatusOK,
		Body:       `{"message":"World from Lambda!"}`,
	}, nil
}

func main() {
	lambda.Start(handler)
}
