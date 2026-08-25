-- Q2 — Chi tiết toàn bộ đơn hàng của 1 khách (join 3 bảng)
SELECT o.id, o.created_at, p.name, oi.quantity, oi.unit_price
FROM orders o
JOIN order_items oi ON oi.order_id = o.id
JOIN products p     ON p.id = oi.product_id
WHERE o.customer_id = 777;
