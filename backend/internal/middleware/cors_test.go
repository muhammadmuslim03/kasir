package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCORSAllowsAllOriginsByDefault(t *testing.T) {
	handler := CORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodGet, "/healthz", nil)
	request.Header.Set("Origin", "https://kasir.example.com")

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", recorder.Code)
	}
	if got := recorder.Header().Get("Access-Control-Allow-Origin"); got != "*" {
		t.Fatalf("expected wildcard origin, got %q", got)
	}
}

func TestCORSAllowsConfiguredOrigin(t *testing.T) {
	t.Setenv("KASIR_ALLOWED_ORIGINS", "https://kasir.example.com, https://admin.example.com/")
	handler := CORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodOptions, "/api/products", nil)
	request.Header.Set("Origin", "https://admin.example.com")

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusNoContent {
		t.Fatalf("expected status 204, got %d", recorder.Code)
	}
	if got := recorder.Header().Get("Access-Control-Allow-Origin"); got != "https://admin.example.com" {
		t.Fatalf("expected configured origin, got %q", got)
	}
}

func TestCORSRejectsDisallowedPreflightOrigin(t *testing.T) {
	t.Setenv("KASIR_ALLOWED_ORIGINS", "https://kasir.example.com")
	handler := CORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		t.Fatal("next handler should not run for rejected preflight")
	}))

	recorder := httptest.NewRecorder()
	request := httptest.NewRequest(http.MethodOptions, "/api/products", nil)
	request.Header.Set("Origin", "https://evil.example.com")

	handler.ServeHTTP(recorder, request)

	if recorder.Code != http.StatusForbidden {
		t.Fatalf("expected status 403, got %d", recorder.Code)
	}
	if got := recorder.Header().Get("Access-Control-Allow-Origin"); got != "" {
		t.Fatalf("expected no allowed origin, got %q", got)
	}
}
