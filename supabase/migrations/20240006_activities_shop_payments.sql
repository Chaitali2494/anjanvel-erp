-- Migration 006: Activities, Heritage Walks, Artisans, Shop, Payments, Notifications

-- ACTIVITIES
CREATE TABLE activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  category TEXT,
  duration_minutes INTEGER DEFAULT 60,
  max_capacity INTEGER DEFAULT 20,
  price_per_person NUMERIC(10,2) DEFAULT 0,
  min_age INTEGER,
  difficulty_level TEXT DEFAULT 'EASY',
  includes TEXT[],
  image_urls TEXT[],
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE activity_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  activity_id UUID NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  session_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME,
  max_capacity INTEGER,
  booked_count INTEGER DEFAULT 0,
  guide_id UUID REFERENCES users(id) ON DELETE SET NULL,
  location TEXT,
  status activity_status DEFAULT 'ACTIVE',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE activity_bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES activity_sessions(id) ON DELETE CASCADE,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  guest_id UUID REFERENCES guests(id) ON DELETE SET NULL,
  participant_name TEXT NOT NULL,
  num_participants INTEGER DEFAULT 1,
  amount NUMERIC(10,2) DEFAULT 0,
  payment_status payment_status DEFAULT 'PENDING',
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE activity_attendance (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES activity_sessions(id) ON DELETE CASCADE,
  activity_booking_id UUID REFERENCES activity_bookings(id) ON DELETE SET NULL,
  participant_name TEXT NOT NULL,
  attended BOOLEAN DEFAULT FALSE,
  attended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_activity_sessions_date ON activity_sessions(session_date);
CREATE INDEX idx_activity_bookings_session ON activity_bookings(session_id);

ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Activities: all read active" ON activities FOR SELECT USING (is_active = TRUE OR auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Activities: coordinator manage" ON activities FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACTIVITY_COORDINATOR'));
CREATE POLICY "Activity sessions: all staff read" ON activity_sessions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Activity sessions: coordinator manage" ON activity_sessions FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACTIVITY_COORDINATOR'));
CREATE POLICY "Activity bookings: all staff read" ON activity_bookings FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Activity attendance: guide update" ON activity_attendance FOR UPDATE USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACTIVITY_COORDINATOR', 'GUIDE'));

-- Seed activities
INSERT INTO activities (name, slug, description, category, duration_minutes, price_per_person) VALUES
  ('Heritage Walk', 'heritage-walk', 'Guided walk through historic village', 'HERITAGE', 90, 300),
  ('Pottery Workshop', 'pottery-workshop', 'Learn traditional pottery', 'CRAFT', 120, 500),
  ('Farm Tour', 'farm-tour', 'Guided organic farm tour', 'FARM', 60, 200),
  ('Bird Watching', 'bird-watching', 'Early morning bird watching', 'NATURE', 90, 350),
  ('Bonfire Evening', 'bonfire', 'Folk music and storytelling', 'CULTURAL', 120, 300),
  ('Warli Art Class', 'warli-art', 'Traditional Warli painting', 'CRAFT', 90, 400),
  ('Yoga & Meditation', 'yoga-meditation', 'Morning yoga in nature', 'WELLNESS', 60, 250),
  ('Village Tour', 'village-tour', 'Guided local village tour', 'HERITAGE', 120, 400),
  ('Kansa Thali Workshop', 'kansa-thali', 'Traditional metalwork demo', 'CRAFT', 90, 600),
  ('Organic Cooking', 'organic-cooking', 'Farm-to-table cooking class', 'CULTURAL', 150, 700);

-- HERITAGE WALKS
CREATE TABLE heritage_walk_routes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  distance_km NUMERIC(5,2),
  duration_minutes INTEGER DEFAULT 90,
  difficulty TEXT DEFAULT 'EASY',
  highlights TEXT[],
  map_url TEXT,
  image_urls TEXT[],
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE heritage_walk_stops (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  route_id UUID NOT NULL REFERENCES heritage_walk_routes(id) ON DELETE CASCADE,
  stop_name TEXT NOT NULL,
  description TEXT,
  story TEXT,
  latitude NUMERIC(10,7),
  longitude NUMERIC(10,7),
  image_urls TEXT[],
  audio_guide_url TEXT,
  stop_number INTEGER NOT NULL,
  sort_order INTEGER DEFAULT 0
);

CREATE TABLE heritage_walk_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  route_id UUID NOT NULL REFERENCES heritage_walk_routes(id) ON DELETE CASCADE,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  session_date DATE NOT NULL,
  start_time TIME NOT NULL,
  guide_id UUID REFERENCES users(id) ON DELETE SET NULL,
  max_participants INTEGER DEFAULT 20,
  actual_participants INTEGER DEFAULT 0,
  status TEXT DEFAULT 'SCHEDULED',
  feedback_rating NUMERIC(3,2),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE heritage_walk_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE heritage_walk_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE heritage_walk_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "HW routes: all read" ON heritage_walk_routes FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "HW routes: coordinator manage" ON heritage_walk_routes FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACTIVITY_COORDINATOR'));
CREATE POLICY "HW stops: all read" ON heritage_walk_stops FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "HW sessions: all read" ON heritage_walk_sessions FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "HW sessions: coordinator manage" ON heritage_walk_sessions FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACTIVITY_COORDINATOR', 'GUIDE'));

-- ARTISANS
CREATE TABLE artisans (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  village TEXT,
  bio TEXT,
  profile_image_url TEXT,
  portfolio_urls TEXT[],
  is_active BOOLEAN DEFAULT TRUE,
  bank_account TEXT,
  ifsc_code TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE artisan_skills (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  artisan_id UUID NOT NULL REFERENCES artisans(id) ON DELETE CASCADE,
  skill_name TEXT NOT NULL,
  experience_years INTEGER,
  hourly_rate NUMERIC(10,2),
  session_rate NUMERIC(10,2),
  is_primary BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE artisan_payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  artisan_id UUID NOT NULL REFERENCES artisans(id) ON DELETE CASCADE,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  activity_session_id UUID REFERENCES activity_sessions(id) ON DELETE SET NULL,
  amount NUMERIC(10,2) NOT NULL,
  payment_date DATE NOT NULL,
  payment_method payment_method DEFAULT 'CASH',
  reference TEXT,
  notes TEXT,
  paid_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE artisans ENABLE ROW LEVEL SECURITY;
ALTER TABLE artisan_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE artisan_payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Artisans: all staff read" ON artisans FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Artisans: owner/manager manage" ON artisans FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Artisan payments: accountant/owner read" ON artisan_payments FOR SELECT USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACCOUNTANT'));

-- SHOP
CREATE TABLE shop_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  image_url TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE shop_products (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  category_id UUID REFERENCES shop_categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  sku TEXT UNIQUE,
  description TEXT,
  price NUMERIC(10,2) NOT NULL,
  mrp NUMERIC(10,2),
  cost_price NUMERIC(10,2),
  stock_quantity INTEGER DEFAULT 0,
  min_stock INTEGER DEFAULT 5,
  unit TEXT DEFAULT 'PIECE',
  image_urls TEXT[],
  barcode TEXT,
  weight_grams INTEGER,
  is_active BOOLEAN DEFAULT TRUE,
  is_homemade BOOLEAN DEFAULT FALSE,
  inventory_item_id UUID REFERENCES inventory_items(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE SEQUENCE sale_number_seq START 1001;

CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sale_number TEXT UNIQUE NOT NULL,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  guest_id UUID REFERENCES guests(id) ON DELETE SET NULL,
  sale_date TIMESTAMPTZ DEFAULT NOW(),
  subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
  discount_amount NUMERIC(10,2) DEFAULT 0,
  tax_amount NUMERIC(10,2) DEFAULT 0,
  total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  payment_method payment_method DEFAULT 'CASH',
  payment_reference TEXT,
  is_paid BOOLEAN DEFAULT FALSE,
  sold_by UUID REFERENCES users(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE sale_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  product_id UUID REFERENCES shop_products(id) ON DELETE SET NULL,
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC(10,2) NOT NULL,
  discount_percent NUMERIC(5,2) DEFAULT 0,
  total_price NUMERIC(10,2) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE shop_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON shop_products FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE FUNCTION generate_sale_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.sale_number := 'ANJ-SL-' || LPAD(nextval('sale_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_number BEFORE INSERT ON sales
  FOR EACH ROW WHEN (NEW.sale_number IS NULL) EXECUTE FUNCTION generate_sale_number();

-- Deduct stock on sale
CREATE OR REPLACE FUNCTION update_shop_stock_on_sale()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.product_id IS NOT NULL THEN
    UPDATE shop_products SET stock_quantity = stock_quantity - NEW.quantity WHERE id = NEW.product_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_shop_stock_on_sale AFTER INSERT ON sale_items FOR EACH ROW EXECUTE FUNCTION update_shop_stock_on_sale();

CREATE POLICY "Shop categories: all read" ON shop_categories FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Shop products: all staff read" ON shop_products FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Shop products: shop op manage" ON shop_products FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER', 'SHOP_OPERATOR'));
CREATE POLICY "Sales: shop op/accountant read" ON sales FOR SELECT USING (auth_user_role() IN ('OWNER', 'MANAGER', 'SHOP_OPERATOR', 'ACCOUNTANT'));
CREATE POLICY "Sales: shop op create" ON sales FOR INSERT WITH CHECK (auth_user_role() IN ('OWNER', 'MANAGER', 'SHOP_OPERATOR'));

-- Seed shop categories
INSERT INTO shop_categories (name, sort_order) VALUES
  ('Honey & Preserves', 1), ('Millets & Grains', 2), ('Pickles & Chutneys', 3),
  ('Handicrafts', 4), ('Books & Stories', 5), ('Souvenirs', 6), ('Organic Products', 7);

-- PAYMENTS
CREATE SEQUENCE payment_number_seq START 1001;

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_number TEXT UNIQUE NOT NULL,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  sale_id UUID REFERENCES sales(id) ON DELETE SET NULL,
  guest_id UUID REFERENCES guests(id) ON DELETE SET NULL,
  amount NUMERIC(12,2) NOT NULL,
  method payment_method NOT NULL,
  status TEXT DEFAULT 'SUCCESS',
  reference_number TEXT,
  gateway TEXT,
  gateway_response JSONB,
  notes TEXT,
  collected_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE refunds (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  amount NUMERIC(12,2) NOT NULL,
  reason TEXT NOT NULL,
  status TEXT DEFAULT 'PENDING',
  refund_method payment_method,
  reference_number TEXT,
  processed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  processed_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_payments_booking ON payments(booking_id);
CREATE INDEX idx_payments_created_at ON payments(created_at DESC);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION generate_payment_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.payment_number := 'ANJ-PY-' || LPAD(nextval('payment_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payment_number BEFORE INSERT ON payments
  FOR EACH ROW WHEN (NEW.payment_number IS NULL) EXECUTE FUNCTION generate_payment_number();

-- Update booking paid_amount on payment
CREATE OR REPLACE FUNCTION update_booking_paid_amount()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.booking_id IS NOT NULL AND NEW.status = 'SUCCESS' THEN
    UPDATE bookings SET
      paid_amount = (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE booking_id = NEW.booking_id AND status = 'SUCCESS'),
      payment_status = CASE
        WHEN (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE booking_id = NEW.booking_id AND status = 'SUCCESS') >= total_amount THEN 'PAID'::payment_status
        WHEN (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE booking_id = NEW.booking_id AND status = 'SUCCESS') > 0 THEN 'PARTIAL'::payment_status
        ELSE 'PENDING'::payment_status
      END
    WHERE id = NEW.booking_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payment_update_booking AFTER INSERT OR UPDATE ON payments FOR EACH ROW EXECUTE FUNCTION update_booking_paid_amount();

CREATE TRIGGER trg_audit_payments AFTER INSERT OR UPDATE OR DELETE ON payments FOR EACH ROW EXECUTE FUNCTION log_audit();

CREATE POLICY "Payments: accountant/owner read" ON payments FOR SELECT USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACCOUNTANT'));
CREATE POLICY "Payments: accountant insert" ON payments FOR INSERT WITH CHECK (auth_user_role() IN ('OWNER', 'MANAGER', 'ACCOUNTANT'));
CREATE POLICY "Refunds: owner/accountant read" ON refunds FOR SELECT USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACCOUNTANT'));

-- WHATSAPP & NOTIFICATIONS
CREATE TABLE whatsapp_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  trigger_event TEXT NOT NULL,
  template_id TEXT,
  message_body TEXT NOT NULL,
  variables TEXT[],
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL,
  reference_id UUID,
  reference_type TEXT,
  is_read BOOLEAN DEFAULT FALSE,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE push_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, token)
);

CREATE INDEX idx_notif_user ON notifications(user_id);
CREATE INDEX idx_notif_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

ALTER TABLE whatsapp_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Notif: users read own" ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Notif: users update own" ON notifications FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Notif: service role insert" ON notifications FOR INSERT WITH CHECK (auth.role() = 'service_role' OR auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Push tokens: users manage own" ON push_tokens FOR ALL USING (user_id = auth.uid());
CREATE POLICY "WA templates: owner/manager read" ON whatsapp_templates FOR SELECT USING (auth_user_role() IN ('OWNER', 'MANAGER'));

-- Seed WhatsApp templates
INSERT INTO whatsapp_templates (name, trigger_event, message_body, variables) VALUES
  ('Booking Confirmation', 'BOOKING_CONFIRMED', 'Dear {{guest_name}}, your booking {{booking_number}} at Anjanvel is confirmed for {{check_in_date}}. Total: ₹{{total_amount}}. 🌿', ARRAY['guest_name', 'booking_number', 'check_in_date', 'total_amount']),
  ('Payment Reminder', 'PAYMENT_REMINDER', 'Dear {{guest_name}}, ₹{{balance_amount}} is pending for booking {{booking_number}}. Please pay to confirm your stay. 🙏', ARRAY['guest_name', 'balance_amount', 'booking_number']),
  ('Check-In Reminder', 'CHECKIN_REMINDER', 'Dear {{guest_name}}, your check-in is tomorrow ({{check_in_date}}). Please carry a valid ID. Welcome! 🌾', ARRAY['guest_name', 'check_in_date']),
  ('Checkout Reminder', 'CHECKOUT_REMINDER', 'Dear {{guest_name}}, your checkout is today. We hope you had a wonderful stay at Anjanvel! 🌿', ARRAY['guest_name']),
  ('Feedback Request', 'FEEDBACK_REQUEST', 'Dear {{guest_name}}, thank you for visiting Anjanvel! Please share your experience: {{feedback_link}} 🙏', ARRAY['guest_name', 'feedback_link']);
