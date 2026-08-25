package app

import (
	"os"
	"strings"
	"testing"
)

func TestBuildRunnerWrapsGinWithSecurityHeadersAtHTTPBoundary(t *testing.T) {
	raw, err := os.ReadFile("bootstrap.go")
	if err != nil {
		t.Fatalf("read bootstrap.go: %v", err)
	}
	source := string(raw)
	setup := strings.Index(source, "engine := httpserver.SetupRouter(cfg, dependencies)")
	security := strings.Index(source, "handler := httpservermiddleware.SecurityHeadersHandler(cfg.Server.Mode, engine)")
	server := strings.Index(source, "httpService := NewHTTPService(addr, handler)")
	if setup < 0 || security < 0 || server < 0 {
		t.Fatalf("HTTP security boundary missing: setup=%d security=%d server=%d", setup, security, server)
	}
	if !(setup < security && security < server) {
		t.Fatalf("Gin engine must be wrapped before it is assigned to the HTTP server")
	}
}
