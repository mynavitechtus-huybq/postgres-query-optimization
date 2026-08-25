-- Sinh dữ liệu mẫu. Chạy trên `shop_perf`, mất vài phút.

-- Chặn trường hợp đứng nhầm database — nạp 4 triệu dòng vào nhầm chỗ chỉ lộ
-- ra rất muộn.
DO $$
BEGIN
    IF current_database() <> 'shop_perf' THEN
        RAISE EXCEPTION
            'Đang đứng ở database "%" chứ không phải "shop_perf". Dừng lại, đổi kết nối rồi chạy lại.',
            current_database();
    END IF;
END $$;

INSERT INTO customers (email, country, created_at)
SELECT 'user' || g || '@example.com',
       (ARRAY['VN','US','SG','JP','TH'])[floor(random()*5+1)],
       now() - (random() * interval '730 days')
FROM generate_series(1, 50000) g;

INSERT INTO products (name, category, price)
SELECT 'Product ' || g,
       (ARRAY['electronics','fashion','home','books','toys'])[floor(random()*5+1)],
       round((random()*500 + 5)::numeric, 2)
FROM generate_series(1, 5000) g;

INSERT INTO orders (customer_id, status, created_at, total)
SELECT floor(random()*50000+1),
       (ARRAY['pending','paid','shipped','cancelled'])[floor(random()*4+1)],
       now() - (random() * interval '730 days'),
       round((random()*1000 + 10)::numeric, 2)
FROM generate_series(1, 1000000) g;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT floor(random()*1000000+1),
       floor(random()*5000+1),
       floor(random()*5+1),
       round((random()*500 + 5)::numeric, 2)
FROM generate_series(1, 3000000) g;

-- Bắt buộc. Thiếu bước này thì planner vẫn tưởng bảng rỗng và mọi số đo
-- EXPLAIN ANALYZE phía sau đều vô nghĩa.
ANALYZE;
