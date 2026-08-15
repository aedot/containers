package main

import (
	"testing"

	helpers "github.com/aedot/containers/tests"
)

func Test(t *testing.T) {
	image := helpers.GetTestImage("ghcr.io/aedot/busybox:rolling")
	helpers.RequireCommandSucceeds(t, image, nil, "/bin/busybox", "--list")
}
