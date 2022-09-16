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
	Status string `json:"status"`
}

func main() {
	startTime := time.Now()

	for {
		time.Sleep(5 * time.Second)
		logLine("Waiting for Soroban RPC to start")

		if time.Since(startTime) > timeout {
			logLine("Timeout")
			os.Exit(-1)
		}

		resp, err := http.Get("http://localhost:8000/soroban/rpc/getHealth")
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

		if root.Status == "healthy" {
			logLine("Soroban RPC has started!")
			os.Exit(0)
		}
	}
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}
