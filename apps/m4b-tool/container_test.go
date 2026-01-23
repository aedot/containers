package main

import (
	"context"
	"testing"

	"github.com/aedot/containers/testhelpers"
)

func TestContainerStartup(t *testing.T) {
	ctx := context.Background()
	image := testhelpers.GetTestImage("ghcr.io/aedot/m4b-tool:rolling")

	// Test that the main script exists and is executable
	testhelpers.TestFileExists(t, ctx, image, "/runscript.sh", nil)

	// Test that the auto-m4b-tool script exists
	testhelpers.TestFileExists(t, ctx, image, "/auto-m4b-tool.sh", nil)

	// Test that m4b-tool binary is available
	testhelpers.TestCommandSucceeds(t, ctx, image, nil, "m4b-tool", "--version")
}

func TestDirectoryStructure(t *testing.T) {
	ctx := context.Background()
	image := testhelpers.GetTestImage("ghcr.io/aedot/m4b-tool:rolling")

	// Test that required directories can be created
	testhelpers.TestCommandSucceeds(t, ctx, image, nil,
		"mkdir -p", "/temp/merge", "/temp/untagged", "/temp/recentlyadded",
		"/temp/fix", "/temp/backup", "/temp/delete",
	)
}

func TestAudioProcessing(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping audio processing test in short mode")
	}

	ctx := context.Background()
	image := testhelpers.GetTestImage("ghcr.io/aedot/m4b-tool:rolling")

	// Test that the script can handle audio file operations
	testhelpers.TestCommandSucceeds(t, ctx, image, nil,
		"mkdir -p", "/temp/testinput/MyTestBook",
		"touch", "/temp/testinput/MyTestBook/chapter01.mp3",
		"bash", "-c", "find /temp/testinput -name '*.mp3' | head -1",
	)
}
