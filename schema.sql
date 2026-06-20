-- Perfiles
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  username text unique not null,
  doll_color text default '#C24545',
  streak int default 0,
  last_post_date date,
  created_at timestamptz default now()
);

-- Posts diarios
create table public.posts (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles on delete cascade not null,
  username text not null,
  razon text not null,
  castigo text not null,
  dibujo_trazos jsonb,
  dibujo_descripcion text,
  doll_color text not null,
  dep_count int default 0,
  created_at timestamptz default now(),
  post_date date default current_date,
  unique(user_id, post_date)
);

-- DEPs (velas)
create table public.deps (
  id uuid default gen_random_uuid() primary key,
  post_id uuid references public.posts on delete cascade not null,
  user_id uuid references public.profiles on delete cascade not null,
  created_at timestamptz default now(),
  unique(post_id, user_id)
);

-- Trigger: crear perfil al registrarse
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, username)
  values (new.id, coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1)));
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Trigger: actualizar dep_count automáticamente
create or replace function public.update_dep_count()
returns trigger as $$
begin
  if TG_OP = 'INSERT' then
    update public.posts set dep_count = dep_count + 1 where id = NEW.post_id;
  elsif TG_OP = 'DELETE' then
    update public.posts set dep_count = greatest(0, dep_count - 1) where id = OLD.post_id;
  end if;
  return null;
end;
$$ language plpgsql security definer;

create trigger dep_count_trigger
  after insert or delete on public.deps
  for each row execute procedure public.update_dep_count();

-- Row Level Security
alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.deps enable row level security;

create policy "profiles_select" on public.profiles for select using (true);
create policy "profiles_insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profiles_update" on public.profiles for update using (auth.uid() = id);

create policy "posts_select" on public.posts for select using (true);
create policy "posts_insert" on public.posts for insert with check (auth.uid() = user_id);

create policy "deps_select" on public.deps for select using (true);
create policy "deps_insert" on public.deps for insert with check (auth.uid() = user_id);
create policy "deps_delete" on public.deps for delete using (auth.uid() = user_id);
