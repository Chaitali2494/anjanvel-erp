-- Migration 007: Views, Stored Procedures, Permissions Seed

-- VIEWS

CREATE OR REPLACE VIEW v_room_availability AS
SELECT
  r.id, r.room_number, rt.name AS room_type,
  rt.base_price, rt.max_occupancy,
  r.floor, r.status, r.view_type, r.image_urls,
  CASE WHEN r.status = 'AVAILABLE' THEN TRUE ELSE FALSE END AS is_available
FROM rooms r JOIN room_types rt ON r.room_type_id = rt.id
WHERE r.is_active = TRUE;

CREATE OR REPLACE VIEW v_booking_summary AS
SELECT
  b.id, b.booking_number, b.status, b.payment_status,
  b.check_in_date, b.check_out_date,
  b.total_amount, b.paid_amount, b.balance_amount,
  b.num_adults + b.num_children AS total_guests,
  g.full_name AS guest_name, g.phone AS guest_phone,
  p.name AS package_name, p.type AS package_type,
  ARRAY_AGG(r.room_number) FILTER (WHERE r.room_number IS NOT NULL) AS rooms,
  b.created_at
FROM bookings b
LEFT JOIN guests g ON b.primary_guest_id = g.id
LEFT JOIN packages p ON b.package_id = p.id
LEFT JOIN booking_rooms br ON b.id = br.booking_id
LEFT JOIN rooms r ON br.room_id = r.id
GROUP BY b.id, g.full_name, g.phone, p.name, p.type;

CREATE OR REPLACE VIEW v_daily_revenue AS
SELECT
  DATE(p.created_at) AS date,
  SUM(CASE WHEN p.status = 'SUCCESS' THEN p.amount ELSE 0 END) AS total_revenue,
  COUNT(CASE WHEN p.status = 'SUCCESS' THEN 1 END) AS total_transactions,
  SUM(CASE WHEN p.method = 'CASH' AND p.status = 'SUCCESS' THEN p.amount ELSE 0 END) AS cash_revenue,
  SUM(CASE WHEN p.method = 'UPI' AND p.status = 'SUCCESS' THEN p.amount ELSE 0 END) AS upi_revenue,
  SUM(CASE WHEN p.method = 'CARD' AND p.status = 'SUCCESS' THEN p.amount ELSE 0 END) AS card_revenue
FROM payments p GROUP BY DATE(p.created_at);

CREATE OR REPLACE VIEW v_occupancy AS
SELECT
  check_in_date AS date,
  COUNT(*) AS total_bookings,
  SUM(num_adults + num_children) AS total_guests,
  SUM(CASE WHEN status = 'CHECKED_IN' THEN 1 ELSE 0 END) AS active_checkins,
  SUM(CASE WHEN status = 'CONFIRMED' THEN 1 ELSE 0 END) AS confirmed_bookings
FROM bookings WHERE status NOT IN ('CANCELLED', 'NO_SHOW')
GROUP BY check_in_date;

CREATE OR REPLACE VIEW v_low_stock_alerts AS
SELECT id, name, sku, category, unit, current_stock, min_stock,
  (min_stock - current_stock) AS shortage, supplier_id
FROM inventory_items WHERE current_stock <= min_stock AND is_active = TRUE;

CREATE OR REPLACE VIEW v_activity_revenue AS
SELECT
  a.id, a.name, a.category,
  COUNT(ab.id) AS total_bookings,
  SUM(ab.num_participants) AS total_participants,
  SUM(ab.amount) AS total_revenue
FROM activities a
LEFT JOIN activity_sessions acs ON a.id = acs.activity_id
LEFT JOIN activity_bookings ab ON acs.id = ab.session_id
WHERE ab.payment_status = 'PAID'
GROUP BY a.id, a.name, a.category;

CREATE OR REPLACE VIEW v_todays_dashboard AS
SELECT
  (SELECT COUNT(*) FROM bookings WHERE check_in_date = CURRENT_DATE AND status = 'CONFIRMED') AS checkins_today,
  (SELECT COUNT(*) FROM bookings WHERE check_out_date = CURRENT_DATE AND status = 'CHECKED_IN') AS checkouts_today,
  (SELECT COUNT(*) FROM bookings WHERE status = 'CHECKED_IN') AS guests_inhouse,
  (SELECT COALESCE(SUM(amount), 0) FROM payments WHERE DATE(created_at) = CURRENT_DATE AND status = 'SUCCESS') AS revenue_today,
  (SELECT COUNT(*) FROM housekeeping_tasks WHERE status = 'PENDING' AND DATE(scheduled_at) = CURRENT_DATE) AS hk_pending,
  (SELECT COUNT(*) FROM maintenance_tickets WHERE status IN ('OPEN', 'ASSIGNED')) AS maintenance_open,
  (SELECT COUNT(*) FROM food_orders WHERE status IN ('PENDING', 'PREPARING') AND DATE(ordered_at) = CURRENT_DATE) AS food_orders_pending,
  (SELECT COUNT(*) FROM leads WHERE status = 'NEW') AS new_leads;

-- STORED PROCEDURES

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

CREATE OR REPLACE FUNCTION get_revenue_summary(p_from DATE, p_to DATE)
RETURNS TABLE(
  total_bookings BIGINT, confirmed_bookings BIGINT,
  total_revenue NUMERIC, collected_revenue NUMERIC,
  pending_revenue NUMERIC, avg_booking_value NUMERIC
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
  WHERE check_in_date BETWEEN p_from AND p_to AND status != 'CANCELLED';
END;
$$ LANGUAGE plpgsql;

-- Seed default permissions
INSERT INTO permissions (role, module, action) VALUES
  ('OWNER', '*', 'CREATE'), ('OWNER', '*', 'READ'), ('OWNER', '*', 'UPDATE'), ('OWNER', '*', 'DELETE'), ('OWNER', '*', 'EXPORT'),
  ('MANAGER', 'BOOKINGS', 'CREATE'), ('MANAGER', 'BOOKINGS', 'READ'), ('MANAGER', 'BOOKINGS', 'UPDATE'),
  ('MANAGER', 'ROOMS', 'READ'), ('MANAGER', 'ROOMS', 'UPDATE'),
  ('MANAGER', 'LEADS', 'CREATE'), ('MANAGER', 'LEADS', 'READ'), ('MANAGER', 'LEADS', 'UPDATE'),
  ('MANAGER', 'GUESTS', 'READ'), ('MANAGER', 'GUESTS', 'UPDATE'),
  ('MANAGER', 'REPORTS', 'READ'), ('MANAGER', 'REPORTS', 'EXPORT'),
  ('HOUSEKEEPING', 'ROOMS', 'READ'), ('HOUSEKEEPING', 'HOUSEKEEPING', 'READ'), ('HOUSEKEEPING', 'HOUSEKEEPING', 'UPDATE'),
  ('HOUSEKEEPING', 'MAINTENANCE', 'CREATE'),
  ('KITCHEN', 'FOOD', 'READ'), ('KITCHEN', 'FOOD', 'UPDATE'), ('KITCHEN', 'INVENTORY', 'READ'),
  ('ACTIVITY_COORDINATOR', 'ACTIVITIES', 'CREATE'), ('ACTIVITY_COORDINATOR', 'ACTIVITIES', 'READ'), ('ACTIVITY_COORDINATOR', 'ACTIVITIES', 'UPDATE'),
  ('SHOP_OPERATOR', 'SHOP', 'CREATE'), ('SHOP_OPERATOR', 'SHOP', 'READ'), ('SHOP_OPERATOR', 'SHOP', 'UPDATE'),
  ('ACCOUNTANT', 'PAYMENTS', 'READ'), ('ACCOUNTANT', 'PAYMENTS', 'CREATE'), ('ACCOUNTANT', 'REPORTS', 'READ'), ('ACCOUNTANT', 'REPORTS', 'EXPORT'),
  ('GUIDE', 'ACTIVITIES', 'READ'), ('GUIDE', 'HERITAGE', 'READ');
