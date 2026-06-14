-- Migration 003: CRM, Leads, Packages

-- LEADS
CREATE TABLE leads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  full_name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  source lead_source NOT NULL DEFAULT 'PHONE',
  status lead_status NOT NULL DEFAULT 'NEW',
  group_size INTEGER DEFAULT 1,
  preferred_date DATE,
  preferred_package package_type,
  budget NUMERIC(10,2),
  notes TEXT,
  assigned_to UUID REFERENCES users(id) ON DELETE SET NULL,
  converted_booking_id UUID,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE lead_followups (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lead_id UUID NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
  follow_up_date TIMESTAMPTZ NOT NULL,
  notes TEXT,
  done_by UUID REFERENCES users(id) ON DELETE SET NULL,
  outcome TEXT,
  next_follow_up TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE communication_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  lead_id UUID REFERENCES leads(id) ON DELETE CASCADE,
  booking_id UUID,
  channel TEXT NOT NULL,
  direction TEXT NOT NULL DEFAULT 'OUTBOUND',
  message TEXT,
  template_id UUID,
  sent_by UUID REFERENCES users(id) ON DELETE SET NULL,
  is_delivered BOOLEAN DEFAULT FALSE,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_source ON leads(source);
CREATE INDEX idx_leads_assigned_to ON leads(assigned_to);
CREATE INDEX idx_leads_created_at ON leads(created_at DESC);
CREATE INDEX idx_leads_phone_trgm ON leads USING GIN(phone gin_trgm_ops);
CREATE INDEX idx_leads_name_trgm ON leads USING GIN(full_name gin_trgm_ops);

ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_logs ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_leads_updated_at BEFORE UPDATE ON leads FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE POLICY "Leads: staff can read" ON leads FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Leads: manager/owner can manage" ON leads FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER'));

-- PACKAGES
CREATE TABLE packages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  type package_type NOT NULL,
  description TEXT,
  highlights TEXT[],
  base_price NUMERIC(10,2) NOT NULL,
  price_per_adult NUMERIC(10,2) DEFAULT 0,
  price_per_child NUMERIC(10,2) DEFAULT 0,
  min_persons INTEGER DEFAULT 1,
  max_persons INTEGER DEFAULT 100,
  duration_hours INTEGER,
  duration_nights INTEGER DEFAULT 0,
  includes TEXT[],
  excludes TEXT[],
  cover_image_url TEXT,
  gallery_urls TEXT[],
  is_active BOOLEAN DEFAULT TRUE,
  is_featured BOOLEAN DEFAULT FALSE,
  tax_percent NUMERIC(5,2) DEFAULT 18,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE package_components (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  package_id UUID NOT NULL REFERENCES packages(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  is_mandatory BOOLEAN DEFAULT TRUE,
  additional_price NUMERIC(10,2) DEFAULT 0,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE package_itineraries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  package_id UUID NOT NULL REFERENCES packages(id) ON DELETE CASCADE,
  day_number INTEGER NOT NULL DEFAULT 1,
  time_slot TIME,
  activity_name TEXT NOT NULL,
  description TEXT,
  location TEXT,
  duration_minutes INTEGER,
  sort_order INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE package_addons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  package_id UUID REFERENCES packages(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_itineraries ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_addons ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER trg_packages_updated_at BEFORE UPDATE ON packages FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE POLICY "Packages: all can read active" ON packages FOR SELECT USING (is_active = TRUE OR auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Packages: owner/manager manage" ON packages FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER'));
CREATE POLICY "Package components: all read" ON package_components FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Package itineraries: all read" ON package_itineraries FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Package addons: all read" ON package_addons FOR SELECT USING (auth.uid() IS NOT NULL);

-- Seed packages
INSERT INTO packages (name, slug, type, description, base_price, price_per_adult, price_per_child, duration_hours, duration_nights, includes, tax_percent) VALUES
  ('Day Picnic', 'day-picnic', 'DAY_PICNIC', 'Full day farm experience', 1200, 1200, 600, 8, 0, ARRAY['Welcome Drink', 'Lunch', 'Farm Tour', 'Activities'], 5),
  ('Overnight Farm Stay', 'overnight-farm-stay', 'OVERNIGHT_STAY', 'One night farm stay', 3500, 3500, 1750, 24, 1, ARRAY['Accommodation', 'All Meals', 'Farm Tour', 'Bonfire'], 12),
  ('Heritage Walk', 'heritage-walk', 'HERITAGE_PACKAGE', 'Village heritage walk', 800, 800, 400, 3, 0, ARRAY['Expert Guide', 'Heritage Tour', 'Snacks'], 5),
  ('School Camp', 'school-camp', 'SCHOOL_CAMP', 'Educational camp for students', 2500, 2500, 2000, 48, 2, ARRAY['Accommodation', 'All Meals', 'Activities', 'Workshops'], 5),
  ('Corporate Retreat', 'corporate-retreat', 'CORPORATE_RETREAT', 'Team building retreat', 5000, 5000, 0, 48, 2, ARRAY['Premium Stay', 'All Meals', 'Team Activities', 'Conference Room'], 18),
  ('Farm Experience', 'farm-experience', 'FARM_EXPERIENCE', 'Hands-on farm activities', 1500, 1500, 750, 6, 0, ARRAY['Farm Tour', 'Hands-on', 'Organic Lunch'], 5);
