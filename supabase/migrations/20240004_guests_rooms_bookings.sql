-- Migration 004: Guests, Rooms, Bookings, Check-in/out

-- GUESTS
CREATE TABLE guests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  gender gender,
  date_of_birth DATE,
  address TEXT,
  city TEXT,
  state TEXT,
  pincode TEXT,
  country TEXT DEFAULT 'India',
  id_type id_type,
  id_number TEXT,
  id_image_url TEXT,
  selfie_url TEXT,
  tags TEXT[],
  is_vip BOOLEAN DEFAULT FALSE,
  notes TEXT,
  total_visits INTEGER DEFAULT 0,
  total_spend NUMERIC(12,2) DEFAULT 0,
  last_visit DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE guest_preferences (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  guest_id UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
  food_type food_type DEFAULT 'VEG',
  allergies TEXT[],
  special_requests TEXT,
  room_preferences TEXT,
  activity_preferences TEXT[],
  pillow_preference TEXT,
  wake_up_time TIME,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(guest_id)
);

CREATE TABLE guest_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  guest_id UUID NOT NULL REFERENCES guests(id) ON DELETE CASCADE,
  booking_id UUID,
  overall_rating INTEGER CHECK (overall_rating BETWEEN 1 AND 5),
  food_rating INTEGER CHECK (food_rating BETWEEN 1 AND 5),
  room_rating INTEGER CHECK (room_rating BETWEEN 1 AND 5),
  staff_rating INTEGER CHECK (staff_rating BETWEEN 1 AND 5),
  activity_rating INTEGER CHECK (activity_rating BETWEEN 1 AND 5),
  review_text TEXT,
  photo_urls TEXT[],
  nps_score INTEGER CHECK (nps_score BETWEEN 0 AND 10),
  is_published BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_guests_phone ON guests(phone);
CREATE INDEX idx_guests_name_trgm ON guests USING GIN(full_name gin_trgm_ops);
CREATE INDEX idx_guests_phone_trgm ON guests USING GIN(phone gin_trgm_ops);
CREATE INDEX idx_guests_tags ON guests USING GIN(tags);

ALTER TABLE guests ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_feedback ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_guests_updated_at BEFORE UPDATE ON guests FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE POLICY "Guests: staff can read" ON guests FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Guests: manager/owner manage" ON guests FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Guest prefs: staff read" ON guest_preferences FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Guest feedback: all read published" ON guest_feedback FOR SELECT USING (is_published = TRUE OR auth_user_role() IN ('OWNER', 'MANAGER'));

-- ROOMS
CREATE TABLE room_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  base_price NUMERIC(10,2) NOT NULL,
  max_occupancy INTEGER NOT NULL DEFAULT 2,
  amenities TEXT[],
  image_urls TEXT[],
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_number TEXT NOT NULL UNIQUE,
  room_type_id UUID NOT NULL REFERENCES room_types(id) ON DELETE RESTRICT,
  floor INTEGER DEFAULT 1,
  status room_status DEFAULT 'AVAILABLE',
  description TEXT,
  view_type TEXT,
  image_urls TEXT[],
  qr_code_url TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE room_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  booking_id UUID,
  guest_id UUID REFERENCES guests(id) ON DELETE SET NULL,
  check_in TIMESTAMPTZ,
  check_out TIMESTAMPTZ,
  status room_status NOT NULL,
  changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_rooms_status ON rooms(status);
CREATE INDEX idx_rooms_type ON rooms(room_type_id);

ALTER TABLE room_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_history ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_rooms_updated_at BEFORE UPDATE ON rooms FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE POLICY "Rooms: all staff read" ON rooms FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Rooms: owner/manager manage" ON rooms FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Room types: all read" ON room_types FOR SELECT USING (auth.uid() IS NOT NULL);

-- Seed room types
INSERT INTO room_types (name, description, base_price, max_occupancy, amenities) VALUES
  ('Mud House Suite', 'Traditional mud house with modern amenities', 4500, 2, ARRAY['AC', 'Hot Water', 'Garden View', 'Sit-Out']),
  ('Farm Cottage', 'Cozy cottage overlooking the farm', 3500, 3, ARRAY['Fan', 'Hot Water', 'Farm View', 'Balcony']),
  ('Heritage Bungalow', 'Colonial-era bungalow', 6500, 4, ARRAY['AC', 'Hot Water', 'Heritage View', 'Kitchenette']),
  ('Tree House', 'Unique elevated stay', 5500, 2, ARRAY['Fan', 'Hot Water', 'Forest View', 'Private Deck']),
  ('Dormitory', 'Shared for school camps', 800, 8, ARRAY['Fan', 'Shared Bathroom', 'Bunk Beds']);

-- BOOKINGS
CREATE SEQUENCE booking_number_seq START 1001;

CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_number TEXT UNIQUE NOT NULL,
  lead_id UUID REFERENCES leads(id) ON DELETE SET NULL,
  primary_guest_id UUID REFERENCES guests(id) ON DELETE RESTRICT,
  package_id UUID REFERENCES packages(id) ON DELETE RESTRICT,
  status booking_status NOT NULL DEFAULT 'INQUIRY',
  payment_status payment_status NOT NULL DEFAULT 'PENDING',
  check_in_date DATE NOT NULL,
  check_out_date DATE,
  num_adults INTEGER NOT NULL DEFAULT 1,
  num_children INTEGER DEFAULT 0,
  num_infants INTEGER DEFAULT 0,
  base_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  addon_amount NUMERIC(12,2) DEFAULT 0,
  discount_amount NUMERIC(12,2) DEFAULT 0,
  tax_amount NUMERIC(12,2) DEFAULT 0,
  total_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  paid_amount NUMERIC(12,2) DEFAULT 0,
  balance_amount NUMERIC(12,2) GENERATED ALWAYS AS (total_amount - paid_amount) STORED,
  special_requests TEXT,
  internal_notes TEXT,
  source lead_source DEFAULT 'PHONE',
  confirmed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  confirmed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE booking_addons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  addon_id UUID REFERENCES package_addons(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  quantity INTEGER DEFAULT 1,
  unit_price NUMERIC(10,2) NOT NULL,
  total_price NUMERIC(10,2) GENERATED ALWAYS AS (quantity * unit_price) STORED,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE booking_rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE RESTRICT,
  check_in TIMESTAMPTZ,
  check_out TIMESTAMPTZ,
  price_per_night NUMERIC(10,2),
  assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(booking_id, room_id)
);

CREATE TABLE groups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  group_name TEXT,
  group_type TEXT,
  contact_person TEXT,
  contact_phone TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE group_participants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  guest_id UUID REFERENCES guests(id) ON DELETE SET NULL,
  full_name TEXT NOT NULL,
  age INTEGER,
  gender gender,
  id_type id_type,
  id_number TEXT,
  food_type food_type DEFAULT 'VEG',
  is_primary BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- FK back-references
ALTER TABLE leads ADD CONSTRAINT fk_leads_converted_booking
  FOREIGN KEY (converted_booking_id) REFERENCES bookings(id) ON DELETE SET NULL;
ALTER TABLE communication_logs ADD CONSTRAINT fk_comm_logs_booking
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;
ALTER TABLE guest_feedback ADD CONSTRAINT fk_feedback_booking
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;
ALTER TABLE room_history ADD CONSTRAINT fk_room_history_booking
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_payment_status ON bookings(payment_status);
CREATE INDEX idx_bookings_check_in ON bookings(check_in_date);
CREATE INDEX idx_bookings_guest ON bookings(primary_guest_id);
CREATE INDEX idx_bookings_created_at ON bookings(created_at DESC);
CREATE INDEX idx_booking_rooms_booking ON booking_rooms(booking_id);
CREATE INDEX idx_booking_rooms_room ON booking_rooms(room_id);

ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_addons ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_participants ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_bookings_updated_at BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Auto-generate booking number
CREATE OR REPLACE FUNCTION generate_booking_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.booking_number := 'ANJ-BK-' || LPAD(nextval('booking_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_booking_number BEFORE INSERT ON bookings
  FOR EACH ROW WHEN (NEW.booking_number IS NULL) EXECUTE FUNCTION generate_booking_number();

CREATE POLICY "Bookings: all staff read" ON bookings FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Bookings: owner/manager insert" ON bookings FOR INSERT WITH CHECK (auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Bookings: owner/manager update" ON bookings FOR UPDATE USING (auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Booking rooms: all staff read" ON booking_rooms FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Booking rooms: owner/manager manage" ON booking_rooms FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER'));

-- CHECK-IN / CHECK-OUT
CREATE TABLE checkins (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  guest_id UUID NOT NULL REFERENCES guests(id) ON DELETE RESTRICT,
  checked_in_at TIMESTAMPTZ DEFAULT NOW(),
  checked_in_by UUID REFERENCES users(id) ON DELETE SET NULL,
  id_verified BOOLEAN DEFAULT FALSE,
  id_type id_type,
  id_number TEXT,
  id_image_url TEXT,
  selfie_url TEXT,
  signature_url TEXT,
  qr_pass_url TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(booking_id, guest_id)
);

CREATE TABLE checkouts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  checked_out_at TIMESTAMPTZ DEFAULT NOW(),
  checked_out_by UUID REFERENCES users(id) ON DELETE SET NULL,
  invoice_url TEXT,
  final_amount NUMERIC(12,2),
  balance_collected NUMERIC(12,2) DEFAULT 0,
  payment_method payment_method,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(booking_id)
);

ALTER TABLE checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkouts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Checkins: all staff read" ON checkins FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Checkins: owner/manager insert" ON checkins FOR INSERT WITH CHECK (auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Checkouts: all staff read" ON checkouts FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Checkouts: owner/manager insert" ON checkouts FOR INSERT WITH CHECK (auth_user_role() IN ('OWNER', 'MANAGER'));

-- Audit triggers for bookings/checkins/checkouts
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_logs(user_id, action, module, record_id, old_data, new_data)
  VALUES (
    auth.uid(), TG_OP, TG_TABLE_NAME,
    CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_audit_bookings AFTER INSERT OR UPDATE OR DELETE ON bookings FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER trg_audit_checkins AFTER INSERT OR UPDATE OR DELETE ON checkins FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER trg_audit_checkouts AFTER INSERT OR UPDATE OR DELETE ON checkouts FOR EACH ROW EXECUTE FUNCTION log_audit();

-- Update guest stats on checkout
CREATE OR REPLACE FUNCTION update_guest_stats_on_checkout()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE guests SET
    total_visits = total_visits + 1,
    last_visit = NOW()::DATE,
    total_spend = total_spend + COALESCE(NEW.final_amount, 0)
  WHERE id = (SELECT primary_guest_id FROM bookings WHERE id = NEW.booking_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guest_stats_on_checkout AFTER INSERT ON checkouts FOR EACH ROW EXECUTE FUNCTION update_guest_stats_on_checkout();

-- Available rooms function
CREATE OR REPLACE FUNCTION get_available_rooms(
  p_check_in DATE, p_check_out DATE, p_room_type_id UUID DEFAULT NULL
)
RETURNS TABLE(room_id UUID, room_number TEXT, room_type TEXT, price NUMERIC, max_occupancy INTEGER) AS $$
BEGIN
  RETURN QUERY
  SELECT r.id, r.room_number, rt.name, rt.base_price, rt.max_occupancy
  FROM rooms r JOIN room_types rt ON r.room_type_id = rt.id
  WHERE r.is_active = TRUE AND r.status != 'MAINTENANCE'
  AND (p_room_type_id IS NULL OR r.room_type_id = p_room_type_id)
  AND r.id NOT IN (
    SELECT br.room_id FROM booking_rooms br JOIN bookings b ON br.booking_id = b.id
    WHERE b.status NOT IN ('CANCELLED', 'NO_SHOW')
    AND (b.check_in_date <= p_check_out AND COALESCE(b.check_out_date, b.check_in_date + 1) >= p_check_in)
  );
END;
$$ LANGUAGE plpgsql;
