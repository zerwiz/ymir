-- Ymir platform schema (W0040). Postgres 16.
-- The files remain the raw record; this is the queryable mirror the gate API
-- reads. Realm isolation is enforced by RLS on every tenant table.

CREATE TABLE IF NOT EXISTS realms (
  id          TEXT PRIMARY KEY,               -- one row per tenant
  tenant      TEXT NOT NULL,
  house       TEXT NOT NULL,
  tint        TEXT,
  status      TEXT NOT NULL DEFAULT 'active',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS users (
  id          BIGSERIAL PRIMARY KEY,
  realm       TEXT NOT NULL REFERENCES realms(id) ON DELETE CASCADE,
  login       TEXT NOT NULL,
  name        TEXT,
  email       TEXT,
  role        TEXT NOT NULL DEFAULT 'member', -- owner | admin | member
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (realm, login)
);

CREATE TABLE IF NOT EXISTS companies (       -- plan 21 entity registry
  id          BIGSERIAL PRIMARY KEY,
  realm       TEXT NOT NULL REFERENCES realms(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  type        TEXT NOT NULL DEFAULT 'company',-- company | personal
  house       TEXT,
  owner       TEXT,
  lore_line   TEXT,
  status      TEXT NOT NULL DEFAULT 'active',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (realm, name)
);

CREATE TABLE IF NOT EXISTS projects (
  id          BIGSERIAL PRIMARY KEY,
  realm       TEXT NOT NULL REFERENCES realms(id) ON DELETE CASCADE,
  company_id  BIGINT REFERENCES companies(id) ON DELETE SET NULL,
  name        TEXT NOT NULL,
  repo        TEXT,
  posture     TEXT NOT NULL DEFAULT 'direct-PR', -- no-mistakes | direct-PR | local-only
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (realm, name)
);

CREATE TABLE IF NOT EXISTS agent_cards (
  id          TEXT PRIMARY KEY,
  realm       TEXT NOT NULL REFERENCES realms(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  role        TEXT NOT NULL,
  capabilities JSONB NOT NULL DEFAULT '[]',
  model       TEXT,
  card_json   JSONB,                          -- the signed Agent Card
  jws         TEXT,                           -- Heimdall signature
  status      TEXT NOT NULL DEFAULT 'nominal',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tasks (
  id          TEXT PRIMARY KEY,               -- A2A task id
  realm       TEXT NOT NULL REFERENCES realms(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  state       TEXT NOT NULL DEFAULT 'SUBMITTED',
  agent       TEXT,
  company_id  BIGINT REFERENCES companies(id) ON DELETE SET NULL,
  worktree    TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS runs (
  id          TEXT PRIMARY KEY,               -- factory_id
  realm       TEXT NOT NULL REFERENCES realms(id) ON DELETE CASCADE,
  request     TEXT,
  status      TEXT NOT NULL DEFAULT 'running',
  engineer    TEXT,
  total_tokens INTEGER DEFAULT 0,
  total_cost  REAL DEFAULT 0,
  started_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at    TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS rune_entries (
  id          BIGSERIAL PRIMARY KEY,
  realm       TEXT NOT NULL REFERENCES realms(id) ON DELETE CASCADE,
  ts          TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor       TEXT,
  order_id    TEXT,
  event       TEXT NOT NULL,
  message     TEXT,
  prev_hash   TEXT,
  checksum    TEXT NOT NULL,
  UNIQUE (checksum)
);

CREATE INDEX IF NOT EXISTS idx_tasks_realm_state ON tasks (realm, state);
CREATE INDEX IF NOT EXISTS idx_rune_entries_realm_ts ON rune_entries (realm, ts DESC);

-- Row-Level Security: a session must set app.realm; rows of other realms are invisible.
ALTER TABLE tasks        ENABLE ROW LEVEL SECURITY;
ALTER TABLE runs         ENABLE ROW LEVEL SECURITY;
ALTER TABLE rune_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE companies    ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects     ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY['tasks','runs','rune_entries','companies','projects']) LOOP
    EXECUTE format('DROP POLICY IF EXISTS realm_isolation ON %I;', t);
    EXECUTE format(
      'CREATE POLICY realm_isolation ON %I USING (realm = current_setting(''app.realm'', true));', t);
  END LOOP;
END $$;
