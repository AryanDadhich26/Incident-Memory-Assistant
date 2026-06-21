create extension if not exists vector;

create table incidents (
  id bigint generated always as identity primary key,
  created_at timestamptz default now(),
  source text,
  alert_summary text,
  embedding vector(384),
  root_cause text,
  resolution_notes text,
  resolved boolean default false
);

create index on incidents using ivfflat (embedding vector_cosine_ops) with (lists = 100);
