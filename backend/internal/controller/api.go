package controller

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"kasir-backend/internal/middleware"
	"kasir-backend/internal/model"
	"kasir-backend/internal/repository"
)

const requestTimeout = 8 * time.Second

type API struct {
	store        *repository.Store
	logger       *slog.Logger
	ownerToken   string
	cashierToken string
	ownerPIN     string
}

func New(store *repository.Store, logger *slog.Logger) *API {
	ownerToken := strings.TrimSpace(os.Getenv("KASIR_OWNER_TOKEN"))
	if ownerToken == "" {
		ownerToken = "owner-demo-token"
	}

	cashierToken := strings.TrimSpace(os.Getenv("KASIR_CASHIER_TOKEN"))
	if cashierToken == "" {
		cashierToken = "cashier-demo-token"
	}

	ownerPIN := strings.TrimSpace(os.Getenv("KASIR_OWNER_PIN"))
	if ownerPIN == "" {
		ownerPIN = "123456"
	}

	return &API{
		store:        store,
		logger:       logger,
		ownerToken:   ownerToken,
		cashierToken: cashierToken,
		ownerPIN:     ownerPIN,
	}
}

func (api *API) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", api.health)
	mux.HandleFunc("POST /api/auth/demo-login", api.demoLogin)
	mux.HandleFunc("GET /api/products", api.listProducts)
	mux.HandleFunc("POST /api/products", api.createProduct)
	mux.HandleFunc("PUT /api/products/{id}", api.updateProduct)
	mux.HandleFunc("DELETE /api/products/{id}", api.deleteProduct)
	mux.HandleFunc("POST /api/checkout", api.checkout)
	mux.HandleFunc("GET /api/transactions", api.listTransactions)
	mux.HandleFunc("GET /api/transactions/{id}", api.getTransaction)
	mux.HandleFunc("GET /api/reports/daily", api.dailyReport)

	return middleware.CORS(mux)
}

func (api *API) health(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (api *API) demoLogin(w http.ResponseWriter, r *http.Request) {
	var req model.DemoLoginRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	switch req.Role {
	case model.RoleOwner:
		if req.PIN != api.ownerPIN {
			writeError(w, http.StatusUnauthorized, "PIN pemilik tidak valid")
			return
		}
		writeJSON(w, http.StatusOK, model.DemoLoginResponse{Token: api.ownerToken, Role: model.RoleOwner})
	case model.RoleCashier:
		writeJSON(w, http.StatusOK, model.DemoLoginResponse{Token: api.cashierToken, Role: model.RoleCashier})
	default:
		writeError(w, http.StatusBadRequest, "Role harus owner atau cashier")
	}
}

func (api *API) listProducts(w http.ResponseWriter, r *http.Request) {
	if _, ok := api.requireRole(w, r, model.RoleOwner, model.RoleCashier); !ok {
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), requestTimeout)
	defer cancel()

	products, err := api.store.ListProducts(ctx)
	if err != nil {
		api.handleError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, products)
}

func (api *API) createProduct(w http.ResponseWriter, r *http.Request) {
	if _, ok := api.requireRole(w, r, model.RoleOwner, model.RoleCashier); !ok {
		return
	}

	var req model.ProductRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), requestTimeout)
	defer cancel()

	product, err := api.store.CreateProduct(ctx, req)
	if err != nil {
		api.handleError(w, err)
		return
	}

	writeJSON(w, http.StatusCreated, product)
}

func (api *API) updateProduct(w http.ResponseWriter, r *http.Request) {
	if _, ok := api.requireRole(w, r, model.RoleOwner, model.RoleCashier); !ok {
		return
	}

	id, ok := pathID(w, r)
	if !ok {
		return
	}

	var req model.ProductRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), requestTimeout)
	defer cancel()

	product, err := api.store.UpdateProduct(ctx, id, req)
	if err != nil {
		api.handleError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, product)
}

func (api *API) deleteProduct(w http.ResponseWriter, r *http.Request) {
	if _, ok := api.requireRole(w, r, model.RoleOwner); !ok {
		return
	}

	id, ok := pathID(w, r)
	if !ok {
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), requestTimeout)
	defer cancel()

	if err := api.store.DeleteProduct(ctx, id); err != nil {
		api.handleError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{"status": "deleted"})
}

func (api *API) checkout(w http.ResponseWriter, r *http.Request) {
	if _, ok := api.requireRole(w, r, model.RoleOwner, model.RoleCashier); !ok {
		return
	}

	var req model.CheckoutRequest
	if !decodeJSON(w, r, &req) {
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), requestTimeout)
	defer cancel()

	transaction, err := api.store.Checkout(ctx, req)
	if err != nil {
		api.handleError(w, err)
		return
	}

	writeJSON(w, http.StatusCreated, transaction)
}

func (api *API) listTransactions(w http.ResponseWriter, r *http.Request) {
	if _, ok := api.requireRole(w, r, model.RoleOwner, model.RoleCashier); !ok {
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), requestTimeout)
	defer cancel()

	transactions, err := api.store.ListTransactions(ctx, r.URL.Query().Get("date"))
	if err != nil {
		api.handleError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, transactions)
}

func (api *API) getTransaction(w http.ResponseWriter, r *http.Request) {
	if _, ok := api.requireRole(w, r, model.RoleOwner, model.RoleCashier); !ok {
		return
	}

	id, ok := pathID(w, r)
	if !ok {
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), requestTimeout)
	defer cancel()

	transaction, err := api.store.GetTransaction(ctx, id)
	if err != nil {
		api.handleError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, transaction)
}

func (api *API) dailyReport(w http.ResponseWriter, r *http.Request) {
	if _, ok := api.requireRole(w, r, model.RoleOwner); !ok {
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), requestTimeout)
	defer cancel()

	report, err := api.store.DailyReport(ctx, r.URL.Query().Get("date"))
	if err != nil {
		api.handleError(w, err)
		return
	}

	writeJSON(w, http.StatusOK, report)
}

func (api *API) requireRole(w http.ResponseWriter, r *http.Request, allowedRoles ...model.Role) (model.AuthUser, bool) {
	user, ok := api.authenticate(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, "Token login tidak valid")
		return model.AuthUser{}, false
	}

	for _, role := range allowedRoles {
		if user.Role == role {
			return user, true
		}
	}

	writeError(w, http.StatusForbidden, "Akses fitur dibatasi untuk role ini")
	return model.AuthUser{}, false
}

func (api *API) authenticate(r *http.Request) (model.AuthUser, bool) {
	header := strings.TrimSpace(r.Header.Get("Authorization"))
	if header == "" {
		return model.AuthUser{}, false
	}

	token := header
	if strings.HasPrefix(strings.ToLower(header), "bearer ") {
		token = strings.TrimSpace(header[7:])
	}

	switch token {
	case api.ownerToken:
		return model.AuthUser{Role: model.RoleOwner}, true
	case api.cashierToken:
		return model.AuthUser{Role: model.RoleCashier}, true
	default:
		return model.AuthUser{}, false
	}
}

func (api *API) handleError(w http.ResponseWriter, err error) {
	var requestError repository.RequestError
	switch {
	case errors.As(err, &requestError):
		writeError(w, http.StatusBadRequest, requestError.Message)
	case errors.Is(err, repository.ErrNotFound):
		writeError(w, http.StatusNotFound, "Data tidak ditemukan")
	default:
		api.logger.Error("request failed", "error", err)
		writeError(w, http.StatusInternalServerError, "Terjadi kesalahan server")
	}
}

func decodeJSON(w http.ResponseWriter, r *http.Request, target any) bool {
	defer r.Body.Close()
	decoder := json.NewDecoder(r.Body)
	decoder.DisallowUnknownFields()

	if err := decoder.Decode(target); err != nil {
		writeError(w, http.StatusBadRequest, "JSON request tidak valid")
		return false
	}

	return true
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}

func pathID(w http.ResponseWriter, r *http.Request) (int64, bool) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		writeError(w, http.StatusBadRequest, "ID tidak valid")
		return 0, false
	}

	return id, true
}
