-- Q1 — Lấy 50 đơn 'paid' mới nhất (Top-N sau khi lọc)
SELECT id, customer_id, total, created_at
FROM orders
WHERE status = 'paid'
ORDER BY created_at DESC
LIMIT 50;
