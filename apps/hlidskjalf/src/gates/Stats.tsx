import { useState } from 'react';
import { useYmir } from '../state/store';
import { MetricTile } from '../components/MetricTile';

const pct = (n: number | null | undefined) => (n == null ? '—' : `${(n * 100).toFixed(1)}%`);
const M = (n: number | null | undefined) => `${((n ?? 0) / 1_000_000).toFixed(3)}M`;
/** A cost is money when it is a number, "not priced" when it is not — never $0.0000 by accident. */
const usd = (n: number | null | undefined) => (n == null ? 'not priced' : `$${n.toFixed(4)}`);
const usd2 = (n: number | null | undefined) => (n == null ? '—' : `$${n.toFixed(2)}`);

/** Stats — what EVERY harness spent, with one meaning per number (plan 275 item 29).
 *
 * The page it replaces said Runs 61,103 / 100 % success (every MESSAGE counted as a
 * successful RUN, failures never read), Online cost $0.0000 beside Actual cost $82.00
 * (two tables pricing the same tokens), Cache read 16,478M "against" 310M total (two
 * different quantities in one sentence), "local (pi, LM Studio, Ollama)" (LM Studio is
 * retired; pi is a harness, not a place a model runs), Local calls = Local sessions (one
 * number printed twice), By chain rows that were harnesses without models, and By
 * workflow rows that were model names. Each of those is answered below by ONE meaning.
 * Claude Code, Codex and Hermes are read from their own stores; a harness that has no
 * usage store says so instead of reporting zero.
 */
export function Stats() {
  const stats = useYmir((s) => s.smidjaStats);
  const [selectedModel, setSelectedModel] = useState('');
  const harnessUsage = useYmir((st) => st.usage);

  const harness = harnessUsage?.gate ?? null;

  const totals = harness?.totals ?? stats?.totals ?? { runs: 0, success: 0, fail: 0, running: 0, tokens: 0, cost: 0 };
  const usage = harness?.usage ?? stats?.usage ?? { input: 0, output: 0, cache_read: 0, cache_write: 0, total: 0 };
  const providers = harness?.providers ?? stats?.providers ?? {
    local: { events: 0, sessions: 0, tokens: 0, cost: 0, input: 0, output: 0, cache_read: 0 },
    online: { events: 0, sessions: 0, tokens: 0, cost: 0, input: 0, output: 0, cache_read: 0 },
    per_model: [],
  };
  const catalog = stats?.vendor_catalog ?? [];
  const byChain = harness?.by_harness ?? harness?.by_chain ?? stats?.by_chain ?? [];
  const byModel = harness?.by_model ?? stats?.by_model ?? [];
  const chosen =
    catalog.find((m) => m.id === selectedModel) ?? catalog[0] ?? null;

  // A RUN is a session. Failure is "not recorded" where no harness states one, and it
  // is said that way — counting every message as a success is what the old page did.
  const sessions = totals.runs ?? 0;
  const messages = harness?.totals?.messages ?? harnessUsage?.totals?.messages ?? 0;
  const successRate =
    totals.success == null || !sessions ? '—' : pct(totals.success / sessions);
  const providerShare = (kind: 'local' | 'online') => {
    const total = (providers.local.tokens ?? 0) + (providers.online.tokens ?? 0);
    return total ? pct((providers[kind].tokens ?? 0) / total) : '—';
  };

  // THE COMMERCIAL COMPARISON, computed from the totals that exist (it used to receive
  // nothing and print $0.00). `input` is the uncached prompt, `cache_read` the cached
  // part, `output` the completion — each priced at the vendor's own rate.
  const vendorCost = (() => {
    if (!chosen) return null;
    const uncached = (usage.input / 1_000_000) * chosen.input_price;
    const cached = (usage.cache_read / 1_000_000) * chosen.cache_price;
    const outTok = (usage.output / 1_000_000) * chosen.output_price;
    const total = uncached + cached + outTok;
    const actual = typeof totals.cost === 'number' ? totals.cost : null;
    const savings = actual == null ? null : total - actual;
    return {
      uncached,
      cached,
      out: outTok,
      total,
      savings,
      savingsPct: savings != null && total > 0 ? savings / total : null,
    };
  })();

  const sources = harnessUsage?.sources ?? {};

  const tierGroups = [1, 2, 3].map((t) => ({
    label: catalog.find((m) => m.tier === t)?.tier_label ?? `Tier ${t}`,
    models: catalog.filter((m) => m.tier === t),
  }));

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">Statistics</h1>
          <p className="stage-deck">
            Every harness on this machine — opencode · pi · Claude Code · Codex · Hermes · tokens, cost,
            cache, and where each number came from
          </p>
        </div>
      </div>

      {harnessUsage && (
        <section className="panel" style={{ marginTop: 12, padding: 12 }}>
          <h2 style={{ fontSize: 13, opacity: 0.8, margin: '0 0 6px' }}>
            Harnesses · {sessions.toLocaleString()} sessions · {messages.toLocaleString()} messages · last{' '}
            {harnessUsage.window_days} days
          </h2>
          <p className="pf-line dim" style={{ margin: '0 0 8px' }}>
            a <b>run</b> is a session (or an errand) · a <b>message</b> is one exchange ·{' '}
            {(usage.input / 1e6).toFixed(1)}M uncached in / {(usage.output / 1e6).toFixed(1)}M out ·
            cache reads {(usage.cache_read / 1e6).toFixed(1)}M ({(pct(usage.cache_hit_ratio ?? harnessUsage.totals.cache_hit_ratio)).replace('—', '0.0%')} of every prompt sent)
          </p>
          <table className="pf-table">
            <thead>
              <tr>
                <th>Harness</th>
                <th>Sessions</th>
                <th>Messages</th>
                <th>Uncached in</th>
                <th>Out</th>
                <th>Cost</th>
                <th>Read from</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(sources).map(([name, s]) => (
                <tr key={name}>
                  <td className="mono">{name}</td>
                  <td className="num">{s.ok ? (s.sessions ?? 0).toLocaleString() : '—'}</td>
                  <td className="num">{s.ok ? (s.messages ?? 0).toLocaleString() : '—'}</td>
                  <td className="num">{s.ok ? M(s.input) : '—'}</td>
                  <td className="num">{s.ok ? M(s.output) : '—'}</td>
                  <td className="num">
                    {s.ok ? ((s.input ?? 0) + (s.output ?? 0) === 0 ? 'no usage' : 'per model below') : '—'}
                  </td>
                  <td className="muted" style={{ fontSize: 11 }}>
                    {s.ok ? 'its own session store' : s.skip || s.error || 'not read'}
                  </td>
                </tr>
              ))}
              {Object.keys(sources).length === 0 && (
                <tr>
                  <td colSpan={7} style={{ padding: 6, opacity: 0.6 }}>
                    no harness usage in the window
                  </td>
                </tr>
              )}
            </tbody>
          </table>
          <table className="pf-table" style={{ marginTop: 10 }}>
            <thead>
              <tr>
                <th>Model</th>
                <th>Harness</th>
                <th>Where</th>
                <th>Sessions</th>
                <th>Messages</th>
                <th>In</th>
                <th>Out</th>
                <th>Cost</th>
              </tr>
            </thead>
            <tbody>
              {(harnessUsage.by_model ?? []).slice(0, 12).map((m) => (
                <tr key={m.source + m.model}>
                  <td className="mono">{m.model}</td>
                  <td>{m.harness ?? m.source}</td>
                  <td>
                    <span className={`badge ${m.kind ?? 'online'}`}>{m.kind ?? 'online'}</span>
                  </td>
                  <td className="num">{(m.sessions ?? 0).toLocaleString()}</td>
                  <td className="num">{(m.messages ?? 0).toLocaleString()}</td>
                  <td className="num">{(m.input / 1e6).toFixed(1)}M</td>
                  <td className="num">{(m.output / 1e6).toFixed(1)}M</td>
                  <td className="num">{usd(m.cost)}</td>
                </tr>
              ))}
              {(harnessUsage.by_model ?? []).length === 0 && (
                <tr>
                  <td colSpan={8} style={{ padding: 6, opacity: 0.6 }}>
                    no harness usage in the window
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </section>
      )}

      <section className="panel" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛗ</span> Runs and messages
          </div>
        </div>
        <div className="metric-grid">
          <MetricTile label="Sessions (runs)" value={sessions.toLocaleString()} />
          <MetricTile label="Messages" value={messages.toLocaleString()} />
          <MetricTile
            label="Success"
            value={totals.success == null ? 'not recorded' : totals.success}
            tone="var(--ymir-ok)"
          />
          <MetricTile
            label="Fail"
            value={totals.fail == null ? 'not recorded' : totals.fail}
            tone="var(--ymir-danger)"
          />
          <MetricTile label="Success rate" value={successRate} />
          <MetricTile label="Tokens (in + out)" value={totals.tokens.toLocaleString()} />
          <MetricTile label="Cost" value={usd(totals.cost)} tone="var(--ymir-warn)" />
        </div>
        <p className="pf-line dim" style={{ margin: '8px 12px 12px' }}>
          No harness writes a per-session end state we can trust, so success and failure are{' '}
          <b>not recorded</b> rather than assumed. Counting every message as a successful run is
          what produced "61,103 runs · 100 %".
        </p>
      </section>

      <section className="panel" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᚦ</span> Token optimization{' '}
            <span className="dim">(how a prompt is split between new and cached)</span>
          </div>
        </div>
        <div className="metric-grid">
          <MetricTile label="Uncached input" value={M(usage.input)} />
          <MetricTile label="Output" value={M(usage.output)} />
          <MetricTile
            label="Cache read (billed per call)"
            value={M(usage.cache_read)}
            tone="var(--ymir-ok)"
          />
          <MetricTile label="Cache write" value={M(usage.cache_write)} />
          <MetricTile label="Tokens (in + out)" value={M(usage.total)} />
          <MetricTile
            label="Cache share of prompt"
            value={pct(usage.cache_hit_ratio ?? harnessUsage?.totals?.cache_hit_ratio ?? 0)}
            tone="var(--ymir-ok)"
          />
          <MetricTile label="Prompt sent (in + cache)" value={M(usage.prompt ?? usage.input + usage.cache_read)} />
        </div>
        <p className="pf-line dim" style={{ margin: '8px 12px 12px' }}>
          Cache read is summed per call, because that is exactly what a provider bills — every
          turn re-reads the prefix it is given. The ratio is taken against the prompt it belongs
          to (uncached input + cache read), never against input + output, which is a different
          quantity.
        </p>
      </section>

      <section className="panel" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᛋ</span> Where the model ran{' '}
            <span className="dim">(this machine's rail vs a cloud API — decided by the endpoint)</span>
          </div>
        </div>
        <div className="metric-grid">
          <MetricTile label={`Local tokens · ${providerShare('local')}`} value={M(providers.local.tokens)} tone="var(--ymir-ok)" />
          <MetricTile label={`Online tokens · ${providerShare('online')}`} value={M(providers.online.tokens)} tone="var(--ymir-danger)" />
          <MetricTile label="Local calls" value={providers.local.events} tone="var(--ymir-ok)" />
          <MetricTile label="Online calls" value={providers.online.events} tone="var(--ymir-danger)" />
          <MetricTile label="Local cost" value={usd(providers.local.cost)} tone="var(--ymir-ok)" />
          <MetricTile label="Online cost" value={usd(providers.online.cost)} tone="var(--ymir-danger)" />
          <MetricTile label="Local sessions" value={providers.local.sessions} tone="var(--ymir-ok)" />
          <MetricTile label="Online sessions" value={providers.online.sessions} tone="var(--ymir-danger)" />
        </div>
        <div className="split-bar" title={`local ${providerShare('local')} / online ${providerShare('online')}`}>
          <div className="split-local" style={{ width: providerShare('local') }} />
          <div className="split-online" style={{ width: providerShare('online') }} />
        </div>
        <div className="split-legend">
          <span>
            <i className="dot dot-local" /> local — this machine's llama.cpp rail (llama-swap,
            llamacpp seats) — {providerShare('local')}
          </span>
          <span>
            <i className="dot dot-online" /> online — a cloud API — {providerShare('online')}
          </span>
        </div>
        <p className="pf-line dim" style={{ margin: '8px 0 10px' }}>
          A call is one message; a session is one run. They are different counts, so they are
          different tiles.
        </p>
        {providers.per_model.length ? (
          <table className="data-table">
            <thead>
              <tr>
                <th>Model</th>
                <th>Agent</th>
                <th>Harness</th>
                <th>Kind</th>
                <th>Calls</th>
                <th>Sessions</th>
                <th>Tokens</th>
                <th>Cost</th>
              </tr>
            </thead>
            <tbody>
              {providers.per_model.map((m) => (
                <tr key={m.model}>
                  <td className="mono">{m.model}</td>
                  <td className="muted">{m.agent ?? '—'}</td>
                  <td className="muted">{m.harness ?? '—'}</td>
                  <td>
                    <span className={`badge ${m.kind}`}>{m.kind}</span>
                  </td>
                  <td className="num">{m.events}</td>
                  <td className="num">{m.sessions ?? '—'}</td>
                  <td className="num">{M(m.tokens)}</td>
                  <td className="num">{usd(m.cost)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : null}
      </section>

      <section className="panel" style={{ marginBottom: 'var(--ymir-space-4)' }}>
        <div className="panel-head">
          <div className="panel-title">
            <span className="glyph" aria-hidden="true">ᚠ</span> Commercial comparison{' '}
            <span className="dim">(what the tokens above would cost at a vendor's rates)</span>
          </div>
        </div>
        <div className="row" style={{ gap: 10, marginBottom: 12, flexWrap: 'wrap' }}>
          <label className="field" style={{ minWidth: 300 }}>
            <span>Model</span>
            <select id="vendor-model" value={chosen?.id ?? ''} onChange={(e) => setSelectedModel(e.target.value)}>
              {tierGroups.map((g) => (
                <optgroup key={g.label} label={g.label}>
                  {g.models.map((m) => (
                    <option key={m.id} value={m.id}>
                      #{m.rank} {m.name} — {m.provider}
                    </option>
                  ))}
                </optgroup>
              ))}
            </select>
          </label>
          {chosen ? (
            <span className="dim" style={{ fontSize: 12 }}>
              rates: ${chosen.input_price.toFixed(2)} in / ${chosen.cache_price.toFixed(2)} cache / $
              {chosen.output_price.toFixed(2)} out per 1M
            </span>
          ) : null}
        </div>
        {chosen && vendorCost ? (
          <table className="data-table">
            <thead>
              <tr>
                <th>Model</th>
                <th>Uncached in</th>
                <th>Cached in</th>
                <th>Output</th>
                <th>Total at list</th>
                <th>Actually paid</th>
                <th>Would save</th>
                <th>Saved</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td>
                  <b>{chosen.name}</b> <span className="dim">· {chosen.provider} · #{chosen.rank}</span>
                </td>
                <td className="num">{usd2(vendorCost.uncached)}</td>
                <td className="num">{usd2(vendorCost.cached)}</td>
                <td className="num">{usd2(vendorCost.out)}</td>
                <td className="num">{usd2(vendorCost.total)}</td>
                <td className="num">{usd2(totals.cost)}</td>
                <td className="num" style={{ color: 'var(--ymir-ok)' }}>
                  {vendorCost.savings == null ? '—' : usd2(vendorCost.savings)}
                </td>
                <td className="num" style={{ color: 'var(--ymir-ok)' }}>
                  {pct(vendorCost.savingsPct)}
                </td>
              </tr>
            </tbody>
          </table>
        ) : (
          <div className="muted" style={{ padding: 12 }}>
            no vendor catalogue yet
          </div>
        )}
      </section>

      <div className="gate-grid cols-2">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛚ</span> By harness
            </div>
          </div>
          <div className="panel-body flush">
            {byChain.length ? (
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Harness</th>
                    <th>Sessions</th>
                    <th>Messages</th>
                    <th>Tokens</th>
                    <th>Cost</th>
                  </tr>
                </thead>
                <tbody>
                  {byChain.map((c, i) => (
                    <tr key={`${c.source ?? c.chain}-${i}`}>
                      <td className="mono">{c.source ?? c.chain}</td>
                      <td className="num">{c.runs?.toLocaleString?.() ?? c.runs}</td>
                      <td className="num">{c.messages?.toLocaleString?.() ?? c.messages ?? '—'}</td>
                      <td className="num">{c.tokens.toLocaleString()}</td>
                      <td className="num">{usd(c.cost)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <div className="muted" style={{ padding: 12 }}>
                No harness usage in the window.
              </div>
            )}
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᛗ</span> By model
            </div>
          </div>
          <div className="panel-body flush">
            {byModel.length ? (
              <table className="data-table">
                <thead>
                  <tr>
                    <th>Model</th>
                    <th>Harness</th>
                    <th>Sessions</th>
                    <th>Tokens</th>
                    <th>Cost</th>
                  </tr>
                </thead>
                <tbody>
                  {byModel.map((m) => (
                    <tr key={m.workflow ?? m.model}>
                      <td className="mono">{m.workflow ?? m.model}</td>
                      <td className="muted">{m.source ?? m.agent ?? '—'}</td>
                      <td className="num">{m.runs?.toLocaleString?.() ?? m.runs}</td>
                      <td className="num">{m.tokens.toLocaleString()}</td>
                      <td className="num">{usd(m.cost)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            ) : (
              <div className="muted" style={{ padding: 12 }}>
                No usage in the window.
              </div>
            )}
          </div>
        </section>
      </div>
    </>
  );
}
