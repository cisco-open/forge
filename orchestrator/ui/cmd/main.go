package main

import (
	"log"

	"github.com/cisco-open/forge/orchestrator/internal/shared"

	"github.com/cisco-open/forge/orchestrator/ui"
)

func main() {
	shared.PrintSharedMessage("UI")
	if err := ui.RunServer(":8080"); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
