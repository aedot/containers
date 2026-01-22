package main

import (
	"context"
	"testing"

	"github.com/aedot/containers/testhelpers"
)

func Test(t *testing.T) {
	ctx := context.Background()
	image := testhelpers.GetTestImage("ghcr.io/aedot/m4b-tool:rolling")
	testhelpers.TestFileExists(t, ctx, image, "/runscript.sh", nil)
}
