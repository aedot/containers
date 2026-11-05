package main

import (
	"testing"

	helpers "github.com/aedot/containers/tests"
)

func Test(t *testing.T) {
	image := helpers.GetTestImage("ghcr.io/aedot/beets-audible:rolling")
	helpers.RequireFileExists(t, image, "/entrypoint.sh")
	helpers.RequireCommandSucceeds(t, image, nil, "python", "-c", "import beetsplug.audible")
}
