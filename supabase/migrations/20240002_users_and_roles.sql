-- Migration 002: Users, Roles, Permissions, Audit Logs

CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name user_role NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT UNIQUE,
  email TEXT UNIQUE,
  role user_role NOT NULL DEFAULT 'GUIDE',
  avatar_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  employee_id TEXT UNIQUE,
  department TEXT,
  join_date DATE,
  last_login TIMESTAMPTZ,
  meta JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE permissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  role user_role NOT NULL,
  module TEXT NOT NULL,
  action TEXT NOT NULL,
  is_allowed BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(role, module, action)
);

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  module TEXT NOT NULL,
  record_id UUID,
  old_data JSONB,
  new_data JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_module ON audit_logs(module);
CREATE INDEX idx_audit_created_at ON audit_logs(created_at DESC);

-- RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION auth_user_role()
RETURNS user_role AS $$
  SELECT role FROM users WHERE id = auth.uid()
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE POLICY "Users: read own profile" ON users FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users: owner/manager read all" ON users FOR SELECT USING (auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Users: owner manage all" ON users FOR ALL USING (auth_user_role() = 'OWNER');
CREATE POLICY "Roles: all can read" ON roles FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Permissions: all can read" ON permissions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Audit: owner can read" ON audit_logs FOR SELECT USING (auth_user_role() = 'OWNER');

-- Seed roles
INSERT INTO roles (name, display_name, description) VALUES
  ('OWNER', 'Owner', 'Full access to all modules'),
  ('MANAGER', 'Manager', 'Access to all operational modules'),
  ('HOUSEKEEPING', 'Housekeeping Staff', 'Rooms and cleaning tasks'),
  ('KITCHEN', 'Kitchen Staff', 'Food orders and kitchen'),
  ('ACTIVITY_COORDINATOR', 'Activity Coordinator', 'Activities and heritage walks'),
  ('SHOP_OPERATOR', 'Shop Operator', 'Shop and POS billing'),
  ('ACCOUNTANT', 'Accountant', 'Payments and financial reports'),
  ('GUIDE', 'Guide / Artisan', 'Tours and activities');
