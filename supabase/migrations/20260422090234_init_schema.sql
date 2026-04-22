-- ============================================================
-- BEERTRACK — Init schema
-- "Strava for beer" — check-ins, social, gamification
-- ============================================================

-- Extensions

-- ============================================================
-- PROFILES (extension de auth.users)
-- ============================================================
create table public.profiles (
  id           uuid primary key references auth.users (id) on delete cascade,
  username     text unique not null,
  display_name text,
  avatar_url   text,
  bio          text,
  city         text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Trigger : updated_at auto
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

-- Trigger : auto-créer un profil à chaque signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- RLS policies — profiles
create policy "Profiles are viewable by everyone"
  on public.profiles for select using (true);

create policy "Users can update their own profile"
  on public.profiles for update using (auth.uid() = id);

-- ============================================================
-- BREWERIES
-- ============================================================
create table public.breweries (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  country    text,
  city       text,
  website    text,
  logo_url   text,
  created_at timestamptz not null default now()
);

alter table public.breweries enable row level security;

create policy "Breweries are viewable by everyone"
  on public.breweries for select using (true);

create policy "Authenticated users can insert breweries"
  on public.breweries for insert with check (auth.role() = 'authenticated');

-- ============================================================
-- BEERS
-- ============================================================
create type public.beer_style as enum (
  'lager', 'pilsner', 'blonde', 'blanche', 'ipa', 'double_ipa',
  'pale_ale', 'amber', 'red_ale', 'stout', 'porter', 'saison',
  'triple', 'dubbel', 'quadrupel', 'sour', 'gose', 'barleywine',
  'fruit_beer', 'smoked', 'wheat', 'other'
);

create table public.beers (
  id           uuid primary key default gen_random_uuid(),
  brewery_id   uuid references public.breweries (id) on delete set null,
  name         text not null,
  style        public.beer_style not null default 'other',
  abv          numeric(4, 1),   -- ex: 6.5 (%)
  ibu          integer,         -- amertume
  description  text,
  image_url    text,
  created_at   timestamptz not null default now()
);

alter table public.beers enable row level security;

create policy "Beers are viewable by everyone"
  on public.beers for select using (true);

create policy "Authenticated users can insert beers"
  on public.beers for insert with check (auth.role() = 'authenticated');

-- ============================================================
-- CHECK-INS (l'activité centrale — comme une activité Strava)
-- ============================================================
create type public.serving_type as enum ('draft', 'bottle', 'can', 'cask', 'other');

create table public.check_ins (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.profiles (id) on delete cascade,
  beer_id        uuid not null references public.beers (id) on delete restrict,
  rating         numeric(2, 1) check (rating >= 0 and rating <= 5),
  notes          text,
  serving_type   public.serving_type,
  location_name  text,
  lat            double precision,
  lng            double precision,
  photo_url      text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.check_ins enable row level security;

create trigger check_ins_updated_at
  before update on public.check_ins
  for each row execute procedure public.set_updated_at();

create index check_ins_user_id_created_at_idx on public.check_ins (user_id, created_at desc);
create index check_ins_beer_id_idx on public.check_ins (beer_id);

create policy "Check-ins are viewable by everyone"
  on public.check_ins for select using (true);

create policy "Users can insert their own check-ins"
  on public.check_ins for insert with check (auth.uid() = user_id);

create policy "Users can update their own check-ins"
  on public.check_ins for update using (auth.uid() = user_id);

create policy "Users can delete their own check-ins"
  on public.check_ins for delete using (auth.uid() = user_id);

-- ============================================================
-- FOLLOWS (graphe social)
-- ============================================================
create table public.follows (
  follower_id  uuid not null references public.profiles (id) on delete cascade,
  following_id uuid not null references public.profiles (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (follower_id, following_id),
  check (follower_id != following_id)
);

alter table public.follows enable row level security;

create index follows_following_id_idx on public.follows (following_id);

create policy "Follows are viewable by everyone"
  on public.follows for select using (true);

create policy "Users can follow others"
  on public.follows for insert with check (auth.uid() = follower_id);

create policy "Users can unfollow"
  on public.follows for delete using (auth.uid() = follower_id);

-- ============================================================
-- KUDOS (équivalent Strava kudos)
-- ============================================================
create table public.kudos (
  user_id      uuid not null references public.profiles (id) on delete cascade,
  check_in_id  uuid not null references public.check_ins (id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (user_id, check_in_id)
);

alter table public.kudos enable row level security;

create index kudos_check_in_id_idx on public.kudos (check_in_id);

create policy "Kudos are viewable by everyone"
  on public.kudos for select using (true);

create policy "Users can give kudos"
  on public.kudos for insert with check (auth.uid() = user_id);

create policy "Users can remove their kudos"
  on public.kudos for delete using (auth.uid() = user_id);

-- ============================================================
-- COMMENTS
-- ============================================================
create table public.comments (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references public.profiles (id) on delete cascade,
  check_in_id  uuid not null references public.check_ins (id) on delete cascade,
  body         text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.comments enable row level security;

create trigger comments_updated_at
  before update on public.comments
  for each row execute procedure public.set_updated_at();

create index comments_check_in_id_idx on public.comments (check_in_id);

create policy "Comments are viewable by everyone"
  on public.comments for select using (true);

create policy "Users can insert their own comments"
  on public.comments for insert with check (auth.uid() = user_id);

create policy "Users can update their own comments"
  on public.comments for update using (auth.uid() = user_id);

create policy "Users can delete their own comments"
  on public.comments for delete using (auth.uid() = user_id);

-- ============================================================
-- ACHIEVEMENTS (catalogue de badges)
-- ============================================================
create table public.achievements (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  name        text not null,
  description text not null,
  icon        text not null,
  created_at  timestamptz not null default now()
);

alter table public.achievements enable row level security;

create policy "Achievements are viewable by everyone"
  on public.achievements for select using (true);

insert into public.achievements (slug, name, description, icon) values
  ('first_checkin',    'Premier verre !',    'Tu as enregistré ton premier check-in',            '🍺'),
  ('ten_checkins',     'Régulier',           '10 check-ins au compteur',                         '🔟'),
  ('century_club',     'Century Club',       '100 check-ins — bienvenue dans le club',            '💯'),
  ('first_ipa',        'Hop Head',           'Ton premier IPA',                                  '🌿'),
  ('first_stout',      'Dark Side',          'Ton premier Stout',                                '🖤'),
  ('first_sour',       'Acidophile',         'Ton premier Sour',                                 '😬'),
  ('high_abv',         'Dangereux',          'Check-in d''une bière à plus de 10% ABV',          '🔥'),
  ('five_styles',      'Explorateur',        'Tu as goûté 5 styles de bière différents',         '🗺️'),
  ('ten_styles',       'Connaisseur',        '10 styles différents — tu connais ta bière',       '🎓'),
  ('five_breweries',   'Tour de France',     '5 brasseries différentes',                         '🏭'),
  ('fifty_breweries',  'Globetrotter',       '50 brasseries différentes',                        '✈️'),
  ('first_kudos',      'Apprécié',           'Tu as reçu ton premier kudos',                     '👏'),
  ('social_butterfly', 'Liant',              'Tu suis 10 personnes',                             '🦋'),
  ('streak_7',         'Semaine parfaite',   '7 jours consécutifs avec au moins un check-in',   '📅'),
  ('perfect_rating',   'Coup de coeur',      'Tu as donné un 5/5 à une bière',                  '⭐');

-- ============================================================
-- USER_ACHIEVEMENTS (badges débloqués)
-- ============================================================
create table public.user_achievements (
  user_id        uuid not null references public.profiles (id) on delete cascade,
  achievement_id uuid not null references public.achievements (id) on delete cascade,
  unlocked_at    timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

alter table public.user_achievements enable row level security;

create policy "User achievements are viewable by everyone"
  on public.user_achievements for select using (true);

create policy "Users can unlock their own achievements"
  on public.user_achievements for insert with check (auth.uid() = user_id);

-- ============================================================
-- VUES STATS
-- ============================================================
create or replace view public.user_stats as
select
  p.id                                        as user_id,
  p.username,
  count(distinct ci.id)                       as total_check_ins,
  count(distinct ci.beer_id)                  as unique_beers,
  count(distinct b.brewery_id)                as unique_breweries,
  count(distinct b.style)                     as unique_styles,
  round(avg(ci.rating)::numeric, 2)           as avg_rating,
  max(b.abv)                                  as max_abv_tried,
  round(avg(b.abv)::numeric, 1)               as avg_abv
from public.profiles p
left join public.check_ins ci on ci.user_id = p.id
left join public.beers b on b.id = ci.beer_id
group by p.id, p.username;

-- Vue feed enrichi
create or replace view public.feed as
select
  ci.id,
  ci.created_at,
  ci.rating,
  ci.notes,
  ci.serving_type,
  ci.location_name,
  ci.lat,
  ci.lng,
  ci.photo_url,
  p.id           as user_id,
  p.username,
  p.display_name,
  p.avatar_url,
  b.id           as beer_id,
  b.name         as beer_name,
  b.style        as beer_style,
  b.abv          as beer_abv,
  b.image_url    as beer_image_url,
  br.id          as brewery_id,
  br.name        as brewery_name,
  (select count(*) from public.kudos k   where k.check_in_id = ci.id) as kudos_count,
  (select count(*) from public.comments c where c.check_in_id = ci.id) as comments_count
from public.check_ins ci
join public.profiles p      on p.id  = ci.user_id
join public.beers b         on b.id  = ci.beer_id
left join public.breweries br on br.id = b.brewery_id
order by ci.created_at desc;
