-- ENABLE EXTENSION UUID-OSSP AND PGCRYPTO
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- SCHEMA ecommerce
CREATE SCHEMA IF NOT EXISTS ecommerce;


-- TABLE customers
CREATE TABLE IF NOT EXISTS ecommerce.customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name VARCHAR(255) NOT NULL,
    last_name VARCHAR(255) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    tier VARCHAR(20) DEFAULT 'bronze' CHECK (tier IN ('bronze', 'silver', 'gold', 'platinum')),
    total_spent NUMERIC(10, 2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_customers_email ON ecommerce.customers (email);
CREATE INDEX idx_customers_tier ON ecommerce.customers (tier);

-- TABLE products
CREATE TABLE IF NOT EXISTS ecommerce.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    price NUMERIC(10, 2) NOT NULL CHECK (price >= 0),
    cost NUMERIC(10, 2) NOT NULL CHECK (cost >= 0),
    weight NUMERIC(10, 2),
    is_available BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_products_sku ON ecommerce.products (sku);
CREATE INDEX idx_products_category ON ecommerce.products (category);

--  orders
CREATE TABLE IF NOT EXISTS ecommerce.orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_number VARCHAR(50) UNIQUE NOT NULL,
    customer_id UUID NOT NULL REFERENCES ecommerce.customers (id),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed','processing','shipped', 'delivered', 'cancelled', 'refunded')),
    subtotal DECIMAL(10, 2) NOT NULL CHECK (subtotal >= 0),
    tax DECIMAL(10, 2) NOT NULL CHECK (tax >= 0),
    shipping DECIMAL(10, 2) NOT NULL CHECK (shipping >= 0),
    total DECIMAL(10, 2) NOT NULL CHECK (total >= 0),
    shipping_address TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_orders_order_number ON ecommerce.orders (order_number);
CREATE INDEX idx_orders_customer_id ON ecommerce.orders (customer_id);
CREATE INDEX idx_orders_status ON ecommerce.orders (status);
CREATE INDEX idx_orders_created_at ON ecommerce.orders (created_at DESC);


-- order_items
CREATE TABLE IF NOT EXISTS ecommerce.order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES ecommerce.orders (id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES ecommerce.products (id),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10, 2) NOT NULL CHECK (unit_price >= 0),
    total_price NUMERIC(10, 2) NOT NULL CHECK (total_price >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_order_items_order_id ON ecommerce.order_items (order_id);
CREATE INDEX idx_order_items_product_id ON ecommerce.order_items (product_id);

-- TABLE inventory
CREATE TABLE IF NOT EXISTS ecommerce.inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL REFERENCES ecommerce.products (id) ,
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    reserved INTEGER NOT NULL DEFAULT 0 CHECK (reserved >= 0),
    available INTEGER NOT NULL DEFAULT 0 CHECK (available >= 0),
    reorder_point INTEGER NOT NULL DEFAULT 0 CHECK (reorder_point >= 0),
    reorder_quantity INTEGER NOT NULL DEFAULT 0 CHECK (reorder_quantity >= 0),
    warehouse_location VARCHAR(100),
    last_updated TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_inventory_product_id ON ecommerce.inventory (product_id); 

-- audit_log
CREATE TABLE IF NOT EXISTS ecommerce.audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(100) DEFAULT CURRENT_USER,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_log_table_name ON ecommerce.audit_log (table_name);
CREATE INDEX idx_audit_log_record_id ON ecommerce.audit_log (record_id);
CREATE INDEX idx_audit_log_changed_at ON ecommerce.audit_log (changed_at DESC);


-- FUNCTION update_timestamp
CREATE OR REPLACE FUNCTION ecommerce.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- TRIGGERS FOR UPDATING updated_at for all tables
CREATE TRIGGER trg_update_customers_timestamp
    BEFORE UPDATE ON ecommerce.customers
    FOR EACH ROW EXECUTE FUNCTION ecommerce.update_timestamp();

CREATE TRIGGER trg_update_products_timestamp
    BEFORE UPDATE ON ecommerce.products
    FOR EACH ROW EXECUTE FUNCTION ecommerce.update_timestamp();

CREATE TRIGGER trg_update_orders_timestamp
    BEFORE UPDATE ON ecommerce.orders
    FOR EACH ROW EXECUTE FUNCTION ecommerce.update_timestamp();


CREATE TRIGGER trg_update_inventory_timestamp
    BEFORE UPDATE ON ecommerce.inventory
    FOR EACH ROW EXECUTE FUNCTION ecommerce.update_timestamp();


-- FUNCTION: GENERATE ORDER NUMBER
CREATE OR REPLACE FUNCTION ecommerce.generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
    NEW.order_number = 'ORD-' || TO_CHAR(NOW(), 'YYYYMMDD') || LPAD(NEXTVAL('order_seq')::text, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE SEQUENCE ecommerce.order_seq START 1;

-- TRIGGER TO SET ORDER NUMBER BEFORE INSERT
CREATE TRIGGER trg_generate_order_number
    BEFORE INSERT ON ecommerce.orders
    FOR EACH ROW 
        WHEN (NEW.order_number IS NULL OR NEW.order_number = '') 
        EXECUTE FUNCTION ecommerce.generate_order_number();


INSERT INTO ecommmerce.products (sku, name, description, category, price, cost, weight) VALUES
('SKU001', 'Wireless Mouse', 'Ergonomic wireless mouse with adjustable DPI.', 'Electronics', 29.99, 15.00, 0.2),
('SKU002', 'Bluetooth Headphones', 'Over-ear Bluetooth headphones with noise cancellation.', 'Electronics', 89.99, 50.00, 0.5),
('SKU003', 'Smartphone Stand', 'Adjustable smartphone stand for desk use.', 'Accessories', 19.99, 5.00, 0.1),
('SKU004', 'USB-C Hub', 'Multi-port USB-C hub with HDMI and USB 3.0 ports.', 'Electronics', 49.99, 25.00, 0.3),
('SKU005', 'Gaming Keyboard', 'Mechanical gaming keyboard with RGB backlighting.', 'Electronics', 79.99, 40.00, 0.7),
('SKU006', '4K Monitor', '27-inch 4K UHD monitor with HDR support.', 'Electronics', 399.99, 250.00, 5.0);

INSERT INTO ecommerce.inventory (product_id, quantity, reserved, available, reorder_point, reorder_quantity, warehouse_location) VALUES
SELECT 
    id,
    (RANDOM() * 200 + 50)::INTEGER,
    (RANDOM() * 10)::INTEGER,
    CASE (RANDOM() * 3)::INTEGER
        WHEN 0 THEN 'WAREHOUSE-A'
        WHEN 1 THEN 'WAREHOUSE-B'
        ELSE 'WAREHOUSE-C'
    END,
    20,
    100
FROM ecommerce.products;

INSERT INTO ecommerce.customers (first_name, last_name, email, phone, tier, total_spent) VALUES
('John', 'Doe', 'john.doe@example.com', '555-1234', 'Gold', 1200.00),
('Jane', 'Smith', 'jane.smith@example.com', '555-5678', 'Silver', 800.00),
('Alice', 'Johnson', 'alice.johnson@example.com', '555-8765', 'Platinum', 2000.00),
('Bob', 'Brown', 'bob.brown@example.com', '555-4321', 'Gold', 1500.00);

-- CDC HEARTBEAT
CREATE TABLE IF NOT EXISTS ecommerce.cdc_heartbeat (
    id SERIAL PRIMARY KEY,
    ts TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO ecommerce.cdc_heartbeat (ts) VALUES (NOW());

CREATE TABLE ecommerce.debezium_signals (
    id SERIAL PRIMARY KEY,
    type VARCHAR(255) NOT NULL,
    data TEXT
);

CREATE TABLE ecommerce.cdc_metrics (
    id BIGSERIAL PRIMARY KEY,
    table_name VARCHAR(255) NOT NULL,
    operation VARCHAR(50) NOT NULL check(operation IN ('INSERT', 'UPDATE', 'DELETE')),
    record_count BIGINT NOT NULL default 1,
    measured_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_cdc_metrics_table_name ON ecommerce.cdc_metrics (table_name, operation);

CREATE PUBLICATION cdc_publication FOR TABLES
    ecommerce.customers,
    ecommerce.products,
    ecommerce.orders,
    ecommerce.order_items,
    ecommerce.inventory,
    ecommerce.cdc_heartbeat;


GRANT USAGE ON SCHEMA ecommerce TO cdc_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ecommerce TO cdc_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA ecommerce TO cdc_user;
GRANT SELECT ON ALL FUNCTIONS IN SCHEMA ecommerce TO cdc_user;
