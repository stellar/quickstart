// test_health_endpoint.go tests the /health endpoint through nginx
// This test verifies that the /health endpoint accessible through nginx on port 8000
// reports all services as "ready". This tests the complete health check pipeline.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

const timeout = 6 * time.Minute

type ReadinessResponse struct {
	Status   string            `json:"status"`
	Services map[string]interface{} `json:"services"`
}

func main() {
	startTime := time.Now()

	for {
		time.Sleep(5 * time.Second)
		logLine("Waiting for health endpoint to be ready")

		if time.Since(startTime) > timeout {
			logLine("Timeout")
			os.Exit(-1)
		}

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
			logLine("Health endpoint reports all services are ready!")
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