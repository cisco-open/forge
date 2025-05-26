package ui

import (
	"log"
	"net/http"
)

// RunServer monta as rotas e inicia o servidor HTTP.
func RunServer(addr string) error {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("Hello, World!"))
	})

	log.Printf("Server listening on %s", addr)
	return http.ListenAndServe(addr, nil)
}
