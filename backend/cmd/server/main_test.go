package main

import (
	"strings"
	"testing"
)

func TestValidateProductionEnvRequiresSecrets(t *testing.T) {
	t.Setenv("KASIR_ENV", "production")

	err := validateProductionEnv(productionMode())
	if err == nil {
		t.Fatal("expected missing production environment variables to fail")
	}
	if !strings.Contains(err.Error(), "KASIR_OWNER_TOKEN") {
		t.Fatalf("expected missing owner token in error, got %v", err)
	}
}

func TestValidateProductionEnvRejectsDevelopmentDefaults(t *testing.T) {
	t.Setenv("KASIR_ENV", "production")
	t.Setenv("KASIR_OWNER_TOKEN", "owner-demo-token")
	t.Setenv("KASIR_CASHIER_TOKEN", "cashier-demo-token")
	t.Setenv("KASIR_OWNER_PIN", "123456")
	t.Setenv("KASIR_ALLOWED_ORIGINS", "https://kasir.example.com")

	err := validateProductionEnv(productionMode())
	if err == nil {
		t.Fatal("expected development defaults to fail in production")
	}
	if !strings.Contains(err.Error(), "development default") {
		t.Fatalf("expected default secret error, got %v", err)
	}
}

func TestValidateProductionEnvAcceptsConfiguredSecrets(t *testing.T) {
	t.Setenv("KASIR_ENV", "production")
	t.Setenv("KASIR_OWNER_TOKEN", "owner-token-min-16-chars")
	t.Setenv("KASIR_CASHIER_TOKEN", "cashier-token-min-16-chars")
	t.Setenv("KASIR_OWNER_PIN", "654321")
	t.Setenv("KASIR_ALLOWED_ORIGINS", "https://kasir.example.com")

	if err := validateProductionEnv(productionMode()); err != nil {
		t.Fatalf("expected production env to be valid: %v", err)
	}
}

func TestValidateProductionEnvRejectsWildcardOrigin(t *testing.T) {
	t.Setenv("KASIR_ENV", "production")
	t.Setenv("KASIR_OWNER_TOKEN", "owner-token-min-16-chars")
	t.Setenv("KASIR_CASHIER_TOKEN", "cashier-token-min-16-chars")
	t.Setenv("KASIR_OWNER_PIN", "654321")
	t.Setenv("KASIR_ALLOWED_ORIGINS", "*")

	err := validateProductionEnv(productionMode())
	if err == nil {
		t.Fatal("expected wildcard origin to fail in production")
	}
	if !strings.Contains(err.Error(), "cannot be *") {
		t.Fatalf("expected wildcard origin error, got %v", err)
	}
}
