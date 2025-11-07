package main

import (
	"context"
	"testing"

	"github.com/home-operations/containers/testhelpers"
)

func Test(t *testing.T) {
	ctx := context.Background()
	image := testhelpers.GetTestImage("ghcr.io/aedot/autto-m4b:rolling")
	testhelpers.TestFileExists(t, ctx, image, "/usr/local/bin/yq", nil)
}
