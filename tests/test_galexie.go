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
	ledgerFile := "FFFFFFFD--2.xdr.zst" // Expected file for ledger 2

	// Test 1: Download and verify the SEP-54 .config.json file exists at the root
	configURL := fmt.Sprintf("%s/.config.json", metaArchiveURL)
	logLine("Waiting for SEP-54 .config.json file...")
	waitForConfigFile(configURL)
	logLine(fmt.Sprintf("Config file downloaded successfully! URL: %s", configURL))

	// Test 2: Wait for and verify the partition directory exists
	logLine("Waiting for meta archive partition directory...")
	waitForURL(fmt.Sprintf("%s/%s/", metaArchiveURL, partitionDir))
	logLine("Partition directory exists!")

	// List partition directory contents and find a ledger file
	partitionURL := fmt.Sprintf("%s/%s/", metaArchiveURL, partitionDir)

	// Test 3: Wait for any ledger file to appear and download it
	logLine(fmt.Sprintf("Waiting for any ledger file in partition (expected: %s)...", ledgerFile))
	foundLedgerFile := waitForAnyLedgerFile(partitionURL)
	if foundLedgerFile == "" {
		logLine("ERROR: No ledger file found!")
		os.Exit(1)
	}
	logLine(fmt.Sprintf("Found ledger file: %s", foundLedgerFile))

	ledgerURL := fmt.Sprintf("%s/%s/%s", metaArchiveURL, partitionDir, foundLedgerFile)
	logLine(fmt.Sprintf("Downloading ledger file: %s", ledgerURL))
	waitForFile(ledgerURL)
	logLine(fmt.Sprintf("Ledger file downloaded successfully! URL: %s", ledgerURL))

	// Test 4: Download and verify the corresponding metadata sidecar file exists
	// Filesystem datastore writes metadata as <filename>.metadata.json
	foundMetadataFile := foundLedgerFile + ".metadata.json"
	metadataURL := fmt.Sprintf("%s/%s/%s", metaArchiveURL, partitionDir, foundMetadataFile)
	logLine(fmt.Sprintf("Waiting for metadata file: %s", foundMetadataFile))
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

		// Try to list the root directory to see what's there
		listResp, listErr := http.Get(metaArchiveURL + "/")
		if listErr == nil {
			body, _ := io.ReadAll(listResp.Body)
			listResp.Body.Close()
			logLine(fmt.Sprintf("Meta archive root listing: %s", string(body)[:min(500, len(body))]))
		}

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
		logLine(fmt.Sprintf("Waiting for %s... status: %d", url, resp.StatusCode))
	}
}

func listPartition(url string) {
	resp, err := http.Get(url)
	if err != nil {
		logLine(fmt.Sprintf("Error listing partition: %v", err))
		return
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		logLine(fmt.Sprintf("Error reading partition listing: %v", err))
		return
	}
	logLine(fmt.Sprintf("Partition directory listing: %s", string(body)))
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

		content := string(body)
		logLine(fmt.Sprintf("Partition listing: %s", content[:min(500, len(content))]))

		// Find any ledger file in the listing
		match := ledgerFilePattern.FindString(content)
		if match != "" {
			return match
		}

		logLine("Waiting for ledger files... no .xdr.zst files found yet")
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
