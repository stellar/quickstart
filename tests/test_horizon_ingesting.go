package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

type Root struct {
	HorizonSequence int32 `json:"history_latest_ledger"`
	CoreSequence    int32 `json:"core_latest_ledger"`
}

func main() {
	for {
		time.Sleep(10 * time.Second)
		logLine("Waiting for Horizon to start ingesting")

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

		if root.HorizonSequence > 0 {
			logLine("Horizon started ingesting!")
			os.Exit(0)
		}
	}
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}
