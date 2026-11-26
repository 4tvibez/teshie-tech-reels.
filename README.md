# TESHIE TECH REELS
A mobile-first short-video community starter with welcome screen, vertical video feed, accounts, upload, likes, sharing, download, tags, discover, following, activity and profile.

## 1. Create the backend (Supabase)
1. Create a free project at https://supabase.com.
2. Open SQL Editor and run all of `supabase/schema.sql`.
3. In Project Settings → API, copy Project URL and anon/public key.
4. Open `index.html` and replace the two empty values near the top of the module:
   `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
   Do not use a service-role key in browser code.
5. In Authentication settings, set your site's URL and allowed redirect URLs. Email confirmation may need to be enabled/disabled in Supabase Auth settings.

## 2. School welcome image
Add your actual school image to the repository root as `school-logo.jpg`. The welcome screen displays it as a round logo. The image previously uploaded in chat is not automatically available to GitHub, so it must be added to this repo.

## 3. Run / deploy
This is a static site: open `index.html` or enable GitHub Pages (Settings → Pages → Deploy from branch → main → /root). It can also be imported into Vercel.

## Included
- Email sign-up / sign-in and session
- Public video feed, upload to Supabase Storage, captions and hashtags
- Like/unlike, share link, download, creator follow, own-video delete
- Discover search, following feed, profile and notification list UI

## Important
This is a first working foundation, not a full TikTok-scale production system. Notifications currently display records in the notifications table; automated event creation, comments, moderation, reporting, video transcoding, private storage/CDN and robust download authorization should be added before a public launch. The browser app requires the Supabase project and SQL setup above before accounts and shared media can work.
