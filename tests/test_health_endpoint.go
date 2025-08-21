// test_health_endpoint.go tests the /health endpoint through nginx
// This test verifies that the /health endpoint accessible through nginx on port 8000
// reports all services as "ready". This tests the complete health check pipeline.
//
// Note: This test uses a 20-minute timeout to accommodate longer sync times
// for networks like pubnet, which can take 10-15 minutes or more to fully sync.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

const timeout = 20 * time.Minute

type ReadinessResponse struct {
	Status   string            `json:"status"`
	Services map[string]interface{} `json:"services"`
}

func main() {
	startTime := time.Now()

	for {
		time.Sleep(5 * time.Second)
		elapsed := time.Since(startTime)
		remaining := timeout - elapsed
		
		if remaining <= 0 {
			logLine("Timeout after", elapsed.Round(time.Second))
			os.Exit(-1)
		}
		
		logLine("Waiting for health endpoint to be ready (elapsed:", elapsed.Round(time.Second), "remaining:", remaining.Round(time.Second), ")")

		// Test the /health endpoint through nginx on port 8000
		// This endpoint returns {"status": "ready", "services": {...}}
		resp, err := http.Get("http://127.0.0.1:8000/health")
		if err != nil {
			logLine(err)
			continue
		}

		var readinessResponse ReadinessResponse
		decoder := json.NewDecoder(resp.Body)
		err = decoder.Decode(&readinessResponse)
		resp.Body.Close()
		if err != nil {
			logLine(err)
			continue
		}

		logLine("Health response:", readinessResponse)

		if resp.StatusCode == http.StatusOK && readinessResponse.Status == "ready" {
			logLine("Health endpoint reports all services are ready after", elapsed.Round(time.Second))
			os.Exit(0)
		}

		if resp.StatusCode != http.StatusOK {
			logLine("Health endpoint returned status:", resp.StatusCode)
		}
	}
}

func logLine(text ...interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}