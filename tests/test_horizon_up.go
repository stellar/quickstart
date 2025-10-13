package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

type Root struct {
	SupportedProtocolVersion int32 `json:"supported_protocol_version"`
}

func main() {
	for {
		time.Sleep(5 * time.Second)
		logLine("Waiting for Horizon to start")

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

		if root.SupportedProtocolVersion > 0 {
			logLine("Horizon has started!")
			os.Exit(0)
		}
	}
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}
