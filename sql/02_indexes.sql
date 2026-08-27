-- =============================================================
-- 02_indexes.sql — Toàn bộ thay đổi schema trong quá trình tối ưu.
-- Khối rollback ở cuối file.
-- =============================================================

-- -------------------------------------------------------------
-- Q1 — Top 50 đơn 'paid' mới nhất
--
-- Vấn đề : Parallel Seq Scan đọc cả 1.000.000 dòng, vứt đi 749.016 dòng,
--          rồi Sort 250.984 dòng chỉ để lấy ra 50 dòng.
-- Cách sửa: composite index đưa nhóm 'paid' về một dải liền mạch, và trong
--          dải đó dữ liệu đã sẵn thứ tự created_at DESC => bỏ hẳn Sort.
-- Thứ tự cột: cột so sánh BẰNG (status) đứng trước, cột SẮP XẾP (created_at)
--          đứng sau. Đảo lại thì status nằm rải rác, không gom được dải nào.
-- Ghi chú : DESC ở đây không bắt buộc — Postgres quét index ngược được.
--          Viết DESC để khớp ý định của query, đọc code hiểu ngay.
-- Kết quả : 80.632 ms -> 0.731 ms (110x) | 8.678 -> 53 block (164x)
CREATE INDEX idx_orders_status_created_at ON orders (status, created_at DESC);


-- -------------------------------------------------------------
-- Q2 — Chi tiết đơn hàng của một khách (join 3 bảng)
--
-- Vấn đề : FOREIGN KEY không tự sinh index ở bảng con. Thiếu index trên
--          orders.customer_id và order_items.order_id nên planner buộc phải
--          Hash Join: quét sạch 3.000.000 dòng order_items + 1.000.000 dòng
--          orders => chạm ~4 triệu dòng chỉ để trả về 51 dòng.
-- Cách sửa: index cho 2 cột khoá ngoại được join. Có index rồi thì Nested Loop
--          trở nên rẻ hơn Hash Join, planner tự đổi chiến lược.
-- Vì sao đơn cột: cả hai chỉ phục vụ một điều kiện `=`, không có ORDER BY hay
--          lọc thêm để mà ghép thành composite.
-- Không đụng products: đã có products_pkey, phần đó chỉ tốn 0.56 ms.
-- Kết quả : 232.851 ms -> 1.197 ms (195x) | 33.857 -> 255 block (133x)
CREATE INDEX idx_orders_customer_id   ON orders (customer_id);
CREATE INDEX idx_order_items_order_id ON order_items (order_id);


-- -------------------------------------------------------------
-- Q3 — Doanh thu theo tháng
--
-- Baseline 133.9 ms có hai vấn đề độc lập:
--   aggregation — ước lượng số nhóm 253.033 vs thực tế 25 (Postgres không có
--     thống kê cho biểu thức) => loại HashAggregate => Sort 250.983 dòng =>
--     vượt work_mem 4MB => đổ đĩa.
--   I/O — WHERE khớp 25,1% bảng, index (status, created_at) vẫn phải vào heap
--     lấy `total` => Heap Blocks: exact=8604.

-- V2 — chữa phần I/O, query giữ nguyên. 133.9 -> 95.4 ms, buffers 9.571 -> 968.
-- Partial nên chỉ chứa ~25% số dòng: 7744 kB thay vì 41 MB.
-- Kiểm chứng Index Only Scan bằng `Heap Fetches: 0` trong plan.
CREATE INDEX idx_orders_paid_created_at
    ON orders (created_at)
    INCLUDE (total)
    WHERE status = 'paid';

-- V3 — chữa phần aggregation bằng cách gộp sẵn. 95.4 -> 0.034 ms, 25 dòng, 40 kB.
-- Chốt 'UTC' vì date_trunc trên timestamptz phụ thuộc TimeZone của session:
-- chạy ở +07 cho kết quả khác hẳn. Đổi sang múi giờ nghiệp vụ nếu cần.
CREATE MATERIALIZED VIEW monthly_paid_revenue AS
SELECT (date_trunc('month', created_at AT TIME ZONE 'UTC'))::date AS month,
       SUM(total) AS revenue
FROM orders
WHERE status = 'paid'
GROUP BY 1;

-- UNIQUE index là điều kiện bắt buộc của REFRESH ... CONCURRENTLY.
CREATE UNIQUE INDEX idx_monthly_paid_revenue_month
    ON monthly_paid_revenue (month);

-- REFRESH ~63 ms, rẻ hơn một lần chạy query gốc, và cũng dùng partial index ở trên.
--   REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_paid_revenue;
--
-- Đã đo rồi loại: CREATE STATISTICS (20.7 ms, đề bài cấm) và cột generated
-- (33.6 ms, rewrite toàn bảng). Xem plans/q3_alternatives.txt.


-- -------------------------------------------------------------
-- Q4 — Tìm email bằng ILIKE '%...%'
--
-- Vấn đề : B-tree KHÔNG thể phục vụ '%...%'. Đây là giới hạn cấu trúc chứ
--          không phải cấu hình — B-tree sắp chuỗi theo thứ tự chữ cái nên chỉ
--          trả lời được "bắt đầu bằng X", không trả lời được "chứa X ở giữa".
--          Đã chứng minh bằng đối chứng: tạo B-tree trên email xong, cost vẫn
--          y hệt 0.00..1083.00 => planner loại thẳng, không hề cân nhắc.
-- Cách sửa: đổi cách BIỂU DIỄN dữ liệu — băm chuỗi thành các mẩu 3 ký tự
--          (trigram) rồi dựng chỉ mục ngược (GIN). Trigram ở giữa chuỗi tra
--          được y như ở đầu. pg_trgm chuyển hết về chữ thường khi sinh trigram
--          nên ILIKE được xử lý luôn.
-- Lưu ý  : GIN chỉ là BỘ LỌC THÔ. `Recheck Cond` trong plan là bắt buộc về
--          logic — chứa đủ trigram không có nghĩa là khớp đúng thứ tự.
-- Giới hạn: pattern ngắn hơn 3 ký tự (vd '%12%') thì index này vô dụng, quay
--          về Seq Scan. GIN cũng ghi chậm hơn B-tree (~8 entry mỗi INSERT).
-- Kích thước: 1904 kB trên bảng 3664 kB (52%) — nhỏ vì email mẫu quá lặp lại.
--          Trên email thật, GIN trigram thường LỚN HƠN bảng. Phải tự đo.
-- Kết quả : 17.342 ms -> 0.760 ms (22,8x) | 458 -> 47 block
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_customers_email_trgm ON customers USING gin (email gin_trgm_ops);


-- -------------------------------------------------------------
-- Q5 — Correlated subquery đếm đơn hàng
--
-- KHÔNG THÊM GÌ. Query này đã nhanh sẵn (27,5 ms) nhờ idx_orders_customer_id
-- tạo ở Q2: mỗi vòng subquery là một Index Only Scan với Heap Fetches = 0.
--
-- Ba phương án tối ưu đã thử và ĐỀU LÀM CHẬM ĐI:
--   LEFT JOIN + GROUP BY            186,8 ms  (chậm hơn 6,8x)
--   gom nhóm trước rồi join         294,1 ms  (chậm hơn 10,7x)
--   index cho customers.country      30,3 ms  (không đổi, đã xoá)
--
-- Đối chứng: bỏ idx_orders_customer_id ra thì cùng query mất 228.254 ms
-- (3 phút 48 giây, chậm hơn 8.300 lần). Xem plans/q5_no_fk_index.txt.
--
-- => Lời khuyên "correlated subquery thì viết lại thành JOIN" bỏ qua điều
--    kiện quyết định: subquery có index để tra hay không.


-- -------------------------------------------------------------
-- Q6 — Hàm bọc lên cột làm hỏng index
--
-- Vấn đề : `date_trunc('day', created_at) = '...'` là NON-SARGABLE. Index lưu
--          giá trị của CỘT, không lưu giá trị của HÀM áp lên cột, nên Postgres
--          phải tính hàm cho từng dòng => quét toàn bảng dù chỉ khớp 0,13%.
--          Dấu hiệu trong plan: `Filter` thay vì `Index Cond`.
-- Cách sửa: viết lại thành khoảng trên chính cột đó (xem queries/q6_after.sql),
--          rồi mới thêm index. Dùng khoảng nửa mở >= ... AND < ... để không
--          phải bận tâm độ chính xác micro giây của TIMESTAMPTZ.
-- Bằng chứng: sau khi có index này, chạy lại query CŨ (còn date_trunc) vẫn ra
--          Parallel Seq Scan 42 ms. Vấn đề nằm ở cách viết query, không phải
--          ở việc thiếu index.
-- Ngã rẽ : không tạo index trên biểu thức được —
--          date_trunc(text, timestamptz) là STABLE chứ không IMMUTABLE
--          (kết quả phụ thuộc TimeZone của session).
--          ERROR: functions in index expression must be marked IMMUTABLE
-- Kích thước: 21 MB trên bảng 67 MB.
-- Kết quả : 40,9 ms -> 5,9 ms (6,9x) | 8.604 -> 1.226 block
CREATE INDEX idx_orders_created_at ON orders (created_at);


-- =============================================================
-- ROLLBACK — đưa DB về trạng thái trước tối ưu để đo lại từ đầu
-- =============================================================
-- DROP INDEX IF EXISTS idx_orders_status_created_at;   -- Q1
-- DROP INDEX IF EXISTS idx_orders_customer_id;          -- Q2
-- DROP INDEX IF EXISTS idx_order_items_order_id;        -- Q2
-- DROP INDEX IF EXISTS idx_orders_paid_created_at;      -- Q3
-- DROP MATERIALIZED VIEW IF EXISTS monthly_paid_revenue; -- Q3
-- DROP INDEX IF EXISTS idx_customers_email_trgm;        -- Q4
--   (giữ lại extension pg_trgm — xoá nó ảnh hưởng cả database)
-- DROP INDEX IF EXISTS idx_orders_created_at;           -- Q6
--   Q5 không thêm gì nên không có gì để rollback.
