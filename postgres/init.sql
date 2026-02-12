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
