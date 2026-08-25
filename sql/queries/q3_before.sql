-- Q3 — Doanh thu theo tháng từ 2024 (aggregate trên khoảng thời gian)
SELECT date_trunc('month', created_at) AS month, SUM(total) AS revenue
FROM orders
WHERE created_at >= '2024-01-01' AND status = 'paid'
GROUP BY 1
ORDER BY 1;
