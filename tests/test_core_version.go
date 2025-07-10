package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

const timeout = 3 * time.Minute

type Root struct {
	StellarCoreVersion string `json:"core_version"`
}

func main() {
	startTime := time.Now()

	for {
		time.Sleep(5 * time.Second)
		logLine("Waiting for Horizon to start and checking core_version")

		if time.Since(startTime) > timeout {
			logLine("Timeout")
			os.Exit(-1)
		}

		resp, err := http.Get("http://localhost:8000")
		if err != nil {
			logLine(err)
			continue
		}

		var root Root
		decoder := json.NewDecoder(resp.Body)
		err = decoder.Decode(&root)
		if err != nil {
			logLine(err)
			continue
		}

		if root.StellarCoreVersion != "" {
			logLine("SUCCESS: core_version is populated: " + root.StellarCoreVersion)
			os.Exit(0)
		} else {
			logLine("core_version is still empty")
		}
	}
}

func logLine(text interface{}) {
	log.Println("\033[33;1m[core_version_test]\033[0m", text)
}