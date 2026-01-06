package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"
)

const metaArchiveURL = "http://localhost:8000/meta-archive"

// ConfigFile represents the SEP-54 .config.json structure
type ConfigFile struct {
	NetworkPassphrase   string `json:"networkPassphrase"`
	Version             string `json:"version"`
	Compression         string `json:"compression"`
	LedgersPerBatch     int    `json:"ledgersPerBatch"`
	BatchesPerPartition int    `json:"batchesPerPartition"`
}

func main() {
	// Wait for galexie to export some ledgers
	// With ledgers_per_file=1 and files_per_partition=64000, ledger 2 would be at:
	// FFFFFFFF--0-63999/FFFFFFFD--2.xdr.zstd
	// The partition directory format is: %08X--%d-%d (MaxUint32-partitionStart, partitionStart, partitionEnd)
	// The file format is: %08X--%d.xdr.zstd (MaxUint32-fileStart, fileStart)

	partitionDir := "FFFFFFFF--0-63999"
	ledgerFile := "FFFFFFFD--2.xdr.zstd"
	metadataFile := "FFFFFFFD--2.json"

	// Test 1: Download and verify the SEP-54 .config.json file exists at the root
	configURL := fmt.Sprintf("%s/.config.json", metaArchiveURL)
	logLine("Waiting for SEP-54 .config.json file...")
	waitForConfigFile(configURL)
	logLine(fmt.Sprintf("Config file downloaded successfully! URL: %s", configURL))

	// Test 2: Wait for and verify the partition directory exists
	logLine("Waiting for meta archive partition directory...")
	waitForURL(fmt.Sprintf("%s/%s/", metaArchiveURL, partitionDir))
	logLine("Partition directory exists!")

	// Test 3: Download and verify a ledger file exists
	ledgerURL := fmt.Sprintf("%s/%s/%s", metaArchiveURL, partitionDir, ledgerFile)
	logLine(fmt.Sprintf("Waiting for ledger file: %s", ledgerFile))
	waitForFile(ledgerURL)
	logLine(fmt.Sprintf("Ledger file downloaded successfully! URL: %s", ledgerURL))

	// Test 4: Download and verify a metadata sidecar file exists
	metadataURL := fmt.Sprintf("%s/%s/%s", metaArchiveURL, partitionDir, metadataFile)
	logLine(fmt.Sprintf("Waiting for metadata file: %s", metadataFile))
	waitForFile(metadataURL)
	logLine(fmt.Sprintf("Metadata file downloaded successfully! URL: %s", metadataURL))

	logLine("All galexie meta archive tests passed!")
	os.Exit(0)
}

func waitForConfigFile(url string) {
	for {
		time.Sleep(5 * time.Second)
		resp, err := http.Get(url)
		if err != nil {
			logLine(fmt.Sprintf("Waiting for config... error: %v", err))
			continue
		}

		if resp.StatusCode == http.StatusOK {
			body, err := io.ReadAll(resp.Body)
			resp.Body.Close()
			if err != nil {
				logLine(fmt.Sprintf("Waiting for config... read error: %v", err))
				continue
			}

			logLine(fmt.Sprintf("Waiting for config... raw response: %s", string(body)))

			var config ConfigFile
			if err := json.Unmarshal(body, &config); err != nil {
				logLine(fmt.Sprintf("Waiting for config... JSON parse error: %v", err))
				continue
			}

			// Validate required fields are present
			if config.NetworkPassphrase == "" {
				logLine("Waiting for config... missing network_passphrase")
				continue
			}
			if config.Compression == "" {
				logLine("Waiting for config... missing compression")
				continue
			}

			logLine(fmt.Sprintf("Config file contents: network_passphrase=%s, compression=%s, ledgers_per_file=%d, files_per_partition=%d",
				config.NetworkPassphrase, config.Compression, config.LedgersPerBatch, config.BatchesPerPartition))
			return
		}
		resp.Body.Close()
		logLine(fmt.Sprintf("Waiting for config... status: %d", resp.StatusCode))
	}
}

func waitForURL(url string) {
	for {
		time.Sleep(5 * time.Second)
		resp, err := http.Get(url)
		if err != nil {
			logLine(fmt.Sprintf("Waiting... error: %v", err))
			continue
		}
		resp.Body.Close()

		if resp.StatusCode == http.StatusOK {
			return
		}
		logLine(fmt.Sprintf("Waiting... status: %d", resp.StatusCode))
	}
}

func waitForFile(url string) {
	for {
		time.Sleep(5 * time.Second)
		resp, err := http.Get(url)
		if err != nil {
			logLine(fmt.Sprintf("Waiting... error: %v", err))
			continue
		}

		if resp.StatusCode == http.StatusOK {
			// Read and verify we got actual content
			body, err := io.ReadAll(resp.Body)
			resp.Body.Close()
			if err != nil {
				logLine(fmt.Sprintf("Waiting... read error: %v", err))
				continue
			}

			if len(body) == 0 {
				logLine("Waiting... empty file")
				continue
			}

			// For .json files, verify it looks like JSON
			if strings.HasSuffix(url, ".json") {
				content := string(body)
				if !strings.HasPrefix(strings.TrimSpace(content), "{") {
					logLine(fmt.Sprintf("Waiting... not valid JSON: %s", content[:min(50, len(content))]))
					continue
				}
				logLine(fmt.Sprintf("Metadata content preview: %s...", content[:min(100, len(content))]))
			} else {
				logLine(fmt.Sprintf("File size: %d bytes", len(body)))
			}
			return
		}
		resp.Body.Close()
		logLine(fmt.Sprintf("Waiting... status: %d", resp.StatusCode))
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}
