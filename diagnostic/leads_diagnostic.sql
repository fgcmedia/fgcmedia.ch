create table public.leads_diagnostic (
  id uuid not null default gen_random_uuid (),
  created_at timestamp with time zone not null default now(),
  nom text not null,
  email text not null,
  entreprise text null,
  site text null,
  secteur text null,
  taille text null,
  ca text null,
  score integer null,
  palier text null,
  score_sops integer null,
  score_auto integer null,
  reponses jsonb not null,
  rapport_genere text null,
  statut text null default 'nouveau'::text,
  constraint leads_diagnostic_pkey primary key (id)
) TABLESPACE pg_default;

create index IF not exists idx_leads_score on public.leads_diagnostic using btree (score desc) TABLESPACE pg_default;

create index IF not exists idx_leads_created on public.leads_diagnostic using btree (created_at desc) TABLESPACE pg_default;