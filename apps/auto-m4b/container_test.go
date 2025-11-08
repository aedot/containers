package main

import (
	"context"
	"testing"
	"time"

	"github.com/aedot/containers/testhelpers"
)

func TestContainerStarts(t *testing.T) {
	ctx := context.Background()

	// Use the updated image name
	image := testhelpers.GetTestImage("ghcr.io/aedot/auto-m4b:alpine")

	// Run the container and wait for it to start
	container, err := testhelpers.RunContainer(ctx, image, nil)
	if err != nil {
		t.Fatalf("Failed to start container: %v", err)
	}
	defer container.Terminate(ctx)

	// Give the entrypoint script a few seconds to initialize
	time.Sleep(5 * time.Second)

	// Check container logs for expected startup message
	logs, err := container.Logs(ctx)
	if err != nil {
		t.Fatalf("Failed to fetch container logs: %v", err)
	}

	if !containsExpectedStartupMessage(logs) {
		t.Errorf("Container did not start as expected, logs:\n%s", logs)
	}
}

// Helper function to detect startup logs
func containsExpectedStartupMessage(logs string) bool {
	// Adjust this based on what your entrypoint prints
	expectedMessages := []string{
		"Created missing",    // user creation
		"Using all CPU cores", // default CPU detection
		"No folders detected", // default m4b-tool loop
	}

	for _, msg := range expectedMessages {
		if !testhelpers.StringContains(logs, msg) {
			return false
		}
	}
	return true
}
