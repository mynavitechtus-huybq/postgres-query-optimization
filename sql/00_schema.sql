-- Phần A chạy trên database `postgres`, phần B chạy trên `shop_perf`.

-- ---------- PHẦN A ----------
-- CREATE DATABASE không chạy được trong transaction block => cần Auto-commit.
CREATE DATABASE shop_perf;

-- Xong thì đổi database đang active sang `shop_perf` rồi mới chạy phần B.
-- `\c shop_perf` là meta-command của psql CLI, DBeaver không hiểu.

-- ---------- PHẦN B ----------
DO $$
BEGIN
    IF current_database() <> 'shop_perf' THEN
        RAISE EXCEPTION
            'Đang đứng ở database "%" chứ không phải "shop_perf". Dừng lại, đổi kết nối rồi chạy lại.',
            current_database();
    END IF;
END $$;

CREATE TABLE customers (
    id         BIGSERIAL PRIMARY KEY,
    email      TEXT        NOT NULL,
    country    TEXT        NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE products (
    id       BIGSERIAL PRIMARY KEY,
    name     TEXT          NOT NULL,
    category TEXT          NOT NULL,
    price    NUMERIC(10,2) NOT NULL
);

CREATE TABLE orders (
    id          BIGSERIAL PRIMARY KEY,
    customer_id BIGINT        NOT NULL REFERENCES customers(id),
    status      TEXT          NOT NULL,  -- 'pending','paid','shipped','cancelled'
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    total       NUMERIC(10,2) NOT NULL
);

CREATE TABLE order_items (
    id         BIGSERIAL PRIMARY KEY,
    order_id   BIGINT        NOT NULL REFERENCES orders(id),
    product_id BIGINT        NOT NULL REFERENCES products(id),
    quantity   INT           NOT NULL,
    unit_price NUMERIC(10,2) NOT NULL
);

-- Không có index nào ngoài PRIMARY KEY.
-- REFERENCES không tự sinh index ở phía bảng con (xem Q2).
