-- IZORA second migration: security boundaries, private assets, admin bootstrap and indexes.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_super_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists(select 1 from public.profiles p where p.id=(select auth.uid()) and p.role='super_admin'); $$;
revoke all on function private.is_super_admin() from public, anon;
grant execute on function private.is_super_admin() to authenticated;

create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
 insert into public.profiles(id,display_name)
 values(new.id,coalesce(new.raw_user_meta_data ->> 'display_name',''));
 return new;
end;
$$;
revoke all on function private.handle_new_user() from public,anon,authenticated;
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure private.handle_new_user();

create table if not exists private.bootstrap_state(
 id smallint primary key check(id=1),
 completed_at timestamptz,
 completed_by uuid references auth.users(id)
);
insert into private.bootstrap_state(id) values(1) on conflict(id) do nothing;
revoke all on private.bootstrap_state from public,anon,authenticated;

create or replace function private.bootstrap_first_super_admin(p_email text)
returns void language plpgsql security definer set search_path = ''
as $$
declare target_user_id uuid; already_completed timestamptz;
begin
 select completed_at into already_completed from private.bootstrap_state where id=1 for update;
 if already_completed is not null then raise exception 'Initial super-admin bootstrap has already been completed'; end if;
 if exists(select 1 from public.profiles where role='super_admin') then raise exception 'A super-admin already exists'; end if;
 select id into target_user_id from auth.users where lower(email)=lower(trim(p_email)) limit 1;
 if target_user_id is null then raise exception 'No registered account found for that email'; end if;
 update public.profiles set role='super_admin',updated_at=now() where id=target_user_id;
 if not found then raise exception 'The user profile is not ready yet'; end if;
 update private.bootstrap_state set completed_at=now(),completed_by=target_user_id where id=1;
end;
$$;
revoke all on function private.bootstrap_first_super_admin(text) from public,anon,authenticated,service_role;

-- Enforce least privilege on user-editable profile columns.
drop policy if exists "users update own profile" on public.profiles;
create policy "users update own profile" on public.profiles for update to authenticated
using(id=(select auth.uid())) with check(id=(select auth.uid()) and role='user');
drop policy if exists "super admins manage profiles" on public.profiles;
create policy "super admins manage profiles" on public.profiles for all to authenticated
using(private.is_super_admin()) with check(private.is_super_admin());

-- Elevated moderation rights are always checked inside PostgreSQL.
drop policy if exists "super admins manage media" on public.media;
create policy "super admins manage media" on public.media for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());
drop policy if exists "super admins manage categories" on public.media_categories;
create policy "super admins manage categories" on public.media_categories for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());
drop policy if exists "super admins manage portfolio" on public.portfolio_items;
create policy "super admins manage portfolio" on public.portfolio_items for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());
drop policy if exists "super admins manage comments" on public.comments;
create policy "super admins manage comments" on public.comments for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());
drop policy if exists "super admins manage reports" on public.reports;
create policy "super admins manage reports" on public.reports for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());
drop policy if exists "super admins read audit logs" on public.audit_logs;
create policy "super admins read audit logs" on public.audit_logs for select to authenticated using(private.is_super_admin());
drop policy if exists "super admins manage quotas" on public.storage_quotas;
create policy "super admins manage quotas" on public.storage_quotas for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());
drop policy if exists "super admins manage notifications" on public.notifications;
create policy "super admins manage notifications" on public.notifications for all to authenticated using(private.is_super_admin()) with check(private.is_super_admin());

-- Restrict comment visibility and creation to public work, the author, or moderators.
drop policy if exists "comments visible when not hidden or own" on public.comments;
drop policy if exists "comments visible on public work" on public.comments;
create policy "comments visible on public work" on public.comments for select to anon,authenticated
using(author_id=(select auth.uid()) or private.is_super_admin() or
 (not is_hidden and exists(select 1 from public.portfolio_items p join public.media m on m.id=p.media_id
 where p.id=portfolio_id and p.status='published' and m.status='approved' and m.deleted_at is null)));
drop policy if exists "write comments as self" on public.comments;
drop policy if exists "write comments on public work" on public.comments;
create policy "write comments on public work" on public.comments for insert to authenticated
with check(author_id=(select auth.uid()) and exists(
 select 1 from public.portfolio_items p join public.media m on m.id=p.media_id
 where p.id=portfolio_id and p.status='published' and m.status='approved' and m.deleted_at is null));
create policy "media owners moderate work comments" on public.comments for update to authenticated
using(exists(select 1 from public.portfolio_items p join public.media m on m.id=p.media_id where p.id=portfolio_id and m.owner_user_id=(select auth.uid())))
with check(exists(select 1 from public.portfolio_items p join public.media m on m.id=p.media_id where p.id=portfolio_id and m.owner_user_id=(select auth.uid())));
create policy "media owners delete work comments" on public.comments for delete to authenticated
using(exists(select 1 from public.portfolio_items p join public.media m on m.id=p.media_id where p.id=portfolio_id and m.owner_user_id=(select auth.uid())));

-- Explicit API grants used by RLS-protected application operations.
grant insert on public.media to authenticated;
grant insert,update,delete on public.media_categories,public.portfolio_items to authenticated;
grant update,delete on public.comments to authenticated;
grant insert,update,delete on public.notifications to authenticated;

-- Correct composite FK behavior: deleting a category must not null media_id.
alter table public.portfolio_items drop constraint if exists portfolio_category_same_tenant;
alter table public.portfolio_items add constraint portfolio_category_same_tenant
foreign key(category_id,media_id) references public.media_categories(id,media_id)
on delete set null (category_id);

-- Private object storage, scoped to the owning media's UUID folder.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('izora-media','izora-media',false,20971520,array['image/jpeg','image/png','image/webp','image/avif','video/mp4','video/webm'])
on conflict(id) do nothing;
create policy "media owners upload to own folder" on storage.objects for insert to authenticated
with check(bucket_id='izora-media' and exists(select 1 from public.media m where m.id::text=(storage.foldername(name))[1] and m.owner_user_id=(select auth.uid()) and m.status='approved' and m.deleted_at is null));
create policy "media owners read own files" on storage.objects for select to authenticated
using(bucket_id='izora-media' and exists(select 1 from public.media m where m.id::text=(storage.foldername(name))[1] and m.owner_user_id=(select auth.uid())));
create policy "media owners update own files" on storage.objects for update to authenticated
using(bucket_id='izora-media' and exists(select 1 from public.media m where m.id::text=(storage.foldername(name))[1] and m.owner_user_id=(select auth.uid())))
with check(bucket_id='izora-media' and exists(select 1 from public.media m where m.id::text=(storage.foldername(name))[1] and m.owner_user_id=(select auth.uid())));
create policy "media owners delete own files" on storage.objects for delete to authenticated
using(bucket_id='izora-media' and exists(select 1 from public.media m where m.id::text=(storage.foldername(name))[1] and m.owner_user_id=(select auth.uid())));
create policy "super admins manage izora files" on storage.objects for all to authenticated
using(bucket_id='izora-media' and private.is_super_admin()) with check(bucket_id='izora-media' and private.is_super_admin());

-- Foreign-key indexes and query indexes for initial traffic patterns.
create index if not exists audit_logs_actor_id_idx on public.audit_logs(actor_id);
create index if not exists comments_author_id_idx on public.comments(author_id);
create index if not exists comments_parent_id_idx on public.comments(parent_id);
create index if not exists media_follows_media_id_idx on public.media_follows(media_id);
create index if not exists media_ratings_media_id_idx on public.media_ratings(media_id);
create index if not exists portfolio_items_category_media_idx on public.portfolio_items(category_id,media_id);
create index if not exists portfolio_likes_portfolio_id_idx on public.portfolio_likes(portfolio_id);
create index if not exists reports_media_id_idx on public.reports(media_id);
create index if not exists reports_portfolio_id_idx on public.reports(portfolio_id);
create index if not exists reports_reporter_id_idx on public.reports(reporter_id);
create index if not exists saved_media_media_id_idx on public.saved_media(media_id);
create index if not exists saved_portfolio_items_portfolio_id_idx on public.saved_portfolio_items(portfolio_id);
