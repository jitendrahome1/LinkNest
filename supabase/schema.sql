-- LinkNest — Supabase schema
-- Run this once in the Supabase SQL Editor (or via `supabase db push`)
-- against a fresh project. Row ids come from the iOS app (SwiftData's
-- UUIDs), so no server-side default generator is needed.

-- ============================================================
-- Tables
-- ============================================================

create table if not exists public.collections (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color_hex integer not null,
  sort_index integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.tags (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (user_id, name)
);

create table if not exists public.content_items (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  url text not null,
  title text not null,
  description text not null default '',
  thumbnail_url text,
  thumbnail_hue double precision not null default 230,
  platform text not null default 'other',
  content_type text not null default 'other',
  creator_name text not null default '',
  creator_url text,
  duration text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_viewed_at timestamptz,
  notes text not null default '',
  summary text,
  is_favorite boolean not null default false,
  is_watch_later boolean not null default false,
  is_completed boolean not null default false,
  is_archived boolean not null default false,
  playback_position_seconds double precision not null default 0,
  playback_duration_seconds double precision not null default 0,
  current_page integer not null default 1,
  total_pages integer not null default 0,
  bookmarked_pages integer[] not null default '{}',
  collection_id uuid references public.collections(id) on delete set null
);

create table if not exists public.content_item_tags (
  content_item_id uuid not null references public.content_items(id) on delete cascade,
  tag_id uuid not null references public.tags(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  primary key (content_item_id, tag_id)
);

create index if not exists content_items_user_id_idx on public.content_items(user_id);
create index if not exists content_items_collection_id_idx on public.content_items(collection_id);
create index if not exists collections_user_id_idx on public.collections(user_id);
create index if not exists tags_user_id_idx on public.tags(user_id);
create index if not exists content_item_tags_item_idx on public.content_item_tags(content_item_id);
create index if not exists content_item_tags_tag_idx on public.content_item_tags(tag_id);

-- ============================================================
-- updated_at — server-authoritative on every UPDATE, so
-- last-write-wins merges compare a clock the client can't skew.
-- ============================================================

create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists set_updated_at on public.content_items;
create trigger set_updated_at
  before update on public.content_items
  for each row execute function public.touch_updated_at();

-- ============================================================
-- Row Level Security — every table is owned per-row by user_id;
-- a signed-in user may only ever see or touch their own rows.
-- ============================================================

alter table public.collections enable row level security;
alter table public.tags enable row level security;
alter table public.content_items enable row level security;
alter table public.content_item_tags enable row level security;

drop policy if exists "own collections" on public.collections;
create policy "own collections" on public.collections
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own tags" on public.tags;
create policy "own tags" on public.tags
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own content items" on public.content_items;
create policy "own content items" on public.content_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own content item tags" on public.content_item_tags;
create policy "own content item tags" on public.content_item_tags
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ============================================================
-- Realtime — required for the app's live cross-device sync.
-- Adds each table only if it isn't already published, so this
-- whole script is safe to run more than once.
-- ============================================================

do $$
declare
  t text;
begin
  foreach t in array array['content_items', 'collections', 'tags', 'content_item_tags']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
