package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"reflect"
	"time"
)

type Info struct {
	Info struct {
		State string `json:"state"`
	} `json:"info"`
}

func main() {
	settingsPath := flag.String("soroban-settings", "", "Expected Soroban settings JSON file")
	container := flag.String("container", "stellar", "Container containing stellar-xdr")
	timeout := flag.Duration("timeout", 0, "Maximum wait time (zero means no limit)")
	flag.Parse()

	var expectedSettings map[string]interface{}
	if *settingsPath != "" {
		settingsJSON, err := os.ReadFile(*settingsPath)
		if err != nil {
			log.Fatal(err)
		}
		expectedSettings, err = readSorobanSettings(bytes.NewReader(settingsJSON))
		if err != nil {
			log.Fatal(err)
		}
	}

	client := &http.Client{Timeout: 10 * time.Second}
	started := time.Now()
	for {
		if *timeout > 0 && time.Since(started) >= *timeout {
			log.Fatal("Timed out waiting for stellar-core and expected Soroban settings")
		}
		time.Sleep(5 * time.Second)
		logLine("Waiting for stellar-core to start catching up and sync")

		resp, err := client.Get("http://localhost:11626/info")
		if err != nil {
			logLine(err)
			continue
		}

		var info Info
		decoder := json.NewDecoder(resp.Body)
		err = decoder.Decode(&info)
		resp.Body.Close()
		if err != nil {
			logLine(err)
			continue
		}

		logLine("Stellar-core is " + info.Info.State)
		if info.Info.State == "Catching up" || info.Info.State == "Synced!" {
			if expectedSettings != nil {
				actualSettings, err := fetchSorobanSettings(client, *container)
				if err != nil {
					logLine(err)
					continue
				}
				if !reflect.DeepEqual(actualSettings, expectedSettings) {
					logLine("Waiting for Soroban settings to match " + *settingsPath)
					continue
				}
				logLine(fmt.Sprintf("All %d Soroban settings match %s", len(expectedSettings), *settingsPath))
			}
			os.Exit(0)
		}
	}
}

func readSorobanSettings(reader io.Reader) (map[string]interface{}, error) {
	var upgrade struct {
		UpdatedEntry []map[string]interface{} `json:"updated_entry"`
	}
	decoder := json.NewDecoder(reader)
	decoder.UseNumber()
	if err := decoder.Decode(&upgrade); err != nil {
		return nil, err
	}
	settings := make(map[string]interface{})
	for _, entry := range upgrade.UpdatedEntry {
		if len(entry) != 1 {
			return nil, fmt.Errorf("expected one setting per upgrade entry")
		}
		for name, value := range entry {
			if _, exists := settings[name]; exists {
				return nil, fmt.Errorf("duplicate Soroban setting: %s", name)
			}
			settings[name] = value
		}
	}
	if len(settings) == 0 {
		return nil, fmt.Errorf("no Soroban settings in upgrade")
	}
	return settings, nil
}

func fetchSorobanSettings(client *http.Client, container string) (map[string]interface{}, error) {
	resp, err := client.Get("http://localhost:11626/sorobaninfo?format=upgrade_xdr")
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("sorobaninfo returned HTTP %d", resp.StatusCode)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	command := exec.CommandContext(ctx, "docker", "exec", "-i", container, "stellar-xdr", "decode", "--type", "ConfigUpgradeSet", "--output", "json-formatted")
	command.Stdin = resp.Body
	settingsJSON, err := command.CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("decode Soroban settings: %w: %s", err, settingsJSON)
	}
	return readSorobanSettings(bytes.NewReader(settingsJSON))
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test]\033[0m", text)
}
