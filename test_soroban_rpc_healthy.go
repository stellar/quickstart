package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"
)

const timeout = 6 * time.Minute

type RPCResponse struct {
	Result struct {
		Status string `json:"status"`
	} `json:"result"`
	Error struct {
		Message string `json:"message"`
	} `json:"error"`
}

func main() {
	startTime := time.Now()

	getHealthRPCRequest := []byte(`{
	   "jsonrpc": "2.0",
	   "id": 10235,
	   "method": "getHealth"
	}`)

	for {
		time.Sleep(5 * time.Second)
		logLine("Waiting for Soroban RPC to start")

		if time.Since(startTime) > timeout {
			logLine("Timeout")
			os.Exit(-1)
		}

		resp, err := http.Post("http://localhost:8000/soroban/rpc", "application/json", bytes.NewBuffer(getHealthRPCRequest))
		if err != nil {
			logLine(err)
			continue
		}

		var rpcResponse RPCResponse
		decoder := json.NewDecoder(resp.Body)
		err = decoder.Decode(&rpcResponse)
		if err != nil {
			logLine(err)
			continue
		}

		logLine(fmt.Sprintf("Soroban RPC health reponse %#v", rpcResponse))

		if rpcResponse.Result.Status == "healthy" {
			logLine("Soroban RPC is healthy!")
			os.Exit(0)
		}
	}
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}
