package main

import (
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"
)

// This test verifies that libfaketime is active in the container and that
// writing an offset to /etc/faketimerc changes the time seen by processes
// inside the container. It jumps time forward by 24 hours and checks that the
// container clock moves forward by approximately the same amount.

const offsetSeconds = 24 * 60 * 60 // +24h
const toleranceSeconds = 60 * 60   // allow an hour of slack for timing/propagation

func containerEpoch() int64 {
	out, err := exec.Command("docker", "exec", "stellar", "date", "+%s").Output()
	if err != nil {
		logLine(err)
		return 0
	}
	epoch, err := strconv.ParseInt(strings.TrimSpace(string(out)), 10, 64)
	if err != nil {
		logLine(err)
		return 0
	}
	return epoch
}

func main() {
	logLine("Reading baseline container time")
	baseline := containerEpoch()

	logLine("Writing +24h offset to /etc/faketimerc")
	cmd := exec.Command("docker", "exec", "stellar", "bash", "-c", `echo "+24h" > /etc/faketimerc`)
	if out, err := cmd.CombinedOutput(); err != nil {
		logLine(string(out))
		log.Fatal(err)
	}

	for i := 0; i < 12; i++ {
		time.Sleep(5 * time.Second)
		logLine("Waiting for faketime offset to take effect")

		now := containerEpoch()
		delta := now - baseline
		logLine("Container time advanced by " + strconv.FormatInt(delta, 10) + " seconds")

		if delta >= offsetSeconds-toleranceSeconds && delta <= offsetSeconds+toleranceSeconds {
			logLine("Faketime offset applied successfully!")
			os.Exit(0)
		}
	}

	log.Fatal("Faketime offset was not applied within the timeout")
}

func logLine(text interface{}) {
	log.Println("\033[32;1m[test_faketime]\033[0m", text)
}
