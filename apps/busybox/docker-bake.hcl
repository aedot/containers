package main

import (
	"context"
	"testing"

	"github.com/aedot/containers/testhelpers"
)

func Test(t *testing.T) {
	ctx := context.Background()
	image := testhelpers.GetTestImage("ghcr.io/aedot/busybox:rolling")
	testhelpers.TestCommandSucceeds(t, ctx, image, nil, "/bin/busybox", "--list")
}
