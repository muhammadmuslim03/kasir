package repository

import (
	"context"
	"database/sql"
	"encoding/base64"
	"errors"
	"fmt"
	"net/url"
	"sort"
	"strings"
	"time"

	"kasir-backend/internal/model"
)

var ErrNotFound = errors.New("data tidak ditemukan")

const maxImageDataBytes = 2 * 1024 * 1024

type RequestError struct {
	Message string
}

func (e RequestError) Error() string {
	return e.Message
}

type Store struct {
	db       *sql.DB
	location *time.Location
}

func New(db *sql.DB, location *time.Location) *Store {
	return &Store{db: db, location: location}
}

func (s *Store) SeedDefaultProducts(ctx context.Context) error {
	var count int
	if err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM products`).Scan(&count); err != nil {
		return fmt.Errorf("count products: %w", err)
	}

	if count > 0 {
		return nil
	}

	now := s.nowString()
	products := []model.ProductRequest{
		{Name: "Pentol Ghepek", SellingPrice: 15000, CostPrice: 10000},
		{Name: "Tahu Kocek", SellingPrice: 15000, CostPrice: 10000},
		{Name: "Mie Prindapan", SellingPrice: 15000, CostPrice: 10000},
		{Name: "Es Teh", SellingPrice: 3000, CostPrice: 1000},
		{Name: "Latte", SellingPrice: 20000, CostPrice: 15000},
		{Name: "Americano", SellingPrice: 17000, CostPrice: 13000},
	}

	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return fmt.Errorf("begin seed products: %w", err)
	}
	defer tx.Rollback()

	for _, product := range products {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO products (name, selling_price, cost_price, image_url, created_at, updated_at)
			VALUES (?, ?, ?, ?, ?, ?)
		`, product.Name, product.SellingPrice, product.CostPrice, product.ImageURL, now, now); err != nil {
			return fmt.Errorf("seed product: %w", err)
		}
	}

	return tx.Commit()
}

func (s *Store) ListProducts(ctx context.Context) ([]model.Product, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, name, selling_price, cost_price, image_url, created_at, updated_at
		FROM products
		WHERE deleted_at IS NULL
		ORDER BY name COLLATE NOCASE ASC
	`)
	if err != nil {
		return nil, fmt.Errorf("list products: %w", err)
	}
	defer rows.Close()

	products := make([]model.Product, 0)
	for rows.Next() {
		product, err := scanProduct(rows)
		if err != nil {
			return nil, err
		}
		products = append(products, product)
	}

	return products, rows.Err()
}

func (s *Store) CreateProduct(ctx context.Context, req model.ProductRequest) (model.Product, error) {
	if err := validateProductRequest(req); err != nil {
		return model.Product{}, err
	}

	now := s.nowString()
	result, err := s.db.ExecContext(ctx, `
		INSERT INTO products (name, selling_price, cost_price, image_url, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?)
	`, strings.TrimSpace(req.Name), req.SellingPrice, req.CostPrice, normalizeImageURL(req.ImageURL), now, now)
	if err != nil {
		return model.Product{}, fmt.Errorf("create product: %w", err)
	}

	id, err := result.LastInsertId()
	if err != nil {
		return model.Product{}, fmt.Errorf("create product id: %w", err)
	}

	return s.GetProduct(ctx, id)
}

func (s *Store) GetProduct(ctx context.Context, id int64) (model.Product, error) {
	if id <= 0 {
		return model.Product{}, RequestError{Message: "ID produk tidak valid"}
	}

	product, err := scanProduct(s.db.QueryRowContext(ctx, `
		SELECT id, name, selling_price, cost_price, image_url, created_at, updated_at
		FROM products
		WHERE id = ? AND deleted_at IS NULL
	`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return model.Product{}, ErrNotFound
	}
	if err != nil {
		return model.Product{}, err
	}

	return product, nil
}

func (s *Store) UpdateProduct(ctx context.Context, id int64, req model.ProductRequest) (model.Product, error) {
	if id <= 0 {
		return model.Product{}, RequestError{Message: "ID produk tidak valid"}
	}
	if err := validateProductRequest(req); err != nil {
		return model.Product{}, err
	}

	result, err := s.db.ExecContext(ctx, `
		UPDATE products
		SET name = ?, selling_price = ?, cost_price = ?, image_url = ?, updated_at = ?
		WHERE id = ? AND deleted_at IS NULL
	`, strings.TrimSpace(req.Name), req.SellingPrice, req.CostPrice, normalizeImageURL(req.ImageURL), s.nowString(), id)
	if err != nil {
		return model.Product{}, fmt.Errorf("update product: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return model.Product{}, fmt.Errorf("update product rows: %w", err)
	}
	if rowsAffected == 0 {
		return model.Product{}, ErrNotFound
	}

	return s.GetProduct(ctx, id)
}

func (s *Store) DeleteProduct(ctx context.Context, id int64) error {
	if id <= 0 {
		return RequestError{Message: "ID produk tidak valid"}
	}

	now := s.nowString()
	result, err := s.db.ExecContext(ctx, `
		UPDATE products
		SET deleted_at = ?, updated_at = ?
		WHERE id = ? AND deleted_at IS NULL
	`, now, now, id)
	if err != nil {
		return fmt.Errorf("delete product: %w", err)
	}

	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("delete product rows: %w", err)
	}
	if rowsAffected == 0 {
		return ErrNotFound
	}

	return nil
}

func (s *Store) Checkout(ctx context.Context, req model.CheckoutRequest) (model.Transaction, error) {
	items, err := normalizeCheckoutItems(req.Items)
	if err != nil {
		return model.Transaction{}, err
	}
	if req.CashReceived < 0 {
		return model.Transaction{}, RequestError{Message: "Uang diterima tidak boleh negatif"}
	}

	tx, err := s.db.BeginTx(ctx, &sql.TxOptions{})
	if err != nil {
		return model.Transaction{}, fmt.Errorf("begin checkout: %w", err)
	}
	defer tx.Rollback()

	txItems := make([]model.TransactionItem, 0, len(items))
	var totalAmount int64
	var estimatedProfit int64

	ids := make([]int64, 0, len(items))
	for productID := range items {
		ids = append(ids, productID)
	}
	sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })

	for _, productID := range ids {
		quantity := items[productID]
		product, err := scanProduct(tx.QueryRowContext(ctx, `
			SELECT id, name, selling_price, cost_price, image_url, created_at, updated_at
			FROM products
			WHERE id = ? AND deleted_at IS NULL
		`, productID))
		if errors.Is(err, sql.ErrNoRows) {
			return model.Transaction{}, RequestError{Message: fmt.Sprintf("Produk %d tidak ditemukan", productID)}
		}
		if err != nil {
			return model.Transaction{}, err
		}

		subtotal := product.SellingPrice * quantity
		profit := (product.SellingPrice - product.CostPrice) * quantity
		totalAmount += subtotal
		estimatedProfit += profit
		txItems = append(txItems, model.TransactionItem{
			ProductID:    product.ID,
			ProductName:  product.Name,
			Quantity:     quantity,
			SellingPrice: product.SellingPrice,
			CostPrice:    product.CostPrice,
			Subtotal:     subtotal,
			Profit:       profit,
		})
	}

	if req.CashReceived < totalAmount {
		return model.Transaction{}, RequestError{Message: "Uang diterima belum mencukupi"}
	}

	now := s.now()
	result, err := tx.ExecContext(ctx, `
		INSERT INTO transactions (transaction_number, total_amount, cash_received, change_amount, estimated_profit, transaction_date)
		VALUES (NULL, ?, ?, ?, ?, ?)
	`, totalAmount, req.CashReceived, req.CashReceived-totalAmount, estimatedProfit, now.Format(time.RFC3339))
	if err != nil {
		return model.Transaction{}, fmt.Errorf("insert transaction: %w", err)
	}

	transactionID, err := result.LastInsertId()
	if err != nil {
		return model.Transaction{}, fmt.Errorf("transaction id: %w", err)
	}
	transactionNumber := fmt.Sprintf("TRX-%04d", transactionID)

	if _, err := tx.ExecContext(ctx, `UPDATE transactions SET transaction_number = ? WHERE id = ?`, transactionNumber, transactionID); err != nil {
		return model.Transaction{}, fmt.Errorf("update transaction number: %w", err)
	}

	for index, item := range txItems {
		itemResult, err := tx.ExecContext(ctx, `
			INSERT INTO transaction_items (transaction_id, product_id, product_name, quantity, selling_price, cost_price, subtotal, profit)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?)
		`, transactionID, item.ProductID, item.ProductName, item.Quantity, item.SellingPrice, item.CostPrice, item.Subtotal, item.Profit)
		if err != nil {
			return model.Transaction{}, fmt.Errorf("insert transaction item: %w", err)
		}
		itemID, err := itemResult.LastInsertId()
		if err != nil {
			return model.Transaction{}, fmt.Errorf("transaction item id: %w", err)
		}
		txItems[index].ID = itemID
	}

	if err := tx.Commit(); err != nil {
		return model.Transaction{}, fmt.Errorf("commit checkout: %w", err)
	}

	return model.Transaction{
		ID:                transactionID,
		TransactionNumber: transactionNumber,
		TotalAmount:       totalAmount,
		CashReceived:      req.CashReceived,
		ChangeAmount:      req.CashReceived - totalAmount,
		EstimatedProfit:   estimatedProfit,
		TransactionDate:   now,
		Items:             txItems,
	}, nil
}

func (s *Store) ListTransactions(ctx context.Context, date string) ([]model.Transaction, error) {
	query := `
		SELECT id, transaction_number, total_amount, cash_received, change_amount, estimated_profit, transaction_date
		FROM transactions
	`
	args := []any{}
	if date != "" {
		if err := validateDate(date); err != nil {
			return nil, err
		}
		query += ` WHERE substr(transaction_date, 1, 10) = ?`
		args = append(args, date)
	}
	query += ` ORDER BY transaction_date DESC, id DESC`

	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("list transactions: %w", err)
	}

	transactions := make([]model.Transaction, 0)
	for rows.Next() {
		transaction, err := scanTransaction(rows)
		if err != nil {
			rows.Close()
			return nil, err
		}
		transactions = append(transactions, transaction)
	}
	if err := rows.Err(); err != nil {
		rows.Close()
		return nil, err
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}

	for index := range transactions {
		items, err := s.listTransactionItems(ctx, transactions[index].ID)
		if err != nil {
			return nil, err
		}
		transactions[index].Items = items
	}

	return transactions, nil
}

func (s *Store) GetTransaction(ctx context.Context, id int64) (model.Transaction, error) {
	if id <= 0 {
		return model.Transaction{}, RequestError{Message: "ID transaksi tidak valid"}
	}

	transaction, err := scanTransaction(s.db.QueryRowContext(ctx, `
		SELECT id, transaction_number, total_amount, cash_received, change_amount, estimated_profit, transaction_date
		FROM transactions
		WHERE id = ?
	`, id))
	if errors.Is(err, sql.ErrNoRows) {
		return model.Transaction{}, ErrNotFound
	}
	if err != nil {
		return model.Transaction{}, err
	}

	items, err := s.listTransactionItems(ctx, transaction.ID)
	if err != nil {
		return model.Transaction{}, err
	}
	transaction.Items = items

	return transaction, nil
}

func (s *Store) DailyReport(ctx context.Context, date string) (model.DailyReport, error) {
	if date == "" {
		date = s.now().Format("2006-01-02")
	}
	if err := validateDate(date); err != nil {
		return model.DailyReport{}, err
	}

	transactions, err := s.ListTransactions(ctx, date)
	if err != nil {
		return model.DailyReport{}, err
	}

	report := model.DailyReport{
		Date:         date,
		Transactions: transactions,
	}

	for _, transaction := range transactions {
		report.TotalSales += transaction.TotalAmount
		report.TransactionCount++
		report.EstimatedProfit += transaction.EstimatedProfit
		for _, item := range transaction.Items {
			report.TotalItemsSold += item.Quantity
		}
	}

	return report, nil
}

func (s *Store) listTransactionItems(ctx context.Context, transactionID int64) ([]model.TransactionItem, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, product_id, product_name, quantity, selling_price, cost_price, subtotal, profit
		FROM transaction_items
		WHERE transaction_id = ?
		ORDER BY id ASC
	`, transactionID)
	if err != nil {
		return nil, fmt.Errorf("list transaction items: %w", err)
	}
	defer rows.Close()

	items := make([]model.TransactionItem, 0)
	for rows.Next() {
		var item model.TransactionItem
		if err := rows.Scan(
			&item.ID,
			&item.ProductID,
			&item.ProductName,
			&item.Quantity,
			&item.SellingPrice,
			&item.CostPrice,
			&item.Subtotal,
			&item.Profit,
		); err != nil {
			return nil, fmt.Errorf("scan transaction item: %w", err)
		}
		items = append(items, item)
	}

	return items, rows.Err()
}

func validateProductRequest(req model.ProductRequest) error {
	if strings.TrimSpace(req.Name) == "" {
		return RequestError{Message: "Nama produk wajib diisi"}
	}
	if req.SellingPrice < 0 {
		return RequestError{Message: "Harga jual tidak boleh negatif"}
	}
	if req.CostPrice < 0 {
		return RequestError{Message: "Harga modal tidak boleh negatif"}
	}
	if err := validateImageURL(req.ImageURL); err != nil {
		return err
	}

	return nil
}

func validateImageURL(value string) error {
	value = normalizeImageURL(value)
	if value == "" {
		return nil
	}
	if strings.HasPrefix(strings.ToLower(value), "data:") {
		return validateImageDataURL(value)
	}
	if len(value) > 2048 {
		return RequestError{Message: "Data gambar terlalu panjang"}
	}

	parsed, err := url.ParseRequestURI(value)
	if err != nil || parsed.Scheme == "" || parsed.Host == "" {
		return RequestError{Message: "URL gambar tidak valid"}
	}
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return RequestError{Message: "URL gambar harus diawali http atau https"}
	}

	return nil
}

func validateImageDataURL(value string) error {
	metadata, encoded, ok := strings.Cut(value, ",")
	if !ok || encoded == "" {
		return RequestError{Message: "Data gambar tidak valid"}
	}

	metadata = strings.ToLower(metadata)
	validMetadata := metadata == "data:image/jpeg;base64" ||
		metadata == "data:image/jpg;base64" ||
		metadata == "data:image/png;base64" ||
		metadata == "data:image/webp;base64" ||
		metadata == "data:image/gif;base64"
	if !validMetadata {
		return RequestError{Message: "Format gambar harus JPG, PNG, WEBP, atau GIF"}
	}

	if base64.StdEncoding.DecodedLen(len(encoded)) > maxImageDataBytes {
		return RequestError{Message: "Ukuran gambar maksimal 2 MB"}
	}
	decoded, err := base64.StdEncoding.Strict().DecodeString(encoded)
	if err != nil || len(decoded) == 0 {
		return RequestError{Message: "Data gambar tidak valid"}
	}
	if len(decoded) > maxImageDataBytes {
		return RequestError{Message: "Ukuran gambar maksimal 2 MB"}
	}

	return nil
}

func normalizeImageURL(value string) string {
	return strings.TrimSpace(value)
}

func normalizeCheckoutItems(items []model.CheckoutItemRequest) (map[int64]int64, error) {
	if len(items) == 0 {
		return nil, RequestError{Message: "Keranjang masih kosong"}
	}

	normalized := make(map[int64]int64)
	for _, item := range items {
		if item.ProductID <= 0 {
			return nil, RequestError{Message: "ID produk tidak valid"}
		}
		if item.Quantity <= 0 {
			return nil, RequestError{Message: "Jumlah barang harus lebih dari 0"}
		}
		normalized[item.ProductID] += item.Quantity
	}

	return normalized, nil
}

func validateDate(date string) error {
	if _, err := time.Parse("2006-01-02", date); err != nil {
		return RequestError{Message: "Format tanggal harus YYYY-MM-DD"}
	}

	return nil
}

func scanProduct(scanner interface{ Scan(dest ...any) error }) (model.Product, error) {
	var product model.Product
	var imageURL sql.NullString
	var createdAt string
	var updatedAt string
	if err := scanner.Scan(
		&product.ID,
		&product.Name,
		&product.SellingPrice,
		&product.CostPrice,
		&imageURL,
		&createdAt,
		&updatedAt,
	); err != nil {
		return model.Product{}, err
	}

	product.ImageURL = imageURL.String
	product.CreatedAt = parseTime(createdAt)
	product.UpdatedAt = parseTime(updatedAt)

	return product, nil
}

func scanTransaction(scanner interface{ Scan(dest ...any) error }) (model.Transaction, error) {
	var transaction model.Transaction
	var transactionDate string
	if err := scanner.Scan(
		&transaction.ID,
		&transaction.TransactionNumber,
		&transaction.TotalAmount,
		&transaction.CashReceived,
		&transaction.ChangeAmount,
		&transaction.EstimatedProfit,
		&transactionDate,
	); err != nil {
		return model.Transaction{}, err
	}

	transaction.TransactionDate = parseTime(transactionDate)
	transaction.Items = []model.TransactionItem{}

	return transaction, nil
}

func parseTime(value string) time.Time {
	parsed, err := time.Parse(time.RFC3339, value)
	if err != nil {
		return time.Time{}
	}

	return parsed
}

func (s *Store) now() time.Time {
	return time.Now().In(s.location)
}

func (s *Store) nowString() string {
	return s.now().Format(time.RFC3339)
}
