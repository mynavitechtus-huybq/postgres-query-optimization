-- Kiểm tra dữ liệu đã nạp đủ chưa.
-- Kỳ vọng: 50000 / 5000 / 1000000 / 3000000
SELECT 'customers'   AS table_name, count(*) AS row_count FROM customers
UNION ALL SELECT 'products',    count(*) FROM products
UNION ALL SELECT 'orders',      count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items;

-- Kiểm tra thống kê đã được cập nhật (last_analyze phải có giá trị)
SELECT relname, n_live_tup, last_analyze, last_autoanalyze
FROM pg_stat_user_tables
ORDER BY relname;
