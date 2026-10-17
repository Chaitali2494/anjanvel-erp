-- ============================================================
-- ANJANVEL ERP - Complete PostgreSQL Schema
-- Agro Tourism Resort & Experience Management Platform
-- ============================================================
-- Version: 1.0.0
-- Generated: 2026-06-14
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================
-- ENUMS
-- ============================================================

CREATE TYPE user_role AS ENUM (
  'OWNER', 'MANAGER', 'HOUSEKEEPING', 'KITCHEN',
  'ACTIVITY_COORDINATOR', 'SHOP_OPERATOR', 'ACCOUNTANT', 'GUIDE'
);

CREATE TYPE booking_status AS ENUM (
  'INQUIRY', 'CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT', 'CANCELLED', 'NO_SHOW'
);

CREATE TYPE payment_status AS ENUM (
  'PENDING', 'PARTIAL', 'PAID', 'REFUNDED', 'FAILED'
);

CREATE TYPE payment_method AS ENUM (
  'CASH', 'UPI', 'CARD', 'ONLINE', 'BANK_TRANSFER'
);

CREATE TYPE room_status AS ENUM (
  'AVAILABLE', 'OCCUPIED', 'RESERVED', 'CLEANING', 'MAINTENANCE'
);

CREATE TYPE package_type AS ENUM (
  'DAY_PICNIC', 'OVERNIGHT_STAY', 'CORPORATE_RETREAT',
  'SCHOOL_CAMP', 'HERITAGE_PACKAGE', 'FARM_EXPERIENCE',
  'WORKSHOP', 'FESTIVAL_PACKAGE'
);

CREATE TYPE lead_source AS ENUM (
  'WEBSITE', 'INSTAGRAM', 'WHATSAPP', 'GOOGLE', 'PHONE', 'WALK_IN', 'REFERRAL'
);

CREATE TYPE lead_status AS ENUM (
  'NEW', 'CONTACTED', 'FOLLOW_UP', 'QUALIFIED', 'CONVERTED', 'LOST'
);

CREATE TYPE food_type AS ENUM (
  'VEG', 'NON_VEG', 'JAIN', 'VEGAN', 'SATVIK'
);

CREATE TYPE meal_type AS ENUM (
  'BREAKFAST', 'LUNCH', 'DINNER', 'SNACKS', 'HIGH_TEA'
);

CREATE TYPE order_status AS ENUM (
  'PENDING', 'PREPARING', 'READY', 'SERVED', 'CANCELLED'
);

CREATE TYPE task_status AS ENUM (
  'PENDING', 'IN_PROGRESS', 'DONE', 'SKIPPED'
);

CREATE TYPE ticket_status AS ENUM (
  'OPEN', 'ASSIGNED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED'
);

CREATE TYPE ticket_priority AS ENUM (
  'LOW', 'MEDIUM', 'HIGH', 'URGENT'
);

CREATE TYPE inventory_category AS ENUM (
  'KITCHEN', 'HOUSEKEEPING', 'FARM', 'MAINTENANCE', 'SHOP'
);

CREATE TYPE transaction_type AS ENUM (
  'IN', 'OUT', 'ADJUSTMENT', 'DAMAGE', 'RETURN'
);

CREATE TYPE activity_status AS ENUM (
  'ACTIVE', 'CANCELLED', 'COMPLETED', 'FULL'
);

CREATE TYPE gender AS ENUM (
  'MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY'
);

CREATE TYPE id_type AS ENUM (
  'AADHAAR', 'PASSPORT', 'DRIVING_LICENSE', 'PAN', 'VOTER_ID'
);

-- ============================================================
-- MODULE 1: USER MANAGEMENT
-- ============================================================

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
  action TEXT NOT NULL, -- CREATE, READ, UPDATE, DELETE, EXPORT
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

-- ============================================================
-- MODULE 2: CRM / LEAD MANAGEMENT
-- ============================================================

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
  converted_booking_id UUID, -- FK added after bookings table
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
  booking_id UUID, -- FK added after bookings table
  channel TEXT NOT NULL, -- 'WHATSAPP', 'SMS', 'EMAIL', 'CALL', 'IN_PERSON'
  direction TEXT NOT NULL DEFAULT 'OUTBOUND', -- 'INBOUND', 'OUTBOUND'
  message TEXT,
  template_id UUID,
  sent_by UUID REFERENCES users(id) ON DELETE SET NULL,
  is_delivered BOOLEAN DEFAULT FALSE,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MODULE 3: PACKAGE MANAGEMENT
-- ============================================================

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
  package_id UUID REFERENCES packages(id) ON DELETE SET NULL, -- NULL = global addon
  name TEXT NOT NULL,
  description TEXT,
  price NUMERIC(10,2) NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MODULE 4: GUEST MANAGEMENT
-- ============================================================

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
  booking_id UUID, -- FK added later
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

-- ============================================================
-- MODULE 5: ROOM MANAGEMENT
-- ============================================================

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
  view_type TEXT, -- 'GARDEN', 'FARM', 'POOL', 'FOREST'
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
  booking_id UUID, -- FK added later
  guest_id UUID REFERENCES guests(id) ON DELETE SET NULL,
  check_in TIMESTAMPTZ,
  check_out TIMESTAMPTZ,
  status room_status NOT NULL,
  changed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MODULE 6: BOOKING MANAGEMENT
-- ============================================================

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
  group_type TEXT, -- 'FAMILY', 'CORPORATE', 'SCHOOL', 'FRIENDS'
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

-- Add FK from leads to bookings
ALTER TABLE leads ADD CONSTRAINT fk_leads_converted_booking
  FOREIGN KEY (converted_booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

-- Add FK from communication_logs to bookings
ALTER TABLE communication_logs ADD CONSTRAINT fk_comm_logs_booking
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;

-- Add FK from guest_feedback to bookings
ALTER TABLE guest_feedback ADD CONSTRAINT fk_feedback_booking
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE;

-- Add FK from room_history to bookings
ALTER TABLE room_history ADD CONSTRAINT fk_room_history_booking
  FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE SET NULL;

-- ============================================================
-- MODULE 7: CHECK-IN / CHECK-OUT
-- ============================================================

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

-- ============================================================
-- MODULE 8: HOUSEKEEPING
-- ============================================================

CREATE TABLE housekeeping_tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  task_type TEXT NOT NULL, -- 'CHECKOUT_CLEAN', 'DAILY_CLEAN', 'TURNDOWN', 'DEEP_CLEAN'
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

-- ============================================================
-- MODULE 9: MAINTENANCE
-- ============================================================

CREATE TABLE maintenance_tickets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  ticket_number TEXT UNIQUE NOT NULL,
  room_id UUID REFERENCES rooms(id) ON DELETE SET NULL,
  location TEXT, -- for common areas
  issue_type TEXT NOT NULL, -- 'ELECTRICAL', 'PLUMBING', 'FURNITURE', 'APPLIANCE', 'OTHER'
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

-- ============================================================
-- MODULE 10: FOOD MANAGEMENT
-- ============================================================

CREATE TABLE food_menu_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  category TEXT, -- 'STARTER', 'MAIN', 'DESSERT', 'BEVERAGE', 'SNACK'
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

-- ============================================================
-- MODULE 11: INVENTORY MANAGEMENT
-- ============================================================

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
  unit TEXT NOT NULL, -- 'KG', 'LITRE', 'PIECE', 'PACKET', 'DOZEN'
  current_stock NUMERIC(12,3) DEFAULT 0,
  min_stock NUMERIC(12,3) DEFAULT 0, -- reorder threshold
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
  reference_id UUID, -- booking_id, purchase_order_id, etc.
  reference_type TEXT, -- 'BOOKING', 'PURCHASE_ORDER', 'MANUAL'
  batch_number TEXT,
  expiry_date DATE,
  notes TEXT,
  done_by UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE purchase_orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  po_number TEXT UNIQUE NOT NULL,
  supplier_id UUID REFERENCES suppliers(id) ON DELETE SET NULL,
  status TEXT DEFAULT 'DRAFT', -- 'DRAFT', 'SENT', 'RECEIVED', 'PARTIAL', 'CANCELLED'
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

-- ============================================================
-- MODULE 12: ACTIVITIES MANAGEMENT
-- ============================================================

CREATE TABLE activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  description TEXT,
  category TEXT, -- 'HERITAGE', 'FARM', 'CRAFT', 'NATURE', 'CULTURAL', 'WELLNESS'
  duration_minutes INTEGER DEFAULT 60,
  max_capacity INTEGER DEFAULT 20,
  price_per_person NUMERIC(10,2) DEFAULT 0,
  min_age INTEGER,
  difficulty_level TEXT DEFAULT 'EASY', -- 'EASY', 'MODERATE', 'HARD'
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

-- ============================================================
-- MODULE 13: HERITAGE WALK MANAGEMENT
-- ============================================================

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

-- ============================================================
-- MODULE 14: ARTISAN / GUIDE MANAGEMENT
-- ============================================================

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
  skill_name TEXT NOT NULL, -- 'POTTERY', 'KANSA_THALI', 'WARLI_ART', 'STORYTELLING', 'MUSIC', 'YOGA', 'MEDITATION', 'HERITAGE_GUIDE'
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

-- ============================================================
-- MODULE 15: SHOP MANAGEMENT
-- ============================================================

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

-- ============================================================
-- MODULE 16: PAYMENT MANAGEMENT
-- ============================================================

CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  payment_number TEXT UNIQUE NOT NULL,
  booking_id UUID REFERENCES bookings(id) ON DELETE SET NULL,
  sale_id UUID REFERENCES sales(id) ON DELETE SET NULL,
  guest_id UUID REFERENCES guests(id) ON DELETE SET NULL,
  amount NUMERIC(12,2) NOT NULL,
  method payment_method NOT NULL,
  status TEXT DEFAULT 'SUCCESS', -- 'PENDING', 'SUCCESS', 'FAILED', 'REFUNDED'
  reference_number TEXT, -- UPI ref, card auth, etc.
  gateway TEXT, -- 'RAZORPAY', 'PAYTM', 'PHONEPE', 'MANUAL'
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
  status TEXT DEFAULT 'PENDING', -- 'PENDING', 'PROCESSED', 'REJECTED'
  refund_method payment_method,
  reference_number TEXT,
  processed_by UUID REFERENCES users(id) ON DELETE SET NULL,
  processed_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MODULE 17: WHATSAPP CRM
-- ============================================================

CREATE TABLE whatsapp_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL UNIQUE,
  trigger_event TEXT NOT NULL, -- 'BOOKING_CONFIRMED', 'PAYMENT_REMINDER', 'CHECKIN_REMINDER', etc.
  template_id TEXT, -- WhatsApp Business API template ID
  message_body TEXT NOT NULL,
  variables TEXT[], -- e.g. ['{{guest_name}}', '{{booking_date}}']
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MODULE 18: NOTIFICATIONS
-- ============================================================

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL, -- 'BOOKING', 'PAYMENT', 'MAINTENANCE', 'HOUSEKEEPING', 'ACTIVITY', 'GENERAL'
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
  platform TEXT NOT NULL, -- 'ANDROID', 'IOS', 'WEB'
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, token)
);

-- ============================================================
-- SEQUENCES FOR HUMAN-READABLE NUMBERS
-- ============================================================

CREATE SEQUENCE booking_number_seq START 1001;
CREATE SEQUENCE ticket_number_seq START 1001;
CREATE SEQUENCE po_number_seq START 1001;
CREATE SEQUENCE sale_number_seq START 1001;
CREATE SEQUENCE payment_number_seq START 1001;
CREATE SEQUENCE order_number_seq START 1001;

-- ============================================================
-- INDEXES
-- ============================================================

-- Users
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_phone ON users(phone);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Leads
CREATE INDEX idx_leads_status ON leads(status);
CREATE INDEX idx_leads_source ON leads(source);
CREATE INDEX idx_leads_assigned_to ON leads(assigned_to);
CREATE INDEX idx_leads_created_at ON leads(created_at DESC);
CREATE INDEX idx_leads_phone_trgm ON leads USING GIN(phone gin_trgm_ops);
CREATE INDEX idx_leads_name_trgm ON leads USING GIN(full_name gin_trgm_ops);

-- Bookings
CREATE INDEX idx_bookings_status ON bookings(status);
CREATE INDEX idx_bookings_payment_status ON bookings(payment_status);
CREATE INDEX idx_bookings_check_in ON bookings(check_in_date);
CREATE INDEX idx_bookings_guest ON bookings(primary_guest_id);
CREATE INDEX idx_bookings_package ON bookings(package_id);
CREATE INDEX idx_bookings_created_at ON bookings(created_at DESC);
CREATE INDEX idx_bookings_number ON bookings(booking_number);

-- Guests
CREATE INDEX idx_guests_phone ON guests(phone);
CREATE INDEX idx_guests_name_trgm ON guests USING GIN(full_name gin_trgm_ops);
CREATE INDEX idx_guests_phone_trgm ON guests USING GIN(phone gin_trgm_ops);
CREATE INDEX idx_guests_tags ON guests USING GIN(tags);

-- Rooms
CREATE INDEX idx_rooms_status ON rooms(status);
CREATE INDEX idx_rooms_type ON rooms(room_type_id);
CREATE INDEX idx_booking_rooms_booking ON booking_rooms(booking_id);
CREATE INDEX idx_booking_rooms_room ON booking_rooms(room_id);

-- Housekeeping
CREATE INDEX idx_hk_tasks_room ON housekeeping_tasks(room_id);
CREATE INDEX idx_hk_tasks_status ON housekeeping_tasks(status);
CREATE INDEX idx_hk_tasks_assigned ON housekeeping_tasks(assigned_to);

-- Maintenance
CREATE INDEX idx_maint_status ON maintenance_tickets(status);
CREATE INDEX idx_maint_priority ON maintenance_tickets(priority);
CREATE INDEX idx_maint_assigned ON maintenance_tickets(assigned_to);

-- Inventory
CREATE INDEX idx_inv_category ON inventory_items(category);
CREATE INDEX idx_inv_low_stock ON inventory_items(current_stock) WHERE current_stock <= min_stock;

-- Payments
CREATE INDEX idx_payments_booking ON payments(booking_id);
CREATE INDEX idx_payments_created_at ON payments(created_at DESC);

-- Audit logs
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_module ON audit_logs(module);
CREATE INDEX idx_audit_created_at ON audit_logs(created_at DESC);

-- Notifications
CREATE INDEX idx_notif_user ON notifications(user_id);
CREATE INDEX idx_notif_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;

-- Activities
CREATE INDEX idx_activity_sessions_date ON activity_sessions(session_date);
CREATE INDEX idx_activity_bookings_session ON activity_bookings(session_id);

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Auto-generate booking number
CREATE OR REPLACE FUNCTION generate_booking_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.booking_number := 'ANJ-BK-' || LPAD(nextval('booking_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_booking_number
  BEFORE INSERT ON bookings
  FOR EACH ROW
  WHEN (NEW.booking_number IS NULL)
  EXECUTE FUNCTION generate_booking_number();

-- Auto-generate ticket number
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.ticket_number := 'ANJ-MT-' || LPAD(nextval('ticket_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ticket_number
  BEFORE INSERT ON maintenance_tickets
  FOR EACH ROW
  WHEN (NEW.ticket_number IS NULL)
  EXECUTE FUNCTION generate_ticket_number();

-- Auto-generate PO number
CREATE OR REPLACE FUNCTION generate_po_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.po_number := 'ANJ-PO-' || LPAD(nextval('po_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_po_number
  BEFORE INSERT ON purchase_orders
  FOR EACH ROW
  WHEN (NEW.po_number IS NULL)
  EXECUTE FUNCTION generate_po_number();

-- Auto-generate sale number
CREATE OR REPLACE FUNCTION generate_sale_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.sale_number := 'ANJ-SL-' || LPAD(nextval('sale_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sale_number
  BEFORE INSERT ON sales
  FOR EACH ROW
  WHEN (NEW.sale_number IS NULL)
  EXECUTE FUNCTION generate_sale_number();

-- Auto-generate payment number
CREATE OR REPLACE FUNCTION generate_payment_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.payment_number := 'ANJ-PY-' || LPAD(nextval('payment_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payment_number
  BEFORE INSERT ON payments
  FOR EACH ROW
  WHEN (NEW.payment_number IS NULL)
  EXECUTE FUNCTION generate_payment_number();

-- Auto-generate food order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.order_number := 'ANJ-FO-' || LPAD(nextval('order_number_seq')::TEXT, 5, '0');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_order_number
  BEFORE INSERT ON food_orders
  FOR EACH ROW
  WHEN (NEW.order_number IS NULL)
  EXECUTE FUNCTION generate_order_number();

-- Update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_leads_updated_at BEFORE UPDATE ON leads FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_bookings_updated_at BEFORE UPDATE ON bookings FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_packages_updated_at BEFORE UPDATE ON packages FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_rooms_updated_at BEFORE UPDATE ON rooms FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_guests_updated_at BEFORE UPDATE ON guests FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_inventory_updated_at BEFORE UPDATE ON inventory_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_hk_updated_at BEFORE UPDATE ON housekeeping_tasks FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_maint_updated_at BEFORE UPDATE ON maintenance_tickets FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON shop_products FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Update inventory stock on transaction
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

CREATE TRIGGER trg_inventory_stock
  AFTER INSERT ON inventory_transactions
  FOR EACH ROW
  EXECUTE FUNCTION update_inventory_stock();

-- Update booking paid_amount on payment insert
CREATE OR REPLACE FUNCTION update_booking_paid_amount()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.booking_id IS NOT NULL AND NEW.status = 'SUCCESS' THEN
    UPDATE bookings SET
      paid_amount = (
        SELECT COALESCE(SUM(amount), 0) FROM payments
        WHERE booking_id = NEW.booking_id AND status = 'SUCCESS'
      )
    WHERE id = NEW.booking_id;
    -- Update payment_status
    UPDATE bookings SET
      payment_status = CASE
        WHEN paid_amount >= total_amount THEN 'PAID'::payment_status
        WHEN paid_amount > 0 THEN 'PARTIAL'::payment_status
        ELSE 'PENDING'::payment_status
      END
    WHERE id = NEW.booking_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payment_update_booking
  AFTER INSERT OR UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION update_booking_paid_amount();

-- Update shop product stock on sale
CREATE OR REPLACE FUNCTION update_shop_stock_on_sale()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.product_id IS NOT NULL THEN
    UPDATE shop_products SET stock_quantity = stock_quantity - NEW.quantity WHERE id = NEW.product_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_shop_stock_on_sale
  AFTER INSERT ON sale_items
  FOR EACH ROW
  EXECUTE FUNCTION update_shop_stock_on_sale();

-- Update guest total_visits and total_spend on checkout
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

CREATE TRIGGER trg_guest_stats_on_checkout
  AFTER INSERT ON checkouts
  FOR EACH ROW
  EXECUTE FUNCTION update_guest_stats_on_checkout();

-- Audit log trigger function
CREATE OR REPLACE FUNCTION log_audit()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO audit_logs(user_id, action, module, record_id, old_data, new_data)
  VALUES (
    auth.uid(),
    TG_OP,
    TG_TABLE_NAME,
    CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END,
    CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
    CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN to_jsonb(NEW) ELSE NULL END
  );
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_audit_bookings AFTER INSERT OR UPDATE OR DELETE ON bookings FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER trg_audit_payments AFTER INSERT OR UPDATE OR DELETE ON payments FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER trg_audit_checkins AFTER INSERT OR UPDATE OR DELETE ON checkins FOR EACH ROW EXECUTE FUNCTION log_audit();
CREATE TRIGGER trg_audit_checkouts AFTER INSERT OR UPDATE OR DELETE ON checkouts FOR EACH ROW EXECUTE FUNCTION log_audit();

-- ============================================================
-- VIEWS
-- ============================================================

-- Room availability view
CREATE OR REPLACE VIEW v_room_availability AS
SELECT
  r.id,
  r.room_number,
  rt.name AS room_type,
  rt.base_price,
  rt.max_occupancy,
  r.floor,
  r.status,
  r.view_type,
  r.image_urls,
  CASE WHEN r.status = 'AVAILABLE' THEN TRUE ELSE FALSE END AS is_available,
  (
    SELECT COUNT(*) FROM booking_rooms br
    JOIN bookings b ON br.booking_id = b.id
    WHERE br.room_id = r.id
    AND b.status NOT IN ('CANCELLED', 'CHECKED_OUT')
  ) AS active_bookings
FROM rooms r
JOIN room_types rt ON r.room_type_id = rt.id
WHERE r.is_active = TRUE;

-- Booking summary view
CREATE OR REPLACE VIEW v_booking_summary AS
SELECT
  b.id,
  b.booking_number,
  b.status,
  b.payment_status,
  b.check_in_date,
  b.check_out_date,
  b.total_amount,
  b.paid_amount,
  b.balance_amount,
  b.num_adults + b.num_children AS total_guests,
  g.full_name AS guest_name,
  g.phone AS guest_phone,
  p.name AS package_name,
  p.type AS package_type,
  ARRAY_AGG(r.room_number) FILTER (WHERE r.room_number IS NOT NULL) AS rooms,
  b.created_at
FROM bookings b
LEFT JOIN guests g ON b.primary_guest_id = g.id
LEFT JOIN packages p ON b.package_id = p.id
LEFT JOIN booking_rooms br ON b.id = br.booking_id
LEFT JOIN rooms r ON br.room_id = r.id
GROUP BY b.id, g.full_name, g.phone, p.name, p.type;

-- Daily revenue view
CREATE OR REPLACE VIEW v_daily_revenue AS
SELECT
  DATE(p.created_at) AS date,
  SUM(CASE WHEN p.status = 'SUCCESS' THEN p.amount ELSE 0 END) AS total_revenue,
  COUNT(CASE WHEN p.status = 'SUCCESS' THEN 1 END) AS total_transactions,
  SUM(CASE WHEN p.method = 'CASH' AND p.status = 'SUCCESS' THEN p.amount ELSE 0 END) AS cash_revenue,
  SUM(CASE WHEN p.method = 'UPI' AND p.status = 'SUCCESS' THEN p.amount ELSE 0 END) AS upi_revenue,
  SUM(CASE WHEN p.method = 'CARD' AND p.status = 'SUCCESS' THEN p.amount ELSE 0 END) AS card_revenue
FROM payments p
GROUP BY DATE(p.created_at);

-- Occupancy view
CREATE OR REPLACE VIEW v_occupancy AS
SELECT
  check_in_date AS date,
  COUNT(*) AS total_bookings,
  SUM(num_adults + num_children) AS total_guests,
  SUM(CASE WHEN status = 'CHECKED_IN' THEN 1 ELSE 0 END) AS active_checkins,
  SUM(CASE WHEN status = 'CONFIRMED' THEN 1 ELSE 0 END) AS confirmed_bookings
FROM bookings
WHERE status NOT IN ('CANCELLED', 'NO_SHOW')
GROUP BY check_in_date;

-- Low stock alert view
CREATE OR REPLACE VIEW v_low_stock_alerts AS
SELECT
  id,
  name,
  sku,
  category,
  unit,
  current_stock,
  min_stock,
  (min_stock - current_stock) AS shortage,
  supplier_id
FROM inventory_items
WHERE current_stock <= min_stock AND is_active = TRUE;

-- Activity revenue view
CREATE OR REPLACE VIEW v_activity_revenue AS
SELECT
  a.id,
  a.name,
  a.category,
  COUNT(ab.id) AS total_bookings,
  SUM(ab.num_participants) AS total_participants,
  SUM(ab.amount) AS total_revenue
FROM activities a
LEFT JOIN activity_sessions acs ON a.id = acs.activity_id
LEFT JOIN activity_bookings ab ON acs.id = ab.session_id
WHERE ab.payment_status = 'PAID'
GROUP BY a.id, a.name, a.category;

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

-- Check available rooms for a date range
CREATE OR REPLACE FUNCTION get_available_rooms(
  p_check_in DATE,
  p_check_out DATE,
  p_room_type_id UUID DEFAULT NULL
)
RETURNS TABLE(
  room_id UUID,
  room_number TEXT,
  room_type TEXT,
  price NUMERIC,
  max_occupancy INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    r.id,
    r.room_number,
    rt.name,
    rt.base_price,
    rt.max_occupancy
  FROM rooms r
  JOIN room_types rt ON r.room_type_id = rt.id
  WHERE r.is_active = TRUE
  AND r.status != 'MAINTENANCE'
  AND (p_room_type_id IS NULL OR r.room_type_id = p_room_type_id)
  AND r.id NOT IN (
    SELECT br.room_id FROM booking_rooms br
    JOIN bookings b ON br.booking_id = b.id
    WHERE b.status NOT IN ('CANCELLED', 'NO_SHOW')
    AND (
      (br.check_in::DATE <= p_check_out AND br.check_out::DATE >= p_check_in)
      OR
      (b.check_in_date <= p_check_out AND COALESCE(b.check_out_date, b.check_in_date + 1) >= p_check_in)
    )
  );
END;
$$ LANGUAGE plpgsql;

-- Get booking revenue summary
CREATE OR REPLACE FUNCTION get_revenue_summary(
  p_from DATE,
  p_to DATE
)
RETURNS TABLE(
  total_bookings BIGINT,
  confirmed_bookings BIGINT,
  total_revenue NUMERIC,
  collected_revenue NUMERIC,
  pending_revenue NUMERIC,
  avg_booking_value NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    COUNT(*)::BIGINT,
    COUNT(*) FILTER (WHERE status IN ('CONFIRMED', 'CHECKED_IN', 'CHECKED_OUT'))::BIGINT,
    COALESCE(SUM(total_amount), 0),
    COALESCE(SUM(paid_amount), 0),
    COALESCE(SUM(balance_amount), 0),
    COALESCE(AVG(total_amount), 0)
  FROM bookings
  WHERE check_in_date BETWEEN p_from AND p_to
  AND status != 'CANCELLED';
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE lead_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_itineraries ENABLE ROW LEVEL SECURITY;
ALTER TABLE package_addons ENABLE ROW LEVEL SECURITY;
ALTER TABLE guests ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE guest_feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE booking_addons ENABLE ROW LEVEL SECURITY;
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE checkouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE housekeeping_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE cleaning_checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE heritage_walk_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE heritage_walk_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE heritage_walk_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE artisans ENABLE ROW LEVEL SECURITY;
ALTER TABLE artisan_skills ENABLE ROW LEVEL SECURITY;
ALTER TABLE artisan_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE shop_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE sale_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;

-- Helper function to get current user role
CREATE OR REPLACE FUNCTION auth_user_role()
RETURNS user_role AS $$
  SELECT role FROM users WHERE id = auth.uid()
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- OWNER and MANAGER have full access to most tables
-- Specific roles have limited access

-- Users table RLS
CREATE POLICY "Users: authenticated can read own profile"
  ON users FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users: owner/manager can read all"
  ON users FOR SELECT USING (auth_user_role() IN ('OWNER', 'MANAGER'));

CREATE POLICY "Users: owner can manage all"
  ON users FOR ALL USING (auth_user_role() = 'OWNER');

-- Bookings RLS
CREATE POLICY "Bookings: staff can read all"
  ON bookings FOR SELECT
  USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACCOUNTANT'));

CREATE POLICY "Bookings: all authenticated staff can read"
  ON bookings FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Bookings: owner/manager can insert"
  ON bookings FOR INSERT
  WITH CHECK (auth_user_role() IN ('OWNER', 'MANAGER'));

CREATE POLICY "Bookings: owner/manager can update"
  ON bookings FOR UPDATE
  USING (auth_user_role() IN ('OWNER', 'MANAGER'));

-- Rooms RLS
CREATE POLICY "Rooms: all staff can read"
  ON rooms FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Rooms: owner/manager can manage"
  ON rooms FOR ALL USING (auth_user_role() IN ('OWNER', 'MANAGER'));

-- Housekeeping RLS
CREATE POLICY "HK: housekeeping can read own tasks"
  ON housekeeping_tasks FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "HK: housekeeping can update own tasks"
  ON housekeeping_tasks FOR UPDATE
  USING (assigned_to = auth.uid() OR auth_user_role() IN ('OWNER', 'MANAGER'));

-- Food orders RLS
CREATE POLICY "Food: kitchen/manager can read all"
  ON food_orders FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Food: kitchen can update"
  ON food_orders FOR UPDATE
  USING (auth_user_role() IN ('KITCHEN', 'MANAGER', 'OWNER'));

-- Inventory RLS
CREATE POLICY "Inventory: relevant roles can read"
  ON inventory_items FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Inventory: manager/owner/accountant can manage"
  ON inventory_items FOR ALL
  USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACCOUNTANT'));

-- Payments RLS
CREATE POLICY "Payments: accountant/owner/manager can read"
  ON payments FOR SELECT
  USING (auth_user_role() IN ('OWNER', 'MANAGER', 'ACCOUNTANT'));

CREATE POLICY "Payments: accountant/owner can insert"
  ON payments FOR INSERT
  WITH CHECK (auth_user_role() IN ('OWNER', 'MANAGER', 'ACCOUNTANT'));

-- Notifications RLS
CREATE POLICY "Notifications: users read own"
  ON notifications FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "Notifications: users update own (mark read)"
  ON notifications FOR UPDATE USING (user_id = auth.uid());

-- Audit logs: only owner can read
CREATE POLICY "Audit: owner can read all"
  ON audit_logs FOR SELECT USING (auth_user_role() = 'OWNER');

-- Shop: shop operator and above
CREATE POLICY "Shop products: all staff read"
  ON shop_products FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Shop products: shop operator/manager/owner manage"
  ON shop_products FOR ALL
  USING (auth_user_role() IN ('OWNER', 'MANAGER', 'SHOP_OPERATOR'));

-- ============================================================
-- SEED DATA
-- ============================================================

-- Roles display names
INSERT INTO roles (name, display_name, description) VALUES
  ('OWNER', 'Owner', 'Full access to all modules and settings'),
  ('MANAGER', 'Manager', 'Access to all operational modules'),
  ('HOUSEKEEPING', 'Housekeeping Staff', 'Access to rooms and cleaning tasks'),
  ('KITCHEN', 'Kitchen Staff', 'Access to food orders and kitchen dashboard'),
  ('ACTIVITY_COORDINATOR', 'Activity Coordinator', 'Manages activities and heritage walks'),
  ('SHOP_OPERATOR', 'Shop Operator', 'Manages shop and POS billing'),
  ('ACCOUNTANT', 'Accountant', 'Access to payments and financial reports'),
  ('GUIDE', 'Guide / Artisan', 'Manages assigned tours and activities');

-- Default permissions
INSERT INTO permissions (role, module, action) VALUES
  -- Owner gets everything
  ('OWNER', '*', 'CREATE'), ('OWNER', '*', 'READ'), ('OWNER', '*', 'UPDATE'),
  ('OWNER', '*', 'DELETE'), ('OWNER', '*', 'EXPORT'),
  -- Manager
  ('MANAGER', 'BOOKINGS', 'CREATE'), ('MANAGER', 'BOOKINGS', 'READ'),
  ('MANAGER', 'BOOKINGS', 'UPDATE'), ('MANAGER', 'ROOMS', 'READ'),
  ('MANAGER', 'ROOMS', 'UPDATE'), ('MANAGER', 'LEADS', 'CREATE'),
  ('MANAGER', 'LEADS', 'READ'), ('MANAGER', 'LEADS', 'UPDATE'),
  ('MANAGER', 'GUESTS', 'READ'), ('MANAGER', 'GUESTS', 'UPDATE'),
  ('MANAGER', 'REPORTS', 'READ'), ('MANAGER', 'REPORTS', 'EXPORT'),
  -- Housekeeping
  ('HOUSEKEEPING', 'ROOMS', 'READ'), ('HOUSEKEEPING', 'HOUSEKEEPING', 'READ'),
  ('HOUSEKEEPING', 'HOUSEKEEPING', 'UPDATE'), ('HOUSEKEEPING', 'MAINTENANCE', 'CREATE'),
  -- Kitchen
  ('KITCHEN', 'FOOD', 'READ'), ('KITCHEN', 'FOOD', 'UPDATE'),
  ('KITCHEN', 'INVENTORY', 'READ'),
  -- Activity Coordinator
  ('ACTIVITY_COORDINATOR', 'ACTIVITIES', 'CREATE'), ('ACTIVITY_COORDINATOR', 'ACTIVITIES', 'READ'),
  ('ACTIVITY_COORDINATOR', 'ACTIVITIES', 'UPDATE'),
  -- Shop Operator
  ('SHOP_OPERATOR', 'SHOP', 'CREATE'), ('SHOP_OPERATOR', 'SHOP', 'READ'),
  ('SHOP_OPERATOR', 'SHOP', 'UPDATE'),
  -- Accountant
  ('ACCOUNTANT', 'PAYMENTS', 'READ'), ('ACCOUNTANT', 'PAYMENTS', 'CREATE'),
  ('ACCOUNTANT', 'REPORTS', 'READ'), ('ACCOUNTANT', 'REPORTS', 'EXPORT'),
  -- Guide
  ('GUIDE', 'ACTIVITIES', 'READ'), ('GUIDE', 'HERITAGE', 'READ');

-- Room types
INSERT INTO room_types (name, description, base_price, max_occupancy, amenities) VALUES
  ('Mud House Suite', 'Traditional mud house with modern amenities', 4500, 2, ARRAY['AC', 'Hot Water', 'Garden View', 'Sit-Out']),
  ('Farm Cottage', 'Cozy cottage overlooking the farm', 3500, 3, ARRAY['Fan', 'Hot Water', 'Farm View', 'Balcony']),
  ('Heritage Bungalow', 'Colonial-era bungalow with heritage character', 6500, 4, ARRAY['AC', 'Hot Water', 'Heritage View', 'Sit-Out', 'Kitchenette']),
  ('Tree House', 'Unique elevated stay among trees', 5500, 2, ARRAY['Fan', 'Hot Water', 'Forest View', 'Private Deck']),
  ('Dormitory', 'Shared accommodation for school camps', 800, 8, ARRAY['Fan', 'Shared Bathroom', 'Bunk Beds']);

-- Packages
INSERT INTO packages (name, slug, type, description, base_price, price_per_adult, price_per_child, duration_hours, duration_nights, includes, tax_percent) VALUES
  ('Day Picnic', 'day-picnic', 'DAY_PICNIC', 'Full day farm experience with meals and activities', 1200, 1200, 600, 8, 0, ARRAY['Welcome Drink', 'Lunch', 'Farm Tour', 'Activities'], 5),
  ('Overnight Farm Stay', 'overnight-farm-stay', 'OVERNIGHT_STAY', 'One night farm stay with all meals', 3500, 3500, 1750, 24, 1, ARRAY['Accommodation', 'All Meals', 'Farm Tour', 'Bonfire', 'Morning Walk'], 12),
  ('Heritage Walk Package', 'heritage-walk', 'HERITAGE_PACKAGE', 'Guided village and heritage walk experience', 800, 800, 400, 3, 0, ARRAY['Expert Guide', 'Heritage Tour', 'Local Snacks'], 5),
  ('School Camp', 'school-camp', 'SCHOOL_CAMP', 'Educational camp for school students', 2500, 2500, 2000, 48, 2, ARRAY['Accommodation', 'All Meals', 'Activities', 'Workshops', 'Supervision'], 5),
  ('Corporate Retreat', 'corporate-retreat', 'CORPORATE_RETREAT', 'Team building and corporate wellness retreat', 5000, 5000, 0, 48, 2, ARRAY['Premium Accommodation', 'All Meals', 'Team Activities', 'Conference Room', 'WiFi'], 18),
  ('Farm Experience', 'farm-experience', 'FARM_EXPERIENCE', 'Hands-on farm activities and organic experience', 1500, 1500, 750, 6, 0, ARRAY['Farm Tour', 'Hands-on Activities', 'Organic Lunch', 'Produce to Take Home'], 5);

-- Activities
INSERT INTO activities (name, slug, description, category, duration_minutes, price_per_person) VALUES
  ('Heritage Walk', 'heritage-walk', 'Guided walk through historic village and landmarks', 'HERITAGE', 90, 300),
  ('Pottery Workshop', 'pottery-workshop', 'Learn traditional pottery with local artisans', 'CRAFT', 120, 500),
  ('Farm Tour', 'farm-tour', 'Guided organic farm tour with hands-on experience', 'FARM', 60, 200),
  ('Bird Watching', 'bird-watching', 'Early morning bird watching with expert naturalist', 'NATURE', 90, 350),
  ('Bonfire Evening', 'bonfire', 'Evening bonfire with folk music and storytelling', 'CULTURAL', 120, 300),
  ('Warli Art Class', 'warli-art', 'Traditional Warli tribal painting workshop', 'CRAFT', 90, 400),
  ('Yoga & Meditation', 'yoga-meditation', 'Morning yoga and meditation in nature', 'WELLNESS', 60, 250),
  ('Village Tour', 'village-tour', 'Guided tour of local village and community', 'HERITAGE', 120, 400),
  ('Kansa Thali Workshop', 'kansa-thali', 'Traditional Kansa metalwork demonstration', 'CRAFT', 90, 600),
  ('Organic Cooking', 'organic-cooking', 'Cook a farm-to-table meal with local ingredients', 'CULTURAL', 150, 700);

-- Shop categories
INSERT INTO shop_categories (name, sort_order) VALUES
  ('Honey & Preserves', 1), ('Millets & Grains', 2), ('Pickles & Chutneys', 3),
  ('Handicrafts', 4), ('Books & Stories', 5), ('Souvenirs', 6), ('Organic Products', 7);

-- WhatsApp templates
INSERT INTO whatsapp_templates (name, trigger_event, message_body, variables) VALUES
  ('Booking Confirmation', 'BOOKING_CONFIRMED', 'Dear {{guest_name}}, your booking {{booking_number}} at Anjanvel Agro Resort is confirmed for {{check_in_date}}. Total: ₹{{total_amount}}. We look forward to hosting you! 🌿', ARRAY['guest_name', 'booking_number', 'check_in_date', 'total_amount']),
  ('Payment Reminder', 'PAYMENT_REMINDER', 'Dear {{guest_name}}, a payment of ₹{{balance_amount}} is pending for booking {{booking_number}}. Please complete your payment to confirm your stay. 🙏', ARRAY['guest_name', 'balance_amount', 'booking_number']),
  ('Check-In Reminder', 'CHECKIN_REMINDER', 'Dear {{guest_name}}, your check-in at Anjanvel is tomorrow ({{check_in_date}}). Please carry a valid ID. We are excited to welcome you! 🌾', ARRAY['guest_name', 'check_in_date']),
  ('Checkout Reminder', 'CHECKOUT_REMINDER', 'Dear {{guest_name}}, your checkout is scheduled for today. We hope you had a wonderful stay. Please visit us again! 🌿', ARRAY['guest_name']),
  ('Feedback Request', 'FEEDBACK_REQUEST', 'Dear {{guest_name}}, thank you for staying at Anjanvel! Please share your experience: {{feedback_link}} Your feedback helps us improve. 🙏', ARRAY['guest_name', 'feedback_link']);
