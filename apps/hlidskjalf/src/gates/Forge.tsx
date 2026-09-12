import { useEffect, useMemo, useState } from 'react';
import { useYmir } from '../state/store';
import { useUI } from '../state/ui';
import { DOMAINS } from '../data/realms';
import { AETTS_LIST, aettFor, suggestFigures } from '../data/mythology';
import { StatusChip } from '../components/Status';
import { RuneTag } from '../components/RuneTag';
import { ModelPicker } from '../components/ModelPicker';
import { gateApi, type PromptFile } from '../services/api';
import type { AgentCard as AgentCardType, DomainId, SkillDef } from '../types';

type Mode = 'agent' | 'skill' | 'prompt';

const DOMAINS_LIST = Object.keys(DOMAINS) as DomainId[];

function slug(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
}

interface AgentDraft {
  id?: string;
  name: string;
  role: string;
  capabilities: string;
  domain: DomainId;
  model: string;
}

const EMPTY_AGENT: AgentDraft = {
  name: '',
  role: '',
  capabilities: '',
  domain: 'brokkforge',
  model: 'opencode-go/deepseek-v4-flash',
};

export function Forge() {
  const agents = useYmir((s) => s.agents);
  const skills = useYmir((s) => s.skills);
  const realm = useYmir((s) => s.realm);
  const addAgent = useYmir((s) => s.addAgent);
  const updateAgent = useYmir((s) => s.updateAgent);
  const addSkill = useYmir((s) => s.addSkill);
  const updateSkill = useYmir((s) => s.updateSkill);
  const pushStream = useYmir((s) => s.pushStream);
  const { toast } = useUI();

  const [mode, setMode] = useState<Mode>('agent');
  const [agent, setAgent] = useState<AgentDraft>(EMPTY_AGENT);
  const [skill, setSkill] = useState<SkillDef | null>(null);
  const chatModels = useYmir((s) => s.chatModels);
  const [promptFiles, setPromptFiles] = useState<PromptFile[]>([]);
  const [prompt, setPrompt] = useState<PromptFile | null>(null);
  const [promptBody, setPromptBody] = useState('');
  const [promptDirty, setPromptDirty] = useState(false);

  useEffect(() => {
    if (mode !== 'prompt' || promptFiles.length) return;
    void gateApi.prompts().then(setPromptFiles).catch(() => {});
  }, [mode, promptFiles.length]);

  function selectPrompt(p: PromptFile) {
    setPrompt(p);
    setPromptBody(p.body);
    setPromptDirty(false);
  }

  /** Jump straight from an agent to its prompts (free-type name still helps). */
  function openPromptsFor(name: string) {
    const key = slug(name);
    const pick = (rows: PromptFile[]) => {
      const match =
        rows.find((r) => r.agent.includes(key) || key.includes(r.agent)) ?? rows[0] ?? null;
      if (match) selectPrompt(match);
    };
    setMode('prompt');
    if (promptFiles.length) pick(promptFiles);
    else
      void gateApi
        .prompts()
        .then((rows) => {
          setPromptFiles(rows);
          pick(rows);
        })
        .catch(() => {});
  }

  async function savePromptFile() {
    if (!prompt) return;
    try {
      const res = await gateApi.savePrompt(prompt.agent, prompt.kind, promptBody);
      setPromptFiles((files) =>
        files.map((f) => (f.agent === prompt.agent && f.kind === prompt.kind ? { ...f, body: promptBody } : f)),
      );
      setPromptDirty(false);
      toast({ kind: 'ok', title: `${prompt.agent}/${prompt.kind}.md saved`, body: res.path });
      emit(`prompt.save ${prompt.agent}/${prompt.kind}`);
    } catch {
      toast({ kind: 'danger', title: 'Prompt save failed', body: 'Check the gate API.' });
    }
  }

  const suggestions = useMemo(
    () => suggestFigures(`${agent.role} ${agent.capabilities}`, 4),
    [agent.role, agent.capabilities],
  );

  function chooseName(name: string, descriptor: string) {
    setAgent((a) => ({ ...a, name, role: a.role || `${name} — ${descriptor}` }));
  }

  function emit(message: string) {
    pushStream({
      id: `forge-${Date.now()}`,
      ts: new Date().toISOString(),
      kind: 'rune',
      from: 'Gungnir',
      module: 'gungnir',
      message,
      checksum: Math.random().toString(16).slice(2, 8),
    });
  }

  function saveAgent() {
    const name = agent.name.trim() || 'Unnamed';
    const capabilities = agent.capabilities
      .split(',')
      .map((c) => c.trim())
      .filter(Boolean);
    if (agent.id) {
      updateAgent(agent.id, { name, role: agent.role, capabilities, domain: agent.domain, model: agent.model });
      toast({ kind: 'ok', title: `${name} updated`, body: 'Agent Card re-published (mock).' });
      emit(`agent.update ${slug(name)}`);
    } else {
      const id = `${slug(name)}-${Date.now().toString(36).slice(-4)}`;
      const card: AgentCardType = {
        id,
        name,
        role: agent.role || 'Eindri worker',
        realm,
        domain: agent.domain,
        status: 'nominal',
        capabilities: capabilities.length ? capabilities : ['general'],
        skills: [],
        interface: { protocol: 'A2A 1.0', endpoint: `utgard://${id}`, signed: false },
        model: agent.model,
        uptime: 0,
        tasksDone: 0,
        traceability: 0.95,
      };
      addAgent(card);
      toast({ kind: 'ok', title: `${name} forged`, body: 'Eindri spawned · A2A card pending JWS.' });
      emit(`agent.forge ${slug(name)}`);
    }
    setAgent(EMPTY_AGENT);
  }

  function editAgent(a: AgentCardType) {
    setMode('agent');
    setSkill(null);
    setAgent({
      id: a.id,
      name: a.name,
      role: a.role,
      capabilities: a.capabilities.join(', '),
      domain: a.domain,
      model: a.model,
    });
  }

  function newSkillDraft(): SkillDef {
    return {
      id: `skl-${Date.now().toString(36)}`,
      name: '',
      aett: 'galdr',
      description: '',
      capabilities: [],
      validated: false,
      domain: 'ymirlabs',
      createdAt: new Date().toISOString(),
    };
  }

  function saveSkill() {
    if (!skill) return;
    const name = skill.name.trim() || 'unnamed-skill';
    const finalSkill = { ...skill, name, capabilities: skill.description.split(/[\s,]+/).slice(0, 4).filter(Boolean) };
    const exists = skills.some((s) => s.id === skill.id);
    if (exists) updateSkill(skill.id, finalSkill);
    else addSkill(finalSkill);
    toast({ kind: 'ok', title: `${name} ${exists ? 'updated' : 'registered'}`, body: 'Validated in Utgard before production.' });
    emit(`skill.${exists ? 'update' : 'forge'} ${name}`);
    setSkill(null);
  }

  return (
    <>
      <div className="stage-head">
        <div>
          <h1 className="stage-title">The Forge</h1>
          <p className="stage-deck">
            Gungnir · create Eindri and skills · every worker earns a myth that matches its craft
          </p>
        </div>
        <div className="stream-tabs" role="group" aria-label="Forge mode">
          <button className="stream-tab" aria-pressed={mode === 'agent'} onClick={() => setMode('agent')}>
            Eindri · {agents.length}
          </button>
          <button className="stream-tab" aria-pressed={mode === 'skill'} onClick={() => setMode('skill')}>
            Skills · {skills.length}
          </button>
          <button className="stream-tab" aria-pressed={mode === 'prompt'} onClick={() => setMode('prompt')}>
            Prompts · {promptFiles.length}
          </button>
        </div>
      </div>

      <div className="forge-layout">
        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">{mode === 'agent' ? 'ᚠ' : 'ᛊ'}</span>
              {mode === 'agent' ? 'Eindri roster' : 'Skill index'}
            </div>
          </div>
          <div className="forge-list">
            {mode === 'agent'
              ? agents.map((a) => (
                  <button
                    key={a.id}
                    className="forge-item"
                    aria-selected={agent.id === a.id}
                    onClick={() => editAgent(a)}
                  >
                    <span className="mono grow truncate">{a.name}</span>
                    <StatusChip status={a.status} />
                  </button>
                ))
              : mode === 'skill'
                ? skills.map((s) => (
                    <button
                      key={s.id}
                      className="forge-item"
                      aria-selected={skill?.id === s.id}
                      onClick={() => setSkill(s)}
                    >
                      <span className="mono grow truncate">{s.name}</span>
                      <RuneTag label={s.aett} glyph="ᛊ" color="var(--ymir-violet-1)" />
                    </button>
                  ))
                : promptFiles.map((p) => (
                    <button
                      key={`${p.agent}/${p.kind}`}
                      className="forge-item"
                      aria-selected={prompt?.agent === p.agent && prompt?.kind === p.kind}
                      onClick={() => selectPrompt(p)}
                    >
                      <span className="mono grow truncate">{p.agent}</span>
                      <span className="dim">{p.kind}.md</span>
                    </button>
                  ))}
            {mode !== 'prompt' ? (
              <button
                className="btn btn-primary"
                style={{ margin: 'var(--ymir-space-3)' }}
                onClick={() => {
                  if (mode === 'agent') {
                    setAgent(EMPTY_AGENT);
                  } else {
                    setSkill(newSkillDraft());
                  }
                }}
              >
                <span aria-hidden="true">+</span> New {mode === 'agent' ? 'Eindri' : 'skill'}
              </button>
            ) : null}
          </div>
        </section>

        <section className="panel">
          <div className="panel-head">
            <div className="panel-title">
              <span className="glyph" aria-hidden="true">ᚨ</span>
              {mode === 'agent'
                ? (agent.id ? `Edit ${agent.name}` : 'Forge a new Eindri')
                : mode === 'skill'
                  ? (skill ? `Edit ${skill.name || 'skill'}` : 'Forge a new skill')
                  : (prompt ? `Edit ${prompt.agent}/${prompt.kind}.md` : 'Agent prompts')}
            </div>
          </div>

          {mode === 'agent' ? (
            <div className="panel-body col" style={{ gap: 'var(--ymir-space-4)' }}>
              <label className="field">
                <span className="eyebrow">Mythic name</span>
                <input
                  value={agent.name}
                  onChange={(e) => setAgent({ ...agent, name: e.target.value })}
                  placeholder="e.g. Sindri"
                />
              </label>

              <div className="chips">
                <span className="eyebrow" style={{ alignSelf: 'center' }}>Suggested by craft →</span>
                {suggestions.map((s) => (
                  <button
                    key={s.figure.name}
                    className="chip"
                    onClick={() => chooseName(s.figure.name, s.figure.descriptor)}
                    title={s.figure.myth}
                  >
                    {s.figure.glyph} {s.figure.name} · {s.figure.descriptor}
                  </button>
                ))}
              </div>

              <label className="field">
                <span className="eyebrow">Role / craft</span>
                <input
                  value={agent.role}
                  onChange={(e) => setAgent({ ...agent, role: e.target.value })}
                  placeholder="code synthesis, refactoring, development"
                />
              </label>

              <label className="field">
                <span className="eyebrow">Capabilities (comma-separated)</span>
                <input
                  value={agent.capabilities}
                  onChange={(e) => setAgent({ ...agent, capabilities: e.target.value })}
                  placeholder="react, vite, a11y"
                />
              </label>

              <div className="form-grid">
                <label className="field">
                  <span className="eyebrow">Domain</span>
                  <select
                    value={agent.domain}
                    onChange={(e) => setAgent({ ...agent, domain: e.target.value as DomainId })}
                  >
                    {DOMAINS_LIST.map((h) => (
                      <option key={h} value={h}>{DOMAINS[h].name}</option>
                    ))}
                  </select>
                </label>
                <label className="field">
                  <span className="eyebrow">Model · connected, free-type</span>
                  <ModelPicker
                    value={agent.model}
                    onChange={(id) => setAgent({ ...agent, model: id })}
                    models={chatModels}
                    placeholder="model id"
                  />
                </label>
              </div>

              <div className="row">
                <button className="btn btn-primary" onClick={saveAgent}>
                  <span aria-hidden="true">ᛉ</span> {agent.id ? 'Save Eindri' : 'Forge Eindri'}
                </button>
                <button className="btn" onClick={() => setAgent(EMPTY_AGENT)}>Clear</button>
                <button className="btn" onClick={() => openPromptsFor(agent.name || agent.role)}>
                  <span aria-hidden="true">ᛊ</span> Edit prompts
                </button>
              </div>
            </div>
          ) : mode === 'skill' && skill ? (
            <div className="panel-body col" style={{ gap: 'var(--ymir-space-4)' }}>
              <div className="form-grid">
                <label className="field">
                  <span className="eyebrow">Skill name</span>
                  <input
                    value={skill.name}
                    onChange={(e) => setSkill({ ...skill, name: e.target.value })}
                    placeholder="workspace_rag"
                  />
                </label>
                <label className="field">
                  <span className="eyebrow">Aett</span>
                  <select
                    value={skill.aett}
                    onChange={(e) => setSkill({ ...skill, aett: e.target.value })}
                  >
                    {AETTS_LIST.map((a) => (
                      <option key={a} value={a}>{a}-</option>
                    ))}
                  </select>
                </label>
              </div>

              <div className="chips">
                <button className="chip" onClick={() => setSkill({ ...skill, aett: aettFor(skill.description) })}>
                  ✦ suggest aett from description
                </button>
              </div>

              <label className="field">
                <span className="eyebrow">Description</span>
                <textarea
                  rows={4}
                  value={skill.description}
                  onChange={(e) => setSkill({ ...skill, description: e.target.value })}
                  placeholder="Hybrid Markdown + vector recall across the workspace."
                />
              </label>

              <label className="field">
                <span className="eyebrow">Domain</span>
                <select
                  value={skill.domain}
                  onChange={(e) => setSkill({ ...skill, domain: e.target.value as DomainId })}
                >
                  {DOMAINS_LIST.map((h) => (
                    <option key={h} value={h}>{DOMAINS[h].name}</option>
                  ))}
                </select>
              </label>

              <button
                className="opt"
                aria-pressed={skill.validated}
                onClick={() => setSkill({ ...skill, validated: !skill.validated })}
              >
                <span className="box" aria-hidden="true">{skill.validated ? '✓' : ''}</span>
                Validated in Utgard (required before production)
              </button>

              <div className="row">
                <button className="btn btn-primary" onClick={saveSkill}>
                  <span aria-hidden="true">ᛉ</span> Register skill
                </button>
                <button className="btn" onClick={() => setSkill(null)}>Cancel</button>
              </div>
            </div>
          ) : prompt ? (
            <div className="panel-body col" style={{ gap: 'var(--ymir-space-4)' }}>
              <div className="row-between">
                <div className="col" style={{ gap: 2 }}>
                  <span className="eyebrow">Prompt file</span>
                  <span className="mono">{prompt.path}</span>
                </div>
                <span className="chip on">{prompt.kind}</span>
              </div>

              <label className="field">
                <span className="eyebrow">{prompt.kind === 'system' ? 'System prompt' : 'User prompt'}</span>
                <textarea
                  rows={18}
                  className="prompt-editor"
                  value={promptBody}
                  onChange={(e) => {
                    setPromptBody(e.target.value);
                    setPromptDirty(true);
                  }}
                />
              </label>

              <div className="row">
                <button className="btn btn-primary" onClick={savePromptFile} disabled={!promptDirty}>
                  <span aria-hidden="true">ᛉ</span> Save prompt
                </button>
                <button
                  className="btn"
                  onClick={() => {
                    setPromptBody(prompt.body);
                    setPromptDirty(false);
                  }}
                  disabled={!promptDirty}
                >
                  Revert
                </button>
                {promptDirty ? <span className="dim" style={{ alignSelf: 'center' }}>unsaved changes</span> : null}
              </div>
            </div>
          ) : (
            <div className="empty">
              <span className="glyph" aria-hidden="true">ᚨ</span>
              <p>Select a prompt file to edit.</p>
            </div>
          )}
        </section>
      </div>
    </>
  );
}
