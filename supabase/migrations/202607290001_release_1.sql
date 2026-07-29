begin;

create extension if not exists postgis with schema extensions;
create extension if not exists pg_trgm with schema extensions;

create type public.course_state as enum ('draft', 'published', 'archived');
create type public.profile_visibility as enum ('private', 'community');
create type public.media_visibility as enum ('private', 'connections', 'community', 'unlisted');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9._]{3,24}$'),
  display_name text not null check (char_length(display_name) between 1 and 60),
  biography text not null default '' check (char_length(biography) <= 240),
  broad_location text,
  avatar_path text,
  visibility public.profile_visibility not null default 'community',
  club_stats_public boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.courses (
  id uuid primary key,
  facility_name text not null,
  layout_name text not null,
  city text not null default '',
  postcode text not null default '',
  search_text text generated always as (
    lower(facility_name || ' ' || layout_name || ' ' || city || ' ' || postcode)
  ) stored,
  state public.course_state not null default 'draft',
  current_revision_id uuid,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.course_revisions (
  id uuid primary key,
  course_id uuid not null references public.courses(id) on delete restrict,
  revision_number integer not null check (revision_number > 0),
  hole_count integer not null check (hole_count between 1 and 36),
  total_par integer not null check (total_par between hole_count * 3 and hole_count * 6),
  status public.course_state not null default 'draft',
  change_summary text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  published_at timestamptz,
  unique (course_id, revision_number)
);

alter table public.courses
  add constraint courses_current_revision_fk
  foreign key (current_revision_id) references public.course_revisions(id) on delete restrict;

create table public.course_holes (
  revision_id uuid not null references public.course_revisions(id) on delete cascade,
  hole_number integer not null check (hole_number between 1 and 36),
  par integer not null check (par between 3 and 6),
  tee extensions.geography(point, 4326) not null,
  tee_accuracy_m real check (tee_accuracy_m is null or tee_accuracy_m >= 0),
  tee_captured_at timestamptz,
  green_reference extensions.geography(point, 4326) not null,
  green_accuracy_m real check (green_accuracy_m is null or green_accuracy_m >= 0),
  green_captured_at timestamptz,
  source text not null check (source in ('satellite', 'gps', 'mixed')),
  primary key (revision_id, hole_number)
);

create index courses_search_trgm on public.courses using gin (search_text extensions.gin_trgm_ops);
create index holes_tee_gist on public.course_holes using gist (tee);
create index holes_green_gist on public.course_holes using gist (green_reference);

create table public.home_courses (
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, course_id)
);

create table public.user_clubs (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  display_name text not null,
  nickname text not null default '',
  loft_degrees numeric(4,1),
  status text not null check (status in ('active', 'inventory', 'retired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index user_clubs_max_active_guard on public.user_clubs(user_id, id) where status = 'active';

create or replace function public.enforce_active_bag_limit()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.status = 'active' and (
    select count(*) from public.user_clubs
    where user_id = new.user_id and status = 'active' and id <> new.id
  ) >= 14 then
    raise exception 'An active bag may contain at most 14 clubs';
  end if;
  return new;
end;
$$;

create trigger active_bag_limit before insert or update on public.user_clubs
for each row execute function public.enforce_active_bag_limit();

create table public.range_hits (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  club_id uuid not null references public.user_clubs(id) on delete restrict,
  distance_m numeric(7,2) not null check (distance_m > 0 and distance_m < 500),
  distance_kind text not null check (distance_kind in ('carry', 'total')),
  source text not null check (source in ('manual', 'launch_monitor', 'gps_endpoints', 'imported', 'corrected')),
  shot_intent text not null default 'full' check (shot_intent in ('full', 'partial', 'punch', 'positional')),
  quality text not null default 'normal' check (quality in ('normal', 'mishit', 'invalid')),
  occurred_at timestamptz not null,
  created_at timestamptz not null default now()
);

create table public.rounds (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete restrict,
  course_revision_id uuid not null references public.course_revisions(id) on delete restrict,
  format text not null,
  rules_compliant boolean not null default false,
  state text not null check (state in ('active', 'complete', 'abandoned')),
  current_hole integer not null default 1,
  started_at timestamptz not null,
  completed_at timestamptz,
  updated_at timestamptz not null default now()
);

create table public.shots (
  id uuid primary key,
  round_id uuid not null references public.rounds(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  hole_number integer not null check (hole_number between 1 and 36),
  start_position extensions.geography(point, 4326),
  start_accuracy_m real,
  end_position extensions.geography(point, 4326),
  end_accuracy_m real,
  club_id uuid references public.user_clubs(id) on delete set null,
  result_direction text,
  ball_flight text,
  strike_quality text,
  finishing_lie text,
  relief_procedure text,
  penalty_strokes smallint not null default 0 check (penalty_strokes between 0 and 4),
  created_at timestamptz not null default now()
);

create table public.gallery_items (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  round_id uuid references public.rounds(id) on delete set null,
  shot_id uuid references public.shots(id) on delete set null,
  private_storage_path text not null,
  title text not null default 'Recorded shot',
  tracer_metadata jsonb not null default '{}'::jsonb,
  visibility public.media_visibility not null default 'private',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function public.nearby_courses(
  latitude double precision,
  longitude double precision,
  radius_m integer default 50000,
  result_limit integer default 20
)
returns table (
  id uuid,
  facility_name text,
  layout_name text,
  city text,
  postcode text,
  current_revision_id uuid,
  distance_m double precision
)
language sql stable security invoker set search_path = '' as $$
  with anchors as (
    select c.id, min(
      extensions.st_distance(
        h.tee,
        extensions.st_point(longitude, latitude)::extensions.geography
      )
    ) as distance_m
    from public.courses c
    join public.course_holes h on h.revision_id = c.current_revision_id
    where c.state = 'published'
      and extensions.st_dwithin(
        h.tee,
        extensions.st_point(longitude, latitude)::extensions.geography,
        radius_m
      )
    group by c.id
  )
  select c.id, c.facility_name, c.layout_name, c.city, c.postcode, c.current_revision_id, a.distance_m
  from anchors a join public.courses c on c.id = a.id
  order by a.distance_m, c.layout_name
  limit least(result_limit, 50);
$$;

create or replace function public.search_courses(query text, result_limit integer default 30)
returns setof public.courses
language sql stable security invoker set search_path = '' as $$
  select c from public.courses c
  where c.state = 'published'
    and extensions.similarity(c.search_text, lower(query)) > 0.2
  order by extensions.similarity(c.search_text, lower(query)) desc
  limit least(result_limit, 50);
$$;

alter table public.profiles enable row level security;
alter table public.courses enable row level security;
alter table public.course_revisions enable row level security;
alter table public.course_holes enable row level security;
alter table public.home_courses enable row level security;
alter table public.user_clubs enable row level security;
alter table public.range_hits enable row level security;
alter table public.rounds enable row level security;
alter table public.shots enable row level security;
alter table public.gallery_items enable row level security;

create policy "community profiles readable" on public.profiles for select
using (visibility = 'community' or id = auth.uid());
create policy "profile owner writes" on public.profiles for all
using (id = auth.uid()) with check (id = auth.uid());

create policy "published courses readable" on public.courses for select
using (state = 'published' or created_by = auth.uid());
create policy "authenticated users draft courses" on public.courses for insert
to authenticated with check (created_by = auth.uid() and state = 'draft');
create policy "course author updates drafts" on public.courses for update
to authenticated using (created_by = auth.uid() and state = 'draft')
with check (created_by = auth.uid() and state = 'draft');

create policy "published revisions readable" on public.course_revisions for select
using (status = 'published' or created_by = auth.uid());
create policy "authors create draft revisions" on public.course_revisions for insert
to authenticated with check (created_by = auth.uid() and status = 'draft');
create policy "authors update draft revisions" on public.course_revisions for update
to authenticated using (created_by = auth.uid() and status = 'draft')
with check (created_by = auth.uid() and status = 'draft');

create policy "published holes readable" on public.course_holes for select
using (exists (
  select 1 from public.course_revisions r
  where r.id = revision_id and (r.status = 'published' or r.created_by = auth.uid())
));
create policy "draft holes author write" on public.course_holes for all
to authenticated using (exists (
  select 1 from public.course_revisions r
  where r.id = revision_id and r.status = 'draft' and r.created_by = auth.uid()
)) with check (exists (
  select 1 from public.course_revisions r
  where r.id = revision_id and r.status = 'draft' and r.created_by = auth.uid()
));

create policy "owners manage home courses" on public.home_courses for all
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "owners manage clubs" on public.user_clubs for all
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "owners manage range hits" on public.range_hits for all
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "owners manage rounds" on public.rounds for all
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "owners manage shots" on public.shots for all
using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "owners manage gallery" on public.gallery_items for all
using (user_id = auth.uid()) with check (user_id = auth.uid());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('private-gallery', 'private-gallery', false, 524288000, array['video/quicktime', 'video/mp4', 'image/jpeg', 'image/png'])
on conflict (id) do nothing;

create policy "gallery owner reads objects" on storage.objects for select
to authenticated using (bucket_id = 'private-gallery' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "gallery owner inserts objects" on storage.objects for insert
to authenticated with check (bucket_id = 'private-gallery' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "gallery owner deletes objects" on storage.objects for delete
to authenticated using (bucket_id = 'private-gallery' and (storage.foldername(name))[1] = auth.uid()::text);

commit;
