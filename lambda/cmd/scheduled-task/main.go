// Package main implements the scheduled task Lambda function handler.
package main

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/aws/aws-lambda-go/lambda"
)

func handler(_ context.Context) error { //nolint:unused // Lambda handler signature requires blank identifier for unused context
	log.Printf("Scheduled task executed at %s (TASK_TYPE=%s)\n", time.Now().Format(time.RFC3339), os.Getenv("TASK_TYPE"))
	return nil
}

func main() {
	lambda.Start(handler)
}
