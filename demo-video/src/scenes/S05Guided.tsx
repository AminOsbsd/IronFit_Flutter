import {Check} from 'lucide-react';
import {colors} from '../config';
import {pop, prog, range} from '../lib/anim';
import {ui} from '../theme';
import {Box, Card, Screen} from '../components/ui';

const sets = [{n: 1, reps: '8', kg: '72,5', at: 26}, {n: 2, reps: '7', kg: '72,5', at: 71}, {n: 3, reps: '7', kg: '72,5', at: 116}];

/** Rebuilt from app/lib/screens/guided_workout_screen.dart. */
export const GuidedScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.member;
  const doneN = sets.filter((s) => f >= s.at).length;
  const bar = (sets.reduce((n, s) => n + prog(f, s.at, s.at + 18), 0) + 3) / 14;
  const last = [...sets].reverse().find((s) => f >= s.at)?.at ?? 0;
  const left = Math.max(0, 90 - Math.floor(Math.max(0, f - last) * 0.5));
  const ring = left / 90, C = 2 * Math.PI * 64;
  return (
    <Screen c={c}>
      <Box x={16} y={56} w={358} h={128} style={{borderRadius: 20, background: 'linear-gradient(135deg,#141519,#2B2C33)', color: '#fff', padding: 18}}>
        <div style={{color: colors.amber, fontSize: 14, fontWeight: 700, letterSpacing: '0.08em'}}>SÉANCE GUIDÉE</div>
        <div style={{fontSize: 23, fontWeight: 700, marginTop: 10}}>{3 + doneN} / 14 séries validées</div>
        <div style={{height: 8, borderRadius: 4, background: 'rgba(255,255,255,.18)', marginTop: 16}}><div style={{height: 8, borderRadius: 4, width: `${bar * 100}%`, background: c.primary}} /></div>
      </Box>
      <Box x={16} y={200} w={358} h={206}><Card c={c} style={{height: '100%'}} /></Box>
      <Box x={120} y={216} w={150} h={150} style={{opacity: f >= 168 ? 0 : prog(f, 8, 16)}}>
        <svg width={150} height={150} style={{transform: 'rotate(-90deg)'}}><circle cx={75} cy={75} r={64} fill="none" stroke={c.soft} strokeWidth={12} /><circle cx={75} cy={75} r={64} fill="none" stroke={c.primary} strokeWidth={12} strokeLinecap="round" strokeDasharray={C} strokeDashoffset={C * (1 - ring)} /></svg>
        <div style={{position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', fontSize: 36, fontWeight: 800, fontVariantNumeric: 'tabular-nums'}}>{Math.floor(left / 60)}:{String(left % 60).padStart(2, '0')}</div>
      </Box>
      <Box x={16} y={372} w={358} style={{textAlign: 'center', color: c.sub, fontSize: 15, fontWeight: 600}}>Repos</Box>
      <Box x={20} y={424} style={{fontSize: 20, fontWeight: 700}}>Squat</Box>
      <Box x={20} y={451} style={{fontSize: 15, color: c.sub}}>Prévu : 4 × 6-8 · 72,5 kg · repos 2 min</Box>
      {sets.map((s, i) => {
        const p = pop(f, s.at, 11), inn = prog(f, 4 + i * 5, 24 + i * 5);
        return (
          <Box key={s.n} x={16} y={490 + i * 112} w={358} h={98} style={{opacity: inn, transform: `translateY(${(1 - inn) * 40}px)`}}>
            <Card c={c} style={{height: '100%', display: 'flex', alignItems: 'center', gap: 12, border: `${p > 0.1 ? 2 : 1}px solid ${p > 0.1 ? c.primary : c.line}`}}>
              <div style={{width: 72, fontWeight: 700, fontSize: 17}}>Série {s.n}</div>
              {[['reps', s.reps], ['kg', s.kg]].map(([l, v]) => <div key={l} style={{flex: 1, height: 56, borderRadius: 12, border: `1px solid ${c.line}`, background: '#fff', display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 5, paddingTop: 14, boxSizing: 'border-box', opacity: range(f, s.at - 12, s.at - 4, 0.35, 1)}}><b style={{fontSize: 22}}>{f >= s.at - 10 ? v : '–'}</b><span style={{fontSize: 13, color: c.sub}}>{l}</span></div>)}
              <div style={{width: 40, height: 40, borderRadius: 12, border: `2px solid ${p > 0.1 ? c.primary : c.line}`, background: p > 0.1 ? c.primary : 'transparent', display: 'grid', placeItems: 'center', transform: `scale(${p > 0 ? 0.85 + p * 0.15 : 1})`, boxSizing: 'border-box'}}>{p > 0.1 ? <Check size={25} color={colors.ink} strokeWidth={3.4} /> : null}</div>
            </Card>
          </Box>
        );
      })}
    </Screen>
  );
};
