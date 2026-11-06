-- Separate anonymous and authenticated comment visibility so anonymous reads never call private admin helpers.
drop policy if exists "comments visible on public work" on public.comments;
create policy "public comments visible on published work" on public.comments
for select to anon
using (
  not is_hidden and exists (
    select 1 from public.portfolio_items p
    join public.media m on m.id=p.media_id
    where p.id=portfolio_id and p.status='published' and m.status='approved' and m.deleted_at is null
  )
);
create policy "authenticated comments visible on published work" on public.comments
for select to authenticated
using (
  author_id=(select auth.uid())
  or private.is_super_admin()
  or (
    not is_hidden and exists (
      select 1 from public.portfolio_items p
      join public.media m on m.id=p.media_id
      where p.id=portfolio_id and p.status='published' and m.status='approved' and m.deleted_at is null
    )
  )
);
