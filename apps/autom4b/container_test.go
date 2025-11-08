package main

import (
	"context"
	"testing"
	"time"

	"github.com/aedot/containers/testhelpers"
)

// TestContainerStarts ensures the autom4b container boots correctly and runs its entrypoint logic.
func TestContainerStarts(t *testing.T) {
	ctx := context.Background()

	image := testhelpers.GetTestImage("ghcr.io/aedot/autom4b:rolling")

	// Run the container and wait for it to initialize
	container, err := testhelpers.RunContainer(ctx, image, nil)
	if err != nil {
		t.Fatalf("failed to start container: %v", err)
	}
	defer func() {
		if err := container.Terminate(ctx); err != nil {
			t.Logf("failed to terminate container: %v", err)
		}
	}()

	// Allow entrypoint.sh to initialize properly
	time.Sleep(5 * time.Second)

	// Fetch container logs
	logs, err := container.Logs(ctx)
	if err != nil {
		t.Fatalf("failed to fetch container logs: %v", err)
	}

	// Check for expected startup messages
	expectedMessages := []string{
		"Created missing",    // user creation log
		"Using",              // CPU core detection
		"Sleeping",           // main loop activity
	}

	for _, msg := range expectedMessages {
		if !testhelpers.StringContains(logs, msg) {
			t.Errorf("expected log message containing %q not found.\n--- Logs ---\n%s", msg, logs)
		}
	}
}
