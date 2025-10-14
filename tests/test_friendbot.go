package main

import (
	"log"
	"net/http"
	"net/url"
	"os"
	"time"
)

func main() {
	for {
		time.Sleep(10 * time.Second)
		logLine("Waiting for Friendbot to be available")

		params := url.Values{}
		params.Set("addr", "GDDVAW5VBBMSKIGNHCZIRZ3BCDQXKO7TCPGEPJR4KL72RHAL2R2ETEST")
		resp, err := http.Get("http://localhost:8000/friendbot?" + params.Encode())
		if err != nil {
			logLine(err)
			continue
		}

		if resp.StatusCode == 200 {
			logLine("Friendbot is available!")
			os.Exit(0)
		}
	}
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test_friendbot]\033[0m", text)
}
