-- Q3 — SAU khi tối ưu.
--
-- V3, phương án chính. Bỏ GROUP BY trên biểu thức: sinh sẵn danh sách mốc tháng
-- rồi với mỗi tháng cộng riêng qua LATERAL. Không còn chỗ để planner đoán sai số
-- nhóm nên không còn Sort 250.983 dòng và không còn đổ đĩa.
-- Dùng lại partial index idx_orders_paid_created_at. Dữ liệu realtime.
-- 134.8 ms -> 28.8 ms
SELECT m.month, x.revenue
FROM generate_series(
       date_trunc('month', TIMESTAMPTZ '2024-01-01'),
       (SELECT max(created_at) FROM orders),
       interval '1 month') AS m(month)
CROSS JOIN LATERAL (
  SELECT SUM(o.total) AS revenue
  FROM orders o
  WHERE o.status = 'paid'
    AND o.created_at >= m.month
    AND o.created_at <  m.month + interval '1 month'
) x
WHERE x.revenue IS NOT NULL
ORDER BY m.month;


-- V4, dùng cho dashboard nếu chấp nhận dữ liệu cũ theo chu kỳ refresh.
-- 28.8 ms -> 0.040 ms, đổi lại phải có lịch REFRESH và kết quả chốt theo UTC.
--
--   SELECT month, revenue
--   FROM monthly_paid_revenue
--   WHERE month >= DATE '2024-01-01'
--   ORDER BY month;
