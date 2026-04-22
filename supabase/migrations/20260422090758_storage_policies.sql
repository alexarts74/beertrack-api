-- ============================================================
-- STORAGE POLICIES
-- Buckets : avatars (public), check-in-photos (public + RLS)
-- ============================================================

-- AVATARS — lecture publique, upload/update/delete par le propriétaire
create policy "Avatars are publicly accessible"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "Users can upload their own avatar"
  on storage.objects for insert
  with check (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can update their own avatar"
  on storage.objects for update
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete their own avatar"
  on storage.objects for delete
  using (
    bucket_id = 'avatars'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- CHECK-IN-PHOTOS — lecture publique, upload/update/delete par le propriétaire
create policy "Check-in photos are publicly accessible"
  on storage.objects for select
  using (bucket_id = 'check-in-photos');

create policy "Users can upload their own check-in photos"
  on storage.objects for insert
  with check (
    bucket_id = 'check-in-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can update their own check-in photos"
  on storage.objects for update
  using (
    bucket_id = 'check-in-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "Users can delete their own check-in photos"
  on storage.objects for delete
  using (
    bucket_id = 'check-in-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );
