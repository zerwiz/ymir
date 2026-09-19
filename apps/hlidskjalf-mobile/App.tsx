import { useEffect, useState } from 'react';
import { SafeAreaView, ScrollView, StyleSheet, Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';

/**
 * Hlidskjalf Mobile — the sovereign's view in the hand (W0037).
 *
 * Reads the same gate API the web control plane uses (`apps/hlidskjalf/server`).
 * Set the API base with `EXPO_PUBLIC_API_URL` (default http://127.0.0.1:3889),
 * or point it at Bifrost in production.
 */
const API = process.env.EXPO_PUBLIC_API_URL ?? 'http://127.0.0.1:3889';

type Agent = { id: string; name: string; role: string; status: string };
type Task = { id: string; title: string; state: string; agent: string };

async function get<T>(path: string): Promise<T | null> {
  try {
    const res = await fetch(`${API}${path}`);
    if (!res.ok) return null;
    return (await res.json()) as T;
  } catch {
    return null;
  }
}

export default function App() {
  const [agents, setAgents] = useState<Agent[]>([]);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [online, setOnline] = useState<boolean | null>(null);

  useEffect(() => {
    let alive = true;
    const load = async () => {
      const health = await get<{ ok: boolean }>('/api/health');
      const a = await get<Agent[]>('/api/agents');
      const t = await get<Task[]>('/api/tasks');
      if (!alive) return;
      setOnline(Boolean(health?.ok));
      setAgents(a ?? []);
      setTasks((t ?? []).slice(0, 20));
    };
    void load();
    const timer = setInterval(load, 5000);
    return () => {
      alive = false;
      clearInterval(timer);
    };
  }, []);

  return (
    <SafeAreaView style={styles.safe}>
      <StatusBar style="light" />
      <ScrollView contentContainerStyle={styles.wrap}>
        <Text style={styles.brand}>HLIDSKJALF</Text>
        <Text style={styles.deck}>
          {online === null ? 'reading the realms…' : online ? 'live · the gate answers' : 'offline · the gate is quiet'}
        </Text>

        <Text style={styles.h}>Fleet · {agents.length}</Text>
        {agents.map((a) => (
          <View key={a.id} style={styles.row}>
            <Text style={styles.name}>{a.name}</Text>
            <Text style={styles.meta}>
              {a.role} · {a.status}
            </Text>
          </View>
        ))}

        <Text style={styles.h}>Forge orders · {tasks.length}</Text>
        {tasks.map((t) => (
          <View key={t.id} style={styles.row}>
            <Text style={styles.name}>
              {t.id} · {t.title}
            </Text>
            <Text style={styles.meta}>{t.state}</Text>
          </View>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#080c14' },
  wrap: { padding: 20, gap: 8 },
  brand: { color: '#38bdf8', fontSize: 22, fontWeight: '700', letterSpacing: 2 },
  deck: { color: '#94a3b8', marginBottom: 12 },
  h: { color: '#e2e8f0', fontSize: 16, fontWeight: '700', marginTop: 18, marginBottom: 6 },
  row: { borderTopWidth: 1, borderTopColor: '#1e293b', paddingVertical: 8 },
  name: { color: '#e2e8f0', fontSize: 15 },
  meta: { color: '#64748b', fontSize: 12, marginTop: 2 },
});
