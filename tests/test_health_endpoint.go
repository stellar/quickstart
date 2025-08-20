// test_health_endpoint.go tests the custom readiness service endpoint
// This test verifies that our custom readiness service on port 8004 is working
// and reports all services as "ready". This is different from Horizon's built-in
// health endpoint on port 8000/health which has a different response format.
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
		logLine("Waiting for readiness endpoint to be ready")

		if time.Since(startTime) > timeout {
			logLine("Timeout")
			os.Exit(-1)
		}

		// Test our custom readiness service on port 8004
		// This endpoint returns {"status": "ready", "services": {...}}
		resp, err := http.Get("http://127.0.0.1:8004")
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

		logLine("Readiness response:", readinessResponse)

		if resp.StatusCode == http.StatusOK && readinessResponse.Status == "ready" {
			logLine("Readiness endpoint reports all services are ready!")
			os.Exit(0)
		}

		if resp.StatusCode != http.StatusOK {
			logLine("Readiness endpoint returned status:", resp.StatusCode)
		}
	}
}

func logLine(text ...interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}