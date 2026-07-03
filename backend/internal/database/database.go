package database

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	_ "modernc.org/sqlite"
)

func Open(ctx context.Context, dsn string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}

	db.SetMaxOpenConns(1)
	db.SetMaxIdleConns(1)
	db.SetConnMaxLifetime(time.Hour)

	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("ping database: %w", err)
	}

	if err := migrate(ctx, db); err != nil {
		db.Close()
		return nil, err
	}

	return db, nil
}

func migrate(ctx context.Context, db *sql.DB) error {
	statements := []string{
		`PRAGMA journal_mode = WAL;`,
		`PRAGMA foreign_keys = ON;`,
		`PRAGMA busy_timeout = 5000;`,
	}

	for _, statement := range statements {
		if _, err := db.ExecContext(ctx, statement); err != nil {
			return fmt.Errorf("migrate database: %w", err)
		}
	}

	if err := migrateProducts(ctx, db); err != nil {
		return err
	}

	statements = []string{
		`CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);`,
		`CREATE TABLE IF NOT EXISTS transactions (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			transaction_number TEXT UNIQUE,
			total_amount INTEGER NOT NULL CHECK (total_amount >= 0),
			cash_received INTEGER NOT NULL CHECK (cash_received >= 0),
			change_amount INTEGER NOT NULL CHECK (change_amount >= 0),
			estimated_profit INTEGER NOT NULL,
			transaction_date TEXT NOT NULL
		);`,
		`CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(transaction_date);`,
		`CREATE TABLE IF NOT EXISTS transaction_items (
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
		`CREATE INDEX IF NOT EXISTS idx_transaction_items_transaction ON transaction_items(transaction_id);`,
	}

	for _, statement := range statements {
		if _, err := db.ExecContext(ctx, statement); err != nil {
			return fmt.Errorf("migrate database: %w", err)
		}
	}

	return nil
}

func migrateProducts(ctx context.Context, db *sql.DB) error {
	var tableName string
	err := db.QueryRowContext(ctx, `
		SELECT name
		FROM sqlite_master
		WHERE type = 'table' AND name = 'products'
	`).Scan(&tableName)
	if err == sql.ErrNoRows {
		_, err = db.ExecContext(ctx, createProductsTableSQL("products"))
		if err != nil {
			return fmt.Errorf("create products table: %w", err)
		}
		return nil
	}
	if err != nil {
		return fmt.Errorf("inspect products table: %w", err)
	}

	columns, err := productColumns(ctx, db)
	if err != nil {
		return err
	}
	if columns["image_url"] && columns["deleted_at"] && !columns["stock_quantity"] && !columns["low_stock_limit"] {
		return nil
	}

	if _, err := db.ExecContext(ctx, `PRAGMA foreign_keys = OFF;`); err != nil {
		return fmt.Errorf("disable foreign keys for products migration: %w", err)
	}
	defer db.ExecContext(context.Background(), `PRAGMA foreign_keys = ON;`)

	tx, err := db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin products migration: %w", err)
	}
	defer tx.Rollback()

	if _, err := tx.ExecContext(ctx, `DROP TABLE IF EXISTS products_migration`); err != nil {
		return fmt.Errorf("drop stale products migration table: %w", err)
	}
	if _, err := tx.ExecContext(ctx, createProductsTableSQL("products_migration")); err != nil {
		return fmt.Errorf("create products migration table: %w", err)
	}

	imageExpression := `''`
	if columns["image_url"] {
		imageExpression = `COALESCE(image_url, '')`
	}
	deletedAtExpression := `NULL`
	if columns["deleted_at"] {
		deletedAtExpression = `deleted_at`
	}
	copySQL := fmt.Sprintf(`
		INSERT INTO products_migration (id, name, selling_price, cost_price, image_url, created_at, updated_at, deleted_at)
		SELECT id, name, selling_price, cost_price, %s, created_at, updated_at, %s
		FROM products
	`, imageExpression, deletedAtExpression)
	if _, err := tx.ExecContext(ctx, copySQL); err != nil {
		return fmt.Errorf("copy products migration data: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `DROP TABLE products`); err != nil {
		return fmt.Errorf("drop old products table: %w", err)
	}
	if _, err := tx.ExecContext(ctx, `ALTER TABLE products_migration RENAME TO products`); err != nil {
		return fmt.Errorf("rename products migration table: %w", err)
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("commit products migration: %w", err)
	}

	return nil
}

func productColumns(ctx context.Context, db *sql.DB) (map[string]bool, error) {
	rows, err := db.QueryContext(ctx, `PRAGMA table_info(products)`)
	if err != nil {
		return nil, fmt.Errorf("inspect products columns: %w", err)
	}
	defer rows.Close()

	columns := map[string]bool{}
	for rows.Next() {
		var cid int
		var name string
		var columnType string
		var notNull int
		var defaultValue sql.NullString
		var primaryKey int
		if err := rows.Scan(&cid, &name, &columnType, &notNull, &defaultValue, &primaryKey); err != nil {
			return nil, fmt.Errorf("scan products column: %w", err)
		}
		columns[name] = true
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("inspect products columns rows: %w", err)
	}

	return columns, nil
}

func createProductsTableSQL(name string) string {
	return fmt.Sprintf(`CREATE TABLE IF NOT EXISTS %s (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT NOT NULL,
		selling_price INTEGER NOT NULL CHECK (selling_price >= 0),
		cost_price INTEGER NOT NULL CHECK (cost_price >= 0),
		image_url TEXT NOT NULL DEFAULT '',
		created_at TEXT NOT NULL,
		updated_at TEXT NOT NULL,
		deleted_at TEXT
	);`, name)
}
