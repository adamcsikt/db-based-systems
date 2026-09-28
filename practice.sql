-- 1. Create the Database with strict encoding
CREATE DATABASE company_platform
    WITH
    ENCODING = 'UTF8'
    LC_COLLATE = 'C.UTF-8'
    LC_CTYPE = 'C.UTF-8';

-- Connect to the new database to create schemas and tables
\c company_platform;

-- 2. Create the Schemas
CREATE SCHEMA core;
CREATE SCHEMA main_site;
CREATE SCHEMA webshop;
CREATE SCHEMA academy;

-- ==========================================
-- CORE SCHEMA (Shared Data)
-- ==========================================

CREATE TABLE core.users (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    -- The "C" collation does byte-by-byte comparison.
    -- It is significantly faster for indexing exact strings like emails.
    email VARCHAR(255) COLLATE "C" UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    -- No created_at needed! We can extract it from the UUIDv7 later.
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE core.roles (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    role_name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE core.user_roles (
    user_id UUID REFERENCES core.users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES core.roles(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, role_id)
);

-- UNLOGGED table for high-speed, temporary session data
CREATE UNLOGGED TABLE core.session_cache (
    session_id UUID PRIMARY KEY DEFAULT uuidv7(),
    user_id UUID REFERENCES core.users(id) ON DELETE CASCADE,
    jwt_token TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL
);

-- ==========================================
-- MAIN SITE SCHEMA
-- ==========================================

CREATE TABLE main_site.contact_messages (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    sender_name VARCHAR(100),
    email VARCHAR(255) COLLATE "C",
    message TEXT,
    submitted_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE main_site.course_applications (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    user_id UUID REFERENCES core.users(id),
    desired_course VARCHAR(100)
);

-- ==========================================
-- WEBSHOP SCHEMA
-- ==========================================

CREATE TABLE webshop.products (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    name VARCHAR(150) NOT NULL,
    price DECIMAL(10,2) CHECK (price >= 0),
    stock_quantity INT DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE webshop.orders (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    user_id UUID REFERENCES core.users(id),
    total_amount DECIMAL(10,2) CHECK (total_amount >= 0),
    status VARCHAR(50) DEFAULT 'pending'
);

-- ==========================================
-- ACADEMY SCHEMA
-- ==========================================

CREATE TABLE academy.courses (
    id UUID PRIMARY KEY DEFAULT uuidv7(),
    title VARCHAR(150) NOT NULL,
    description TEXT
);

CREATE TABLE academy.enrollments (
    user_id UUID REFERENCES core.users(id),
    course_id UUID REFERENCES academy.courses(id),
    -- Extracting timestamp from UUIDv7 only works on the primary key,
    -- so we still need a timestamp column for this join table.
    enrolled_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, course_id)
);

-- ==========================================
-- ROLES AND PERMISSIONS
-- ==========================================

-- Create the webshop application user
CREATE ROLE webshop_app_user LOGIN PASSWORD 'shop_pass_secure_123';
GRANT CONNECT ON DATABASE company_platform TO webshop_app_user;
GRANT USAGE ON SCHEMA webshop, core TO webshop_app_user;

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA webshop TO webshop_app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO webshop_app_user;
-- Allow the webshop to insert new users upon checkout registration
GRANT INSERT, UPDATE ON core.users TO webshop_app_user;

-- Ensure future tables get the same permissions
ALTER DEFAULT PRIVILEGES IN SCHEMA webshop
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO webshop_app_user;

-- Create the academy application user
CREATE ROLE academy_app_user LOGIN PASSWORD 'academy_pass_secure_123';
GRANT CONNECT ON DATABASE company_platform TO academy_app_user;
GRANT USAGE ON SCHEMA academy, core TO academy_app_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA academy TO academy_app_user;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO academy_app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA academy
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO academy_app_user;
