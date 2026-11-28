-- Teshie Tech Reels database schema (Supabase SQL Editor)
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique,
 display_name text,
 bio text default '',
 avatar_url text,
 created_at timestamptz default now()
);
create table if not exists public.videos (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 video_url text not null,
 caption text default '',
 tags text[] default '{}',
 created_at timestamptz default now()
);
create table if not exists public.likes (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id) on delete cascade,
 video_id uuid not null references public.videos(id) on delete cascade,
 created_at timestamptz default now(),
 unique(user_id,video_id)
);
create table if not exists public.follows (
 follower_id uuid references public.profiles(id) on delete cascade,
 following_id uuid references public.profiles(id) on delete cascade,
 created_at timestamptz default now(),
 primary key(follower_id,following_id),
 check(follower_id <> following_id)
);
create table if not exists public.notifications (
 id uuid primary key default gen_random_uuid(),
 recipient_id uuid references public.profiles(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete cascade,
 message text not null,
 created_at timestamptz default now()
);
alter table public.profiles enable row level security;
alter table public.videos enable row level security;
alter table public.likes enable row level security;
alter table public.follows enable row level security;
alter table public.notifications enable row level security;
create policy "profiles readable" on public.profiles for select using(true);
create policy "profile self insert" on public.profiles for insert with check(auth.uid()=id);
create policy "profile self update" on public.profiles for update using(auth.uid()=id);
create policy "videos readable" on public.videos for select using(true);
create policy "users publish own videos" on public.videos for insert with check(auth.uid()=user_id);
create policy "users delete own videos" on public.videos for delete using(auth.uid()=user_id);
create policy "likes readable" on public.likes for select using(true);
create policy "manage own likes" on public.likes for all using(auth.uid()=user_id) with check(auth.uid()=user_id);
create policy "follows readable" on public.follows for select using(true);
create policy "manage own follows" on public.follows for all using(auth.uid()=follower_id) with check(auth.uid()=follower_id);
create policy "read own notifications" on public.notifications for select using(auth.uid()=recipient_id);
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,username,display_name)
 values(new.id, lower(regexp_replace(coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)),'[^a-zA-Z0-9_]','','g')) || '_' || substr(new.id::text,1,5), coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1)));
 return new;
end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('reels','reels',true,104857600,array['video/mp4','video/webm','video/quicktime']) on conflict(id) do nothing;
create policy "public read reels" on storage.objects for select using(bucket_id='reels');
create policy "authenticated upload reels" on storage.objects for insert to authenticated with check(bucket_id='reels' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "owner delete reels" on storage.objects for delete to authenticated using(bucket_id='reels' and (storage.foldername(name))[1]=auth.uid()::text);


-- Video comments
create table if not exists public.comments (
 id uuid primary key default gen_random_uuid(),
 video_id uuid not null references public.videos(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 content text not null check (char_length(trim(content)) between 1 and 500),
 created_at timestamptz default now()
);
create index if not exists comments_video_created_idx on public.comments(video_id, created_at);
alter table public.comments enable row level security;
drop policy if exists "comments readable" on public.comments;
create policy "comments readable" on public.comments for select using(true);
drop policy if exists "users post own comments" on public.comments;
create policy "users post own comments" on public.comments for insert to authenticated with check(auth.uid()=user_id);
drop policy if exists "users delete own comments" on public.comments;
create policy "users delete own comments" on public.comments for delete to authenticated using(auth.uid()=user_id);


-- Profile photos and creator logos
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('avatars','avatars',true,5242880,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict(id) do update set
 public=true,
 file_size_limit=5242880,
 allowed_mime_types=array['image/jpeg','image/png','image/webp','image/gif'];

drop policy if exists "public read avatars" on storage.objects;
create policy "public read avatars" on storage.objects
for select using(bucket_id='avatars');

drop policy if exists "users upload own avatar" on storage.objects;
create policy "users upload own avatar" on storage.objects
for insert to authenticated
with check(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "users update own avatar" on storage.objects;
create policy "users update own avatar" on storage.objects
for update to authenticated
using(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text)
with check(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "users delete own avatar" on storage.objects;
create policy "users delete own avatar" on storage.objects
for delete to authenticated
using(bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);


-- Threaded comment replies
alter table public.comments
 add column if not exists parent_comment_id uuid
 references public.comments(id) on delete cascade;

create index if not exists comments_parent_created_idx
 on public.comments(parent_comment_id, created_at);

create or replace function public.notify_comment_reply()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
 parent_author uuid;
 parent_video uuid;
begin
 if new.parent_comment_id is null then
  return new;
 end if;

 select user_id, video_id
 into parent_author, parent_video
 from public.comments
 where id = new.parent_comment_id;

 if parent_author is not null
    and parent_video = new.video_id
    and parent_author <> new.user_id then
  insert into public.notifications(recipient_id, actor_id, message)
  values(
   parent_author,
   new.user_id,
   'replied to your comment: "' || left(new.content, 300) || '" 💬'
  );
 end if;
 return new;
end;
$$;

drop trigger if exists on_comment_reply_created on public.comments;
create trigger on_comment_reply_created
 after insert on public.comments
 for each row execute function public.notify_comment_reply();
