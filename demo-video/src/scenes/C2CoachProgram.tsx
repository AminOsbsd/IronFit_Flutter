import {GripVertical, Plus} from 'lucide-react';
import {colors} from '../config';
import {pop, prog} from '../lib/anim';
import {ui} from '../theme';
import {Avatar, Box, Card, Screen} from '../components/ui';

const ex = [['Squat', '4', '6-8', '72,5 kg', '2 min', 66], ['Développé couché', '4', '6-8', '60 kg', '2 min', 104], ['Soulevé de terre', '3', '5', '90 kg', '3 min', 142], ['Tractions', '3', 'max', '', '90 s', 180]] as const;
const typed = (f: number, from: number, s: string, speed = 1.2) => s.slice(0, Math.max(0, Math.floor((f - from) / speed)));

/** Rebuilt from the program and exercise forms (program_screens.dart). */
export const CoachProgramScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.light;
  const title = 'Prise de force — 4 semaines', t = typed(f, 18, title);
  const n = ex.filter((e) => f >= e[5]).length;
  return (
    <Screen c={c}>
      <Box x={20} y={56} style={{fontSize: 23, fontWeight: 700}}>Nouveau programme</Box>
      <Box x={16} y={98} w={358} h={66}><Card c={c} style={{height: '100%', padding: '0 14px', display: 'flex', alignItems: 'center', gap: 12}}><Avatar name="Youssef" size={42} /><div><div style={{fontSize: 13, color: c.sub}}>Client</div><div style={{fontWeight: 700, fontSize: 17}}>Youssef Karray</div></div></Card></Box>
      <Box x={16} y={178} w={358} h={64} style={{borderRadius: 13, background: '#fff', border: `2px solid ${f < 54 ? c.accent : c.line}`, padding: '9px 15px'}}><div style={{fontSize: 12.5, color: c.accent, fontWeight: 600}}>Titre</div><div style={{fontSize: 18, fontWeight: 600, marginTop: 2}}>{t}{f > 16 && f < 54 && Math.floor(f / 8) % 2 ? '|' : ''}</div></Box>
      <Box x={20} y={262} w={350} style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 18, fontWeight: 700}}>Exercices<span style={{background: `${colors.amber}40`, color: colors.amberText, borderRadius: 10, padding: '4px 12px', fontSize: 15, transform: `scale(${1 + 0.2 * Math.max(0, ...ex.map((e) => (f >= e[5] && f < e[5] + 12 ? Math.sin(((f - e[5]) / 12) * Math.PI) : 0)))})`}}>{n}</span></Box>
      {ex.map(([name, sets, reps, load, rest, at], i) => {
        const p = pop(f, at, 13);
        if (f < at) return null;
        return (
          <Box key={name} x={16} y={300 + i * 104} w={358} h={94} style={{opacity: Math.min(1, p), transform: `translateY(${(1 - p) * 50}px) scale(${0.92 + 0.08 * p})`}}>
            <Card c={c} style={{height: '100%', padding: '12px 14px', display: 'flex', gap: 10, alignItems: 'center'}}>
              <GripVertical size={20} color={c.sub} />
              <div style={{flex: 1}}>
                <div style={{fontWeight: 700, fontSize: 17.5}}>{name}</div>
                <div style={{display: 'flex', gap: 7, marginTop: 9}}>{[`${sets} × ${reps}`, load, rest].filter(Boolean).map((v, j) => { const q = pop(f, at + 8 + j * 5); return <span key={v} style={{background: c.soft, borderRadius: 9, padding: '5px 11px', fontSize: 14.5, fontWeight: 600, transform: `scale(${q})`}}>{v}</span>; })}</div>
              </div>
            </Card>
          </Box>
        );
      })}
      <Box x={16} y={744} w={358} h={62} style={{borderRadius: 16, background: colors.amber, color: colors.ink, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, fontWeight: 700, fontSize: 18, transform: `scale(${ex.some((e) => f >= e[5] - 6 && f < e[5]) ? 0.95 : 1})`}}><Plus size={23} strokeWidth={3} />Ajouter un exercice</Box>
    </Screen>
  );
};
