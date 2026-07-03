package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"kasir-backend/internal/controller"
	"kasir-backend/internal/database"
	"kasir-backend/internal/repository"
)

func main() {
	addr := flag.String("addr", defaultAddr(), "HTTP listen address")
	dsn := flag.String("db", defaultDSN(), "SQLite DSN")
	flag.Parse()

	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
	production := productionMode()
	if err := validateProductionEnv(production); err != nil {
		logger.Error("production configuration is not ready", "error", err)
		os.Exit(1)
	}

	location, err := time.LoadLocation("Asia/Jakarta")
	if err != nil {
		logger.Warn("failed to load Asia/Jakarta timezone, using fixed WIB", "error", err)
		location = time.FixedZone("WIB", 7*60*60)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	db, err := database.Open(ctx, *dsn)
	if err != nil {
		logger.Error("database initialization failed", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	store := repository.New(db, location)
	if err := store.SeedDefaultProducts(ctx); err != nil {
		logger.Error("seed data failed", "error", err)
		os.Exit(1)
	}

	api := controller.New(store, logger)
	server := &http.Server{
		Handler:           api.Routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	listener, err := net.Listen("tcp", *addr)
	if err != nil {
		logger.Error("server port is not available", "addr", *addr, "error", err, "hint", "stop the old server or run with -addr :8081")
		os.Exit(1)
	}

	serverErrors := make(chan error, 1)
	go func() {
		logger.Info("kasir backend listening", "addr", listener.Addr().String())
		if err := server.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serverErrors <- err
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	select {
	case <-stop:
	case err := <-serverErrors:
		logger.Error("server failed", "error", err)
		os.Exit(1)
	}

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("server shutdown failed", "error", err)
		os.Exit(1)
	}
	logger.Info("kasir backend stopped")
}

func defaultAddr() string {
	if value := strings.TrimSpace(os.Getenv("KASIR_ADDR")); value != "" {
		return value
	}

	if port := strings.TrimSpace(os.Getenv("PORT")); port != "" {
		if strings.HasPrefix(port, ":") {
			return port
		}
		return ":" + port
	}

	return ":8080"
}

func defaultDSN() string {
	if value := strings.TrimSpace(os.Getenv("KASIR_DB_DSN")); value != "" {
		return value
	}

	return "file:kasir.db?_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)"
}

func productionMode() bool {
	value := strings.ToLower(strings.TrimSpace(os.Getenv("KASIR_ENV")))
	return value == "production" || value == "prod"
}

func validateProductionEnv(production bool) error {
	if !production {
		return nil
	}

	required := []string{
		"KASIR_OWNER_TOKEN",
		"KASIR_CASHIER_TOKEN",
		"KASIR_OWNER_PIN",
		"KASIR_ALLOWED_ORIGINS",
	}
	missing := make([]string, 0)
	for _, name := range required {
		if strings.TrimSpace(os.Getenv(name)) == "" {
			missing = append(missing, name)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("missing required environment variables: %s", strings.Join(missing, ", "))
	}

	if err := validateProductionSecret("KASIR_OWNER_TOKEN", os.Getenv("KASIR_OWNER_TOKEN"), "owner-demo-token", 16); err != nil {
		return err
	}
	if err := validateProductionSecret("KASIR_CASHIER_TOKEN", os.Getenv("KASIR_CASHIER_TOKEN"), "cashier-demo-token", 16); err != nil {
		return err
	}
	if err := validateProductionSecret("KASIR_OWNER_PIN", os.Getenv("KASIR_OWNER_PIN"), "123456", 6); err != nil {
		return err
	}

	for _, origin := range strings.Split(os.Getenv("KASIR_ALLOWED_ORIGINS"), ",") {
		if strings.TrimSpace(origin) == "*" {
			return fmt.Errorf("KASIR_ALLOWED_ORIGINS cannot be * in production")
		}
	}

	return nil
}

func validateProductionSecret(name, value, forbidden string, minLength int) error {
	value = strings.TrimSpace(value)
	if value == forbidden {
		return fmt.Errorf("%s must not use the development default", name)
	}
	if len(value) < minLength {
		return fmt.Errorf("%s must be at least %d characters", name, minLength)
	}

	return nil
}
