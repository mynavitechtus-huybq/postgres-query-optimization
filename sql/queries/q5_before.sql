-- Q5 — Đếm số đơn của từng khách VN bằng correlated subquery
SELECT c.id, c.email,
  (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.id) AS order_count
FROM customers c
WHERE c.country = 'VN';
