-- Q6 — Lấy đơn trong đúng 1 ngày, dùng hàm bọc lên cột
SELECT * FROM orders WHERE date_trunc('day', created_at) = '2024-06-01';
