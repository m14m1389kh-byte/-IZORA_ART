-- IZORA initial schema. All tenant-owned content is scoped by media_id.
create extension if not exists pgcrypto;

create type public.account_role as enum ('user', 'super_admin');
create type public.media_status as enum ('pending', 'approved', 'rejected', 'suspended', 'archived');
create type public.portfolio_status as enum ('draft', 'published', 'hidden');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  role public.account_role not null default 'user',
  preferred_locale text not null default 'fa' check (preferred_locale in ('fa','en')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.media (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null unique references public.profiles(id) on delete restrict,
  name text not null,
  slug text not null unique,
  logo_path text,
  banner_path text,
  bio text not null default '',
  specialties text[] not null default '{}',
  contact_email text,
  contact_links jsonb not null default '[]'::jsonb,
  status public.media_status not null default 'pending',
  is_verified boolean not null default false,
  is_featured boolean not null default false,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint media_slug_format check (slug ~ '^[a-z0-9][a-z0-9-]{1,39}$')
);

create table public.media_categories (
  id uuid primary key default gen_random_uuid(),
  media_id uuid not null references public.media(id) on delete cascade,
  name text not null,
  slug text not null,
  created_at timestamptz not null default now(),
  unique(media_id, slug),
  unique(id, media_id)
);

create table public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  media_id uuid not null references public.media(id) on delete cascade,
  category_id uuid,
  title text not null,
  description text not null default '',
  asset_path text,
  asset_kind text not null default 'image' check (asset_kind in ('image','video','external_video')),
  external_url text,
  tags text[] not null default '{}',
  status public.portfolio_status not null default 'draft',
  view_count bigint not null default 0 check (view_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint portfolio_category_same_tenant foreign key(category_id, media_id)
    references public.media_categories(id, media_id) on delete set null
);

create table public.media_follows (
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_id uuid not null references public.media(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, media_id)
);

create table public.portfolio_likes (
  user_id uuid not null references public.profiles(id) on delete cascade,
  portfolio_id uuid not null references public.portfolio_items(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, portfolio_id)
);

create table public.comments (
  id uuid primary key default gen_random_uuid(),
  portfolio_id uuid not null references public.portfolio_items(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  parent_id uuid references public.comments(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 3000),
  is_hidden boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.media_ratings (
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_id uuid not null references public.media(id) on delete cascade,
  rating smallint not null check (rating between 1 and 5),
  updated_at timestamptz not null default now(),
  primary key(user_id, media_id)
);

create table public.saved_media (
  user_id uuid not null references public.profiles(id) on delete cascade,
  media_id uuid not null references public.media(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, media_id)
);

create table public.saved_portfolio_items (
  user_id uuid not null references public.profiles(id) on delete cascade,
  portfolio_id uuid not null references public.portfolio_items(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, portfolio_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null default '',
  target_path text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  media_id uuid references public.media(id) on delete cascade,
  portfolio_id uuid references public.portfolio_items(id) on delete cascade,
  reason text not null,
  details text not null default '',
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  check (media_id is not null or portfolio_id is not null)
);

create table public.storage_quotas (
  media_id uuid primary key references public.media(id) on delete cascade,
  quota_bytes bigint not null default 1073741824 check (quota_bytes > 0),
  used_bytes bigint not null default 0 check (used_bytes >= 0),
  updated_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index portfolio_media_status_created_idx on public.portfolio_items(media_id, status, created_at desc);
create index comments_portfolio_created_idx on public.comments(portfolio_id, created_at);
create index media_status_created_idx on public.media(status, created_at desc);
create index notifications_recipient_created_idx on public.notifications(recipient_id, created_at desc);

-- Create profile rows for new auth users. The role is always forced to the least-privileged value.
create or replace function public.handle_new_user()
returns trigger language plpgsql security invoker set search_path = ''
as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Enable row-level security on every exposed application table.
alter table public.profiles enable row level security;
alter table public.media enable row level security;
alter table public.media_categories enable row level security;
alter table public.portfolio_items enable row level security;
alter table public.media_follows enable row level security;
alter table public.portfolio_likes enable row level security;
alter table public.comments enable row level security;
alter table public.media_ratings enable row level security;
alter table public.saved_media enable row level security;
alter table public.saved_portfolio_items enable row level security;
alter table public.notifications enable row level security;
alter table public.reports enable row level security;
alter table public.storage_quotas enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles: public identity fields can be read; a user may edit only their own non-role fields.
create policy "profiles are readable" on public.profiles for select to anon, authenticated using (true);
create policy "users insert own profile" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
create policy "users update own profile" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
revoke update on public.profiles from authenticated;
grant update(display_name, avatar_url, preferred_locale, updated_at) on public.profiles to authenticated;

-- Media: approved public profiles are discoverable; owners can see their own pending profile.
create policy "approved media are public" on public.media for select to anon, authenticated using (status = 'approved' and deleted_at is null or owner_user_id = (select auth.uid()));
create policy "users request one media" on public.media for insert to authenticated with check (owner_user_id = (select auth.uid()) and status = 'pending' and is_verified = false and is_featured = false);
create policy "owners update own media profile" on public.media for update to authenticated using (owner_user_id = (select auth.uid())) with check (owner_user_id = (select auth.uid()));
revoke update on public.media from authenticated;
grant update(name, slug, logo_path, banner_path, bio, specialties, contact_email, contact_links, updated_at) on public.media to authenticated;

-- Tenant boundary: categories and work are readable only when published, or by their owning media account.
create policy "categories public or owner" on public.media_categories for select to anon, authenticated using (
  exists(select 1 from public.media m where m.id = media_id and m.status = 'approved' and m.deleted_at is null)
  or exists(select 1 from public.media m where m.id = media_id and m.owner_user_id = (select auth.uid()))
);
create policy "owners manage categories" on public.media_categories for all to authenticated
using (exists(select 1 from public.media m where m.id = media_id and m.owner_user_id = (select auth.uid())))
with check (exists(select 1 from public.media m where m.id = media_id and m.owner_user_id = (select auth.uid())));

create policy "published work public or owner" on public.portfolio_items for select to anon, authenticated using (
  (status = 'published' and exists(select 1 from public.media m where m.id = media_id and m.status = 'approved' and m.deleted_at is null))
  or exists(select 1 from public.media m where m.id = media_id and m.owner_user_id = (select auth.uid()))
);
create policy "owners create work" on public.portfolio_items for insert to authenticated with check (
  exists(select 1 from public.media m where m.id = media_id and m.owner_user_id = (select auth.uid()) and m.status = 'approved')
);
create policy "owners update work" on public.portfolio_items for update to authenticated using (
  exists(select 1 from public.media m where m.id = media_id and m.owner_user_id = (select auth.uid()))
) with check (
  exists(select 1 from public.media m where m.id = media_id and m.owner_user_id = (select auth.uid()))
);
create policy "owners delete work" on public.portfolio_items for delete to authenticated using (
  exists(select 1 from public.media m where m.id = media_id and m.owner_user_id = (select auth.uid()))
);

-- User-owned social actions.
create policy "follows visible to owner" on public.media_follows for select to authenticated using (user_id = (select auth.uid()));
create policy "follow as self" on public.media_follows for insert to authenticated with check (user_id = (select auth.uid()));
create policy "unfollow as self" on public.media_follows for delete to authenticated using (user_id = (select auth.uid()));
create policy "likes readable" on public.portfolio_likes for select to anon, authenticated using (true);
create policy "like as self" on public.portfolio_likes for insert to authenticated with check (user_id = (select auth.uid()));
create policy "unlike as self" on public.portfolio_likes for delete to authenticated using (user_id = (select auth.uid()));
create policy "comments visible when not hidden or own" on public.comments for select to anon, authenticated using (not is_hidden or author_id = (select auth.uid()));
create policy "write comments as self" on public.comments for insert to authenticated with check (author_id = (select auth.uid()));
create policy "edit own comments" on public.comments for update to authenticated using (author_id = (select auth.uid())) with check (author_id = (select auth.uid()));
create policy "delete own comments" on public.comments for delete to authenticated using (author_id = (select auth.uid()));
create policy "ratings public read" on public.media_ratings for select to anon, authenticated using (true);
create policy "rate as self" on public.media_ratings for insert to authenticated with check (user_id = (select auth.uid()));
create policy "change own rating" on public.media_ratings for update to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "remove own rating" on public.media_ratings for delete to authenticated using (user_id = (select auth.uid()));

create policy "saved media private" on public.saved_media for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "saved work private" on public.saved_portfolio_items for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "notifications private" on public.notifications for select to authenticated using (recipient_id = (select auth.uid()));
create policy "reports create as self" on public.reports for insert to authenticated with check (reporter_id = (select auth.uid()));
create policy "reporter reads own reports" on public.reports for select to authenticated using (reporter_id = (select auth.uid()));
create policy "quota visible to media owner" on public.storage_quotas for select to authenticated using (exists(select 1 from public.media m where m.id = media_id and m.owner_user_id = (select auth.uid())));
create policy "audit log private" on public.audit_logs for select to authenticated using (actor_id = (select auth.uid()));

-- Default API grants; RLS remains the row-level authorization boundary.
grant select on public.media, public.media_categories, public.portfolio_items, public.portfolio_likes, public.comments, public.media_ratings to anon, authenticated;
grant select, insert, update, delete on public.media_follows, public.portfolio_likes, public.comments, public.media_ratings, public.saved_media, public.saved_portfolio_items to authenticated;
grant select, insert on public.profiles to authenticated;
grant select, insert on public.reports to authenticated;
grant select on public.notifications, public.storage_quotas, public.audit_logs to authenticated;
grant usage, select on all sequences in schema public to authenticated;
