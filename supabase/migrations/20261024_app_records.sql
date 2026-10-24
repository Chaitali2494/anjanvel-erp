-- Shared storage for data that used to live only in browser memory
-- (food orders, guest requests, DND, in-app bookings, bill payments, shop sales).
-- Used by flutter_app/lib/core/services/cloud_store.dart

create table if not exists public.app_records (
  collection  text        not null,
  id          text        not null,
  data        jsonb       not null default '{}'::jsonb,
  deleted     boolean     not null default false,
  updated_at  timestamptz not null default now(),
  primary key (collection, id)
);

create index if not exists app_records_collection_idx
  on public.app_records (collection, updated_at);

-- The app runs without login for most roles, so allow the anon key.
alter table public.app_records enable row level security;
drop policy if exists "app_records read/write" on public.app_records;
create policy "app_records read/write" on public.app_records
  for all to anon, authenticated
  using (true) with check (true);

-- Live updates across devices
alter table public.app_records replica identity full;
do $$
begin
  alter publication supabase_realtime add table public.app_records;
exception when duplicate_object then null;
end $$;

notify pgrst, 'reload schema';
