-- Q6 — SAU khi sửa: bỏ hàm bọc lên cột, dùng khoảng thời gian nửa mở
--
-- Điều kiện dạng `date_trunc('day', created_at) = '...'` là NON-SARGABLE:
-- cột bị bọc trong hàm nên Postgres phải tính hàm đó cho từng dòng mới biết
-- có khớp không => bắt buộc quét toàn bảng, index vô dụng.
--
-- Viết lại thành so sánh trực tiếp trên cột (SARGABLE) thì index dùng được.
-- Dùng khoảng nửa mở [đầu, cuối) thay vì BETWEEN để không phải bận tâm tới
-- độ chính xác của timestamp (BETWEEN ... AND '2024-06-01 23:59:59' sẽ bỏ sót
-- các dòng rơi vào 23:59:59.5).
SELECT * FROM orders
WHERE created_at >= '2024-06-01'
  AND created_at <  '2024-06-02';
