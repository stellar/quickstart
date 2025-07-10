package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

const timeout = 6 * time.Minute

type HealthResponse struct {
	Status   string            `json:"status"`
	Services map[string]string `json:"services"`
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

		resp, err := http.Get("http://localhost:8000/health")
		if err != nil {
			logLine(err)
			continue
		}

		var healthResponse HealthResponse
		decoder := json.NewDecoder(resp.Body)
		err = decoder.Decode(&healthResponse)
		resp.Body.Close()
		if err != nil {
			logLine(err)
			continue
		}

		logLine("Health response:", healthResponse)

		if resp.StatusCode == http.StatusOK && healthResponse.Status == "healthy" {
			logLine("Health endpoint reports all services are healthy!")
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