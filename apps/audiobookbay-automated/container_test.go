package main

import (
	"testing"
	"time"

	helpers "github.com/aedot/containers/tests"
)

func Test(t *testing.T) {
	image := helpers.GetTestImage("ghcr.io/aedot/audiobookbay-automated:rolling")
	helpers.RequireHTTPEndpoint(t, image, helpers.HTTPTestConfig{
		Port:       "5078",
		Path:       "/",
		StatusCode: 200,
		Timeout:    60 * time.Second,
	}, nil)
}
