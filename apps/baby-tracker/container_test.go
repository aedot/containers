package main

import (
	"testing"
	"time"

	helpers "github.com/aedot/containers/tests"
)

func Test(t *testing.T) {
	image := helpers.GetTestImage("ghcr.io/aedot/baby-tracker:rolling")
	helpers.RequireHTTPEndpoint(t, image, helpers.HTTPTestConfig{
		Port:       "8099",
		Path:       "/api/config",
		StatusCode: 200,
		Timeout:    60 * time.Second,
	}, &helpers.ContainerConfig{
		// No broker in the test; keep startup from blocking on MQTT.
		Env: map[string]string{"MQTT_ENABLED": "0"},
	})
}
