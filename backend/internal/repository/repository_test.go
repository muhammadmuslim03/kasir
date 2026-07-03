package repository

import (
	"context"
	"path/filepath"
	"testing"
	"time"

	"kasir-backend/internal/database"
	"kasir-backend/internal/model"
)

func TestDeleteProductHidesMenuWithExistingTransaction(t *testing.T) {
	ctx := context.Background()
	dsn := "file:" + filepath.ToSlash(filepath.Join(t.TempDir(), "kasir.db")) + "?_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)"
	db, err := database.Open(ctx, dsn)
	if err != nil {
		t.Fatalf("open database: %v", err)
	}
	defer db.Close()

	store := New(db, time.FixedZone("WIB", 7*60*60))
	product, err := store.CreateProduct(ctx, model.ProductRequest{
		Name:         "Menu Terjual",
		SellingPrice: 15000,
		CostPrice:    9000,
	})
	if err != nil {
		t.Fatalf("create product: %v", err)
	}

	transaction, err := store.Checkout(ctx, model.CheckoutRequest{
		CashReceived: 30000,
		Items: []model.CheckoutItemRequest{
			{ProductID: product.ID, Quantity: 2},
		},
	})
	if err != nil {
		t.Fatalf("checkout: %v", err)
	}
	if len(transaction.Items) != 1 {
		t.Fatalf("expected one transaction item, got %d", len(transaction.Items))
	}

	if err := store.DeleteProduct(ctx, product.ID); err != nil {
		t.Fatalf("delete product with transaction: %v", err)
	}

	products, err := store.ListProducts(ctx)
	if err != nil {
		t.Fatalf("list products: %v", err)
	}
	for _, listed := range products {
		if listed.ID == product.ID {
			t.Fatalf("deleted product should be hidden from menu list: %#v", listed)
		}
	}

	savedTransaction, err := store.GetTransaction(ctx, transaction.ID)
	if err != nil {
		t.Fatalf("get transaction after product delete: %v", err)
	}
	if len(savedTransaction.Items) != 1 || savedTransaction.Items[0].ProductName != product.Name {
		t.Fatalf("transaction history should remain readable: %#v", savedTransaction.Items)
	}
}
