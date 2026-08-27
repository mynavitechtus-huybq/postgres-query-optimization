-- Q3 — SAU khi tối ưu.
--
-- V2 giữ nguyên query gốc, chỉ thêm partial covering index. Dùng bản này khi
-- cần số liệu realtime:
--
--   SELECT date_trunc('month', created_at) AS month, SUM(total) AS revenue
--   FROM orders
--   WHERE created_at >= '2024-01-01' AND status = 'paid'
--   GROUP BY 1 ORDER BY 1;
--
-- V3 đọc từ bảng đã gộp sẵn. Dùng bản này cho báo cáo/dashboard, chấp nhận dữ
-- liệu cũ tối đa bằng chu kỳ refresh.
SELECT month, revenue
FROM monthly_paid_revenue
WHERE month >= DATE '2024-01-01'
ORDER BY month;
