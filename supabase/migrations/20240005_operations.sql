-- Migration 005: Housekeeping, Maintenance, Food, Inventory

-- HOUSEKEEPING
CREATE TABLE housekeeping_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  task_type TEXT NOT NULL,
  status task_status DEFAULT 'PENDING',
  priority INTEGER DEFAULT 1,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  scheduled_at TIMESTAMPTZ,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  notes TEXT,
  before_photo_urls TEXT[],
  after_photo_urls TEXT[],
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE cleaning_checklists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  task_id UUID NOT NULL REFERENCES housekeeping_tasks(id) ON DELETE CASCADE,
  item TEXT NOT NULL,
  is_done BOOLEAN DEFAULT FALSE,
  done_at TIMESTAMPTZ,
  sort_order INTEGER DEFAULT 0
);

CREATE INDEX idx_hk_tasks_room ON housekeeping_tasks(room_id);
CREATE INDEX idx_hk_tasks_status ON housekeeping_tasks(status);
CREATE INDEX idx_hk_tasks_assigned ON housekeeping_tasks(assigned_to);

ALTER TABLE housekeeping_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE cleaning_checklists ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_hk_updated_at BEFORE UPDATE ON housekeeping_tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE POLICY "HK: all staff read" ON housekeeping_tasks FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "HK: housekeeping can update own" ON housekeeping_tasks FOR UPDATE
  USING (assigned_to = auth.uid() OR auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "HK checklist: all read" ON cleaning_checklists FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "HK checklist: housekeeping update" ON cleaning_checklists FOR UPDATE
  USING (auth_user_role() IN ('OWNER', 'MANAGER', 'HOUSEKEEPING'));

-- MAINTENANCE
CREATE SEQUENCE ticket_number_seq START 1001;

CREATE TABLE maintenance_tickets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_number TEXT UNIQUE NOT NULL,
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  location TEXT,
  issue_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  priority ticket_priority DEFAULT 'MEDIUM',
  status ticket_status DEFAULT 'OPEN',
  reported_by UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  photo_urls TEXT[],
  estimated_cost NUMERIC(10,2),
  actual_cost NUMERIC(10,2),
  resolved_at TIMESTAMPTZ,
  resolution_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE maintenance_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_id UUID NOT NULL REFERENCES maintenance_tickets(id) ON DELETE CASCADE,
  status ticket_status NOT NULL,
  notes TEXT,
  changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_maint_status ON maintenance_tickets(status);
CREATE INDEX idx_maint_priority ON maintenance_tickets(priority);
CREATE INDEX idx_maint_assigned ON maintenance_tickets(assigned_to);

ALTER TABLE maintenance_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_history ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_maint_updated_at BEFORE UPDATE ON maintenance_tickets FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.ticket_number := 'ANJ-MT-' || LPAD(nextval('ticket_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ticket_number BEFORE INSERT ON maintenance_tickets
  FOR EACH ROW WHEN (NEW.ticket_number IS NULL) EXECUTE FUNCTION generate_ticket_number();

CREATE POLICY "Maintenance: all staff read" ON maintenance_tickets FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Maintenance: all staff create" ON maintenance_tickets FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Maintenance: owner/manager update" ON maintenance_tickets FOR UPDATE
  USING (auth_user_role() IN ('OWNER', 'MANAGER') OR assigned_to = auth.uid());

-- FOOD MANAGEMENT
CREATE TABLE food_menu_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  category TEXT,
  food_type food_type NOT NULL DEFAULT 'VEG',
  price NUMERIC(10,2) DEFAULT 0,
  is_available BOOLEAN DEFAULT TRUE,
  image_url TEXT,
  allergens TEXT[],
  preparation_time_mins INTEGER DEFAULT 20,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE meal_plans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  meal_type meal_type NOT NULL,
  num_veg INTEGER DEFAULT 0,
  num_non_veg INTEGER DEFAULT 0,
  num_jain INTEGER DEFAULT 0,
  num_vegan INTEGER DEFAULT 0,
  num_satvik INTEGER DEFAULT 0,
  special_instructions TEXT,
  status order_status DEFAULT 'PENDING',
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE SEQUENCE order_number_seq START 1001;

CREATE TABLE food_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_number TEXT UNIQUE NOT NULL,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  meal_plan_id UUID REFERENCES meal_plans(id) ON DELETE SET NULL,
  table_number TEXT,
  status order_status DEFAULT 'PENDING',
  notes TEXT,
  ordered_at TIMESTAMPTZ DEFAULT NOW(),
  served_at TIMESTAMPTZ,
  total_amount NUMERIC(10,2) DEFAULT 0,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE food_order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES food_orders(id) ON DELETE CASCADE,
  menu_item_id UUID REFERENCES food_menu_items(id) ON DELETE SET NULL,
  item_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC(10,2) NOT NULL,
  food_type food_type,
  special_request TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE food_menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_order_items ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.order_number := 'ANJ-FO-' || LPAD(nextval('order_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_number BEFORE INSERT ON food_orders
  FOR EACH ROW WHEN (NEW.order_number IS NULL) EXECUTE FUNCTION generate_order_number();

CREATE POLICY "Food menu: all read" ON food_menu_items FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Food menu: kitchen/manager manage" ON food_menu_items FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER', 'KITCHEN'));
CREATE POLICY "Meal plans: all staff read" ON meal_plans FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Meal plans: manager/kitchen manage" ON meal_plans FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER', 'KITCHEN'));
CREATE POLICY "Food orders: all staff read" ON food_orders FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Food orders: kitchen update" ON food_orders FOR UPDATE USING (auth_user_role() IN ('KITCHEN', 'MANAGER', 'OWNER'));

-- INVENTORY
CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  contact_person TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  gstin TEXT,
  category inventory_category,
  is_active BOOLEAN DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE inventory_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  sku TEXT UNIQUE,
  category inventory_category NOT NULL,
  unit TEXT NOT NULL,
  current_stock NUMERIC(12,3) DEFAULT 0,
  min_stock NUMERIC(12,3) DEFAULT 0,
  max_stock NUMERIC(12,3),
  unit_cost NUMERIC(10,2) DEFAULT 0,
  supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  storage_location TEXT,
  expiry_tracking BOOLEAN DEFAULT FALSE,
  image_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE inventory_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_id UUID NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  transaction_type transaction_type NOT NULL,
  quantity NUMERIC(12,3) NOT NULL,
  unit_cost NUMERIC(10,2),
  total_cost NUMERIC(12,2),
  reference_id UUID,
  reference_type TEXT,
  batch_number TEXT,
  expiry_date DATE,
  notes TEXT,
  done_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE SEQUENCE po_number_seq START 1001;

CREATE TABLE purchase_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  po_number TEXT UNIQUE NOT NULL,
  supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'DRAFT',
  ordered_at TIMESTAMPTZ,
  expected_delivery DATE,
  received_at TIMESTAMPTZ,
  total_amount NUMERIC(12,2) DEFAULT 0,
  notes TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE purchase_order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  po_id UUID NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
  item_id UUID NOT NULL REFERENCES inventory_items(id) ON DELETE RESTRICT,
  quantity_ordered NUMERIC(12,3) NOT NULL,
  quantity_received NUMERIC(12,3) DEFAULT 0,
  unit_price NUMERIC(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_inv_category ON inventory_items(category);
CREATE INDEX idx_inv_low_stock ON inventory_items(current_stock) WHERE current_stock <= min_stock;

ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_inventory_updated_at BEFORE UPDATE ON inventory_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.po_number := 'ANJ-PO-' || LPAD(nextval('po_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_po_number BEFORE INSERT ON purchase_orders
  FOR EACH ROW WHEN (NEW.po_number IS NULL) EXECUTE FUNCTION generate_po_number();

-- Update stock on transaction
CREATE OR REPLACE FUNCTION update_inventory_stock()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.transaction_type IN ('IN', 'RETURN') THEN
    UPDATE inventory_items SET current_stock = current_stock + NEW.quantity WHERE id = NEW.item_id;
  ELSIF NEW.transaction_type IN ('OUT', 'DAMAGE') THEN
    UPDATE inventory_items SET current_stock = current_stock - NEW.quantity WHERE id = NEW.item_id;
  ELSIF NEW.transaction_type = 'ADJUSTMENT' THEN
    UPDATE inventory_items SET current_stock = NEW.quantity WHERE id = NEW.item_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_stock AFTER INSERT ON inventory_transactions FOR EACH ROW EXECUTE FUNCTION update_inventory_stock();

CREATE POLICY "Inventory: all staff read" ON inventory_items FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Inventory: manager/accountant manage" ON inventory_items FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACCOUNTANT'));
CREATE POLICY "Inv transactions: all staff read" ON inventory_transactions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Inv transactions: manager insert" ON inventory_transactions FOR INSERT WITH CHECK (auth_user_role() IN ('OWNER', 'MANAGER', 'KITCHEN'));
