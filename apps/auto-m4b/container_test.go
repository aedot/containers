package main

import (
	"testing"

	helpers "github.com/aedot/containers/tests"
)

func Test(t *testing.T) {
	image := helpers.GetTestImage("ghcr.io/aedot/auto-m4b:rolling")
	helpers.RequireFileExists(t, image, "/usr/local/bin/auto-m4b-tool.sh")
	helpers.RequireCommandSucceeds(t, image, nil, "/usr/local/bin/m4b-tool", "--version")
}
