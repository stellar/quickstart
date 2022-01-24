package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

const timeout = 3 * time.Minute

type Info struct {
	Info struct {
		State string `json:"state"`
	} `json:"info"`
}

func main() {
	startTime := time.Now()

	for {
		time.Sleep(5 * time.Second)
		logLine("Waiting for stellar-core to start catching up and sync")

		if time.Since(startTime) > timeout {
			logLine("Timeout")
			os.Exit(-1)
		}

		resp, err := http.Get("http://localhost:11626/info")
		if err != nil {
			logLine(err)
			continue
		}

		var info Info
		decoder := json.NewDecoder(resp.Body)
		err = decoder.Decode(&info)
		if err != nil {
			logLine(err)
			continue
		}

		logLine("Stellar-core is " + info.Info.State)
		if info.Info.State == "Catching up" || info.Info.State == "Synced!" {
			os.Exit(0)
		}
	}
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}
