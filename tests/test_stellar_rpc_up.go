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

type RPCResponse struct {
	Result struct {
		Status string `json:"status"`
	} `json:"result"`
	Error struct {
		Message string `json:"message"`
	} `json:"error"`
}

func main() {
	getHealthRPCRequest := []byte(`{
	   "jsonrpc": "2.0",
	   "id": 10235,
	   "method": "getHealth"
	}`)

	for {
		time.Sleep(5 * time.Second)
		logLine("Waiting for Stellar RPC to start")

		resp, err := http.Post("http://localhost:8000/rpc", "application/json", bytes.NewBuffer(getHealthRPCRequest))
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

		logLine(fmt.Sprintf("Stellar RPC health reponse %#v", rpcResponse))

		if rpcResponse.Result.Status != "" || rpcResponse.Error.Message != "" {
			logLine("Stellar RPC has started!")
			os.Exit(0)
		}
	}
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}
