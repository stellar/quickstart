package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"regexp"
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
	// FFFFFFFF--0-63999/FFFFFFFD--2.xdr.zst
	// The partition directory format is: %08X--%d-%d (MaxUint32-partitionStart, partitionStart, partitionEnd)
	// The file format is: %08X--%d.xdr.zst (MaxUint32-fileStart, fileStart)

	partitionDir := "FFFFFFFF--0-63999"

	// Test 1: Download and verify the SEP-54 .config.json file exists at the root
	configURL := fmt.Sprintf("%s/.config.json", metaArchiveURL)
	logLine("Waiting for .config.json file...")
	waitForConfigFile(configURL)
	logLine("Config file validated!")

	// Test 2: Wait for and verify the partition directory exists
	partitionURL := fmt.Sprintf("%s/%s/", metaArchiveURL, partitionDir)
	logLine("Waiting for partition directory...")
	waitForURL(partitionURL)
	logLine("Partition directory exists!")

	// Test 3: Wait for any ledger file to appear and download it
	logLine("Waiting for ledger file...")
	foundLedgerFile := waitForAnyLedgerFile(partitionURL)
	if foundLedgerFile == "" {
		logLine("ERROR: No ledger file found!")
		os.Exit(1)
	}
	logLine(fmt.Sprintf("Found ledger file: %s", foundLedgerFile))

	ledgerURL := fmt.Sprintf("%s/%s/%s", metaArchiveURL, partitionDir, foundLedgerFile)
	waitForFile(ledgerURL)
	logLine("Ledger file downloaded!")

	// Test 4: Download and verify the corresponding metadata sidecar file exists
	// Filesystem datastore writes metadata as <filename>.metadata.json
	metadataFile := foundLedgerFile + ".metadata.json"
	metadataURL := fmt.Sprintf("%s/%s/%s", metaArchiveURL, partitionDir, metadataFile)
	logLine(fmt.Sprintf("Waiting for metadata file: %s", metadataFile))
	waitForFile(metadataURL)
	logLine("Metadata file downloaded!")

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

			var config ConfigFile
			if err := json.Unmarshal(body, &config); err != nil {
				logLine(fmt.Sprintf("Waiting for config... JSON parse error: %v", err))
				continue
			}

			// Validate required fields are present
			if config.NetworkPassphrase == "" {
				logLine("Waiting for config... missing networkPassphrase")
				continue
			}
			if config.Compression == "" {
				logLine("Waiting for config... missing compression")
				continue
			}

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
			logLine(fmt.Sprintf("Waiting for %s... error: %v", url, err))
			continue
		}
		resp.Body.Close()

		if resp.StatusCode == http.StatusOK {
			return
		}
		logLine(fmt.Sprintf("Waiting for %s... status: %d", url, resp.StatusCode))
	}
}

func waitForFile(url string) {
	for {
		time.Sleep(5 * time.Second)
		resp, err := http.Get(url)
		if err != nil {
			logLine(fmt.Sprintf("Waiting for %s... error: %v", url, err))
			continue
		}

		if resp.StatusCode == http.StatusOK {
			body, err := io.ReadAll(resp.Body)
			resp.Body.Close()
			if err != nil {
				logLine(fmt.Sprintf("Waiting for %s... read error: %v", url, err))
				continue
			}

			if len(body) == 0 {
				logLine(fmt.Sprintf("Waiting for %s... empty file", url))
				continue
			}

			// For .json files, verify it looks like JSON
			if strings.HasSuffix(url, ".json") {
				content := string(body)
				if !strings.HasPrefix(strings.TrimSpace(content), "{") {
					logLine(fmt.Sprintf("Waiting for %s... not valid JSON", url))
					continue
				}
			}
			return
		}
		resp.Body.Close()
		logLine(fmt.Sprintf("Waiting for %s... status: %d", url, resp.StatusCode))
	}
}

func waitForAnyLedgerFile(partitionURL string) string {
	// Pattern to match ledger files like "FFFFFFFD--2.xdr.zst"
	ledgerFilePattern := regexp.MustCompile(`[0-9A-Fa-f]{8}--\d+\.xdr\.zst`)

	for {
		time.Sleep(5 * time.Second)
		resp, err := http.Get(partitionURL)
		if err != nil {
			logLine(fmt.Sprintf("Waiting for ledger files... error: %v", err))
			continue
		}

		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			logLine(fmt.Sprintf("Waiting for ledger files... read error: %v", err))
			continue
		}

		// Find any ledger file in the listing
		match := ledgerFilePattern.FindString(string(body))
		if match != "" {
			return match
		}

		logLine("Waiting for ledger files...")
	}
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}
