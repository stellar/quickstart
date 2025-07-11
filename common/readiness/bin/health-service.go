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

type HealthResponse struct {
	Status   string            `json:"status"`
	Services map[string]string `json:"services"`
}

type RPCResponse struct {
	Result struct {
		Status string `json:"status"`
	} `json:"result"`
	Error struct {
		Message string `json:"message"`
	} `json:"error"`
}

type HorizonRoot struct {
	SupportedProtocolVersion int32 `json:"supported_protocol_version"`
	CoreLatestLedger         int32 `json:"core_latest_ledger"`
	HistoryLatestLedger      int32 `json:"history_latest_ledger"`
}

func main() {
	log.Println("Starting health service on port 8004")
	
	http.HandleFunc("/", healthHandler)
	if err := http.ListenAndServe(":8004", nil); err != nil {
		log.Fatal("Health service failed to start:", err)
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	response := HealthResponse{
		Status:   "healthy",
		Services: make(map[string]string),
	}
	
	enableCore := os.Getenv("ENABLE_CORE") == "true"
	enableHorizon := os.Getenv("ENABLE_HORIZON") == "true"
	enableRPC := os.Getenv("ENABLE_RPC") == "true"
	
	allHealthy := true
	
	// Check stellar-core if enabled
	if enableCore {
		if coreHealthy := checkStellarCore(); coreHealthy {
			response.Services["stellar-core"] = "healthy"
		} else {
			response.Services["stellar-core"] = "unhealthy"
			allHealthy = false
		}
	}
	
	// Check horizon if enabled
	if enableHorizon {
		if horizonHealthy := checkHorizon(); horizonHealthy {
			response.Services["horizon"] = "healthy"
		} else {
			response.Services["horizon"] = "unhealthy"
			allHealthy = false
		}
	}
	
	// Check stellar-rpc if enabled
	if enableRPC {
		if rpcHealthy := checkStellarRPC(); rpcHealthy {
			response.Services["stellar-rpc"] = "healthy"
		} else {
			response.Services["stellar-rpc"] = "unhealthy"
			allHealthy = false
		}
	}
	
	if !allHealthy {
		response.Status = "unhealthy"
		w.WriteHeader(http.StatusServiceUnavailable)
	} else {
		w.WriteHeader(http.StatusOK)
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func checkStellarCore() bool {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get("http://localhost:11626/info")
	if err != nil {
		log.Printf("stellar-core check failed: %v", err)
		return false
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		log.Printf("stellar-core returned status: %d", resp.StatusCode)
		return false
	}
	
	// For now, just check if the service responds
	// Could be enhanced to check sync status
	return true
}

func checkHorizon() bool {
	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get("http://localhost:8001")
	if err != nil {
		log.Printf("horizon check failed: %v", err)
		return false
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		log.Printf("horizon returned status: %d", resp.StatusCode)
		return false
	}
	
	var root HorizonRoot
	decoder := json.NewDecoder(resp.Body)
	err = decoder.Decode(&root)
	if err != nil {
		log.Printf("horizon response decode failed: %v", err)
		return false
	}
	
	// Check that horizon is properly started and ingesting
	return root.SupportedProtocolVersion > 0 && root.CoreLatestLedger > 0 && root.HistoryLatestLedger > 0
}

func checkStellarRPC() bool {
	client := &http.Client{Timeout: 5 * time.Second}
	
	getHealthRPCRequest := []byte(`{
		"jsonrpc": "2.0",
		"id": 10235,
		"method": "getHealth"
	}`)
	
	resp, err := client.Post("http://localhost:8003", "application/json", bytes.NewBuffer(getHealthRPCRequest))
	if err != nil {
		log.Printf("stellar-rpc check failed: %v", err)
		return false
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		log.Printf("stellar-rpc returned status: %d", resp.StatusCode)
		return false
	}
	
	var rpcResponse RPCResponse
	decoder := json.NewDecoder(resp.Body)
	err = decoder.Decode(&rpcResponse)
	if err != nil {
		log.Printf("stellar-rpc response decode failed: %v", err)
		return false
	}
	
	return rpcResponse.Result.Status == "healthy"
}