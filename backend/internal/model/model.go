package model

import "time"

type Role string

const (
	RoleOwner   Role = "owner"
	RoleCashier Role = "cashier"
)

type AuthUser struct {
	Role Role `json:"role"`
}

type DemoLoginRequest struct {
	Role Role   `json:"role"`
	PIN  string `json:"pin"`
}

type DemoLoginResponse struct {
	Token string `json:"token"`
	Role  Role   `json:"role"`
}

type Product struct {
	ID           int64     `json:"id"`
	Name         string    `json:"name"`
	SellingPrice int64     `json:"selling_price"`
	CostPrice    int64     `json:"cost_price"`
	ImageURL     string    `json:"image_url"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type ProductRequest struct {
	Name         string `json:"name"`
	SellingPrice int64  `json:"selling_price"`
	CostPrice    int64  `json:"cost_price"`
	ImageURL     string `json:"image_url"`
}

type CheckoutItemRequest struct {
	ProductID int64 `json:"product_id"`
	Quantity  int64 `json:"quantity"`
}

type CheckoutRequest struct {
	Items        []CheckoutItemRequest `json:"items"`
	CashReceived int64                 `json:"cash_received"`
}

type Transaction struct {
	ID                int64             `json:"id"`
	TransactionNumber string            `json:"transaction_number"`
	TotalAmount       int64             `json:"total_amount"`
	CashReceived      int64             `json:"cash_received"`
	ChangeAmount      int64             `json:"change_amount"`
	EstimatedProfit   int64             `json:"estimated_profit"`
	TransactionDate   time.Time         `json:"transaction_date"`
	Items             []TransactionItem `json:"items"`
}

type TransactionItem struct {
	ID           int64  `json:"id"`
	ProductID    int64  `json:"product_id"`
	ProductName  string `json:"product_name"`
	Quantity     int64  `json:"quantity"`
	SellingPrice int64  `json:"selling_price"`
	CostPrice    int64  `json:"cost_price"`
	Subtotal     int64  `json:"subtotal"`
	Profit       int64  `json:"profit"`
}

type DailyReport struct {
	Date             string        `json:"date"`
	TotalSales       int64         `json:"total_sales"`
	TransactionCount int64         `json:"transaction_count"`
	EstimatedProfit  int64         `json:"estimated_profit"`
	TotalItemsSold   int64         `json:"total_items_sold"`
	Transactions     []Transaction `json:"transactions"`
}
