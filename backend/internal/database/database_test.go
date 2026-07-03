package database

import (
	"context"
	"database/sql"
	"path/filepath"
	"testing"

	_ "modernc.org/sqlite"
)

func TestOpenMigratesProductsWithoutStockColumns(t *testing.T) {
	ctx := context.Background()
	dsn := "file:" + filepath.ToSlash(filepath.Join(t.TempDir(), "kasir.db")) + "?_pragma=foreign_keys(1)&_pragma=busy_timeout(5000)"

	seedOldSchema(t, dsn)

	db, err := Open(ctx, dsn)
	if err != nil {
		t.Fatalf("open migrated database: %v", err)
	}
	defer db.Close()

	columns, err := productColumns(ctx, db)
	if err != nil {
		t.Fatalf("inspect migrated columns: %v", err)
	}
	if columns["stock_quantity"] || columns["low_stock_limit"] {
		t.Fatalf("stock columns should be removed, got %#v", columns)
	}
	if !columns["image_url"] {
		t.Fatalf("image_url column should exist, got %#v", columns)
	}
	if !columns["deleted_at"] {
		t.Fatalf("deleted_at column should exist, got %#v", columns)
	}

	var name string
	var imageURL string
	if err := db.QueryRowContext(ctx, `SELECT name, image_url FROM products WHERE id = 1`).Scan(&name, &imageURL); err != nil {
		t.Fatalf("read migrated product: %v", err)
	}
	if name != "Es Teh" || imageURL != "" {
		t.Fatalf("unexpected migrated product: name=%q image_url=%q", name, imageURL)
	}

	var itemCount int
	if err := db.QueryRowContext(ctx, `SELECT COUNT(*) FROM transaction_items WHERE product_id = 1`).Scan(&itemCount); err != nil {
		t.Fatalf("read migrated transaction items: %v", err)
	}
	if itemCount != 1 {
		t.Fatalf("expected transaction item to remain linked, got %d", itemCount)
	}

	rows, err := db.QueryContext(ctx, `PRAGMA foreign_key_check`)
	if err != nil {
		t.Fatalf("foreign key check: %v", err)
	}
	defer rows.Close()
	if rows.Next() {
		t.Fatal("expected migrated database to pass foreign key check")
	}
}

func seedOldSchema(t *testing.T, dsn string) {
	t.Helper()

	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		t.Fatalf("open old database: %v", err)
	}
	defer db.Close()

	statements := []string{
		`PRAGMA foreign_keys = ON;`,
		`CREATE TABLE products (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			selling_price INTEGER NOT NULL CHECK (selling_price >= 0),
			cost_price INTEGER NOT NULL CHECK (cost_price >= 0),
			stock_quantity INTEGER NOT NULL CHECK (stock_quantity >= 0),
			low_stock_limit INTEGER NOT NULL CHECK (low_stock_limit >= 0),
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL
		);`,
		`CREATE TABLE transactions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			transaction_number TEXT UNIQUE,
			total_amount INTEGER NOT NULL CHECK (total_amount >= 0),
			cash_received INTEGER NOT NULL CHECK (cash_received >= 0),
			change_amount INTEGER NOT NULL CHECK (change_amount >= 0),
			estimated_profit INTEGER NOT NULL,
			transaction_date TEXT NOT NULL
		);`,
		`CREATE TABLE transaction_items (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			transaction_id INTEGER NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
			product_id INTEGER NOT NULL REFERENCES products(id),
			product_name TEXT NOT NULL,
			quantity INTEGER NOT NULL CHECK (quantity > 0),
			selling_price INTEGER NOT NULL CHECK (selling_price >= 0),
			cost_price INTEGER NOT NULL CHECK (cost_price >= 0),
			subtotal INTEGER NOT NULL CHECK (subtotal >= 0),
			profit INTEGER NOT NULL
		);`,
		`INSERT INTO products (id, name, selling_price, cost_price, stock_quantity, low_stock_limit, created_at, updated_at)
			VALUES (1, 'Es Teh', 3000, 1000, 25, 8, '2026-06-21T10:00:00+07:00', '2026-06-21T10:00:00+07:00');`,
		`INSERT INTO transactions (id, transaction_number, total_amount, cash_received, change_amount, estimated_profit, transaction_date)
			VALUES (1, 'TRX-0001', 3000, 5000, 2000, 2000, '2026-06-21T10:10:00+07:00');`,
		`INSERT INTO transaction_items (transaction_id, product_id, product_name, quantity, selling_price, cost_price, subtotal, profit)
			VALUES (1, 1, 'Es Teh', 1, 3000, 1000, 3000, 2000);`,
	}

	for _, statement := range statements {
		if _, err := db.Exec(statement); err != nil {
			t.Fatalf("seed old schema: %v", err)
		}
	}
}
