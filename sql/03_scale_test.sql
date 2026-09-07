-- =============================================================
-- 03_scale_test.sql — dựng bộ dữ liệu gấp 5 lần để kiểm tra lại kết luận Q3
--
-- Mục đích: xác nhận thứ hạng giữa các cách tối ưu không đổi khi dữ liệu lớn
-- hơn. Chạy trên database RIÊNG để không ảnh hưởng số liệu của shop_perf.
--
-- Chỉ dựng customers và orders vì Q3 không đụng tới products/order_items.
-- Kết quả đo: plans/q3_scale_5x.txt
-- =============================================================

-- Chạy trên database `postgres`, cần Auto-commit:
--   CREATE DATABASE shop_perf_5x;
-- rồi chuyển sang `shop_perf_5x` và chạy phần dưới.

DO $$
BEGIN
    IF current_database() <> 'shop_perf_5x' THEN
        RAISE EXCEPTION
            'Đang đứng ở database "%" chứ không phải "shop_perf_5x".',
            current_database();
    END IF;
END $$;

CREATE TABLE customers (
    id         BIGSERIAL PRIMARY KEY,
    email      TEXT        NOT NULL,
    country    TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    id          BIGSERIAL PRIMARY KEY,
    customer_id BIGINT        NOT NULL REFERENCES customers(id),
    status      TEXT          NOT NULL,
    created_at  TIMESTAMPTZ   NOT NULL,
    total       NUMERIC(10,2) NOT NULL
);

INSERT INTO customers (email, country, created_at)
SELECT 'user' || g || '@example.com',
       (ARRAY['VN','US','SG','JP','TH'])[floor(random()*5+1)],
       now() - (random() * interval '730 days')
FROM generate_series(1, 250000) g;

INSERT INTO orders (customer_id, status, created_at, total)
SELECT floor(random()*250000+1),
       (ARRAY['pending','paid','shipped','cancelled'])[floor(random()*4+1)],
       now() - (random() * interval '730 days'),
       round((random()*1000 + 10)::numeric, 2)
FROM generate_series(1, 5000000) g;

-- Hai index nền, giống trạng thái dự án thật trước khi tối ưu Q3.
-- idx_orders_created_at đến từ Q6 và cần cho câu con max(created_at) của V3;
-- thiếu nó thì V3 phải quét toàn bảng chỉ để tìm mốc thời gian lớn nhất.
CREATE INDEX idx_orders_status_created_at ON orders (status, created_at DESC);
CREATE INDEX idx_orders_created_at        ON orders (created_at);

VACUUM (ANALYZE);

-- Sau đó áp phần Q3 của 02_indexes.sql:
--   CREATE INDEX idx_orders_paid_created_at
--       ON orders (created_at) INCLUDE (total) WHERE status = 'paid';
--   CREATE MATERIALIZED VIEW monthly_paid_revenue AS ...
--   CREATE UNIQUE INDEX idx_monthly_paid_revenue_month ...
--   VACUUM (ANALYZE) orders;
