import {Check, Search} from 'lucide-react';
import {colors} from '../config';
import {kf, mix, pop, prog} from '../lib/anim';
import {ui} from '../theme';
import {Box, Card, NavBar, Screen, Title} from '../components/ui';

const days: [string, number][] = [['Lun', 23], ['Mar', 24], ['Mer', 25], ['Jeu', 26], ['Ven', 27], ['Sam', 28]];

/** Rebuilt from app/lib/screens/planning_screen.dart. */
export const PlanningScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.dark;
  const sel = prog(f, 34, 48), tap = f >= 78 && f < 88, done = pop(f, 88, 11);
  const bar = mix(8 / 12, 9 / 12, prog(f, 90, 112));
  const cx = kf(f, [[50, 330], [76, 292]]), cy = kf(f, [[50, 760], [76, 566]]), co = kf(f, [[48, 0], [56, 1], [90, 1], [98, 0]]);
  return (
    <Screen c={c}>
      <Title>Planning</Title>
      <Box x={20} y={102} style={{fontSize: 22, fontWeight: 700}}>Trouvez votre rythme</Box>
      <Box x={20} y={133} style={{fontSize: 15, color: c.sub}}>Réservez, participez, progressez.</Box>
      <Box x={16} y={170} w={358} h={50} style={{border: `1px solid ${c.line}`, background: c.soft, borderRadius: 12, display: 'flex', alignItems: 'center', gap: 10, padding: '0 14px', color: c.sub, fontSize: 15}}><Search size={19} />Rechercher un cours ou un coach</Box>
      <Box x={16} y={238} w={358} style={{display: 'flex', gap: 7}}>
        {days.map(([d, n], i) => {
          const on = i === 1 ? sel : i === 0 ? 1 - sel : 0;
          return <div key={d} style={{flex: 1, height: 72, boxSizing: 'border-box', borderRadius: 14, border: `1px solid ${c.line}`, background: on > 0.5 ? colors.amber : c.card, color: on > 0.5 ? colors.ink : c.text, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4, transform: `scale(${i === 1 ? 1 + 0.08 * Math.sin(sel * Math.PI) : 1})`}}><span style={{fontWeight: 700, fontSize: 15}}>{d}</span><span style={{fontSize: 14, opacity: 0.85}}>{n}</span></div>;
        })}
      </Box>
      <Box x={16} y={338} w={358} h={268} style={{opacity: prog(f, 8, 15)}}>
        <Card c={c} style={{height: '100%', position: 'relative'}}>
          <div style={{display: 'flex', gap: 14}}>
            <div style={{width: 70, height: 48, borderRadius: 12, background: c.soft, display: 'grid', placeItems: 'center', fontWeight: 800, fontSize: 18}}>19:00</div>
            <div><div style={{fontWeight: 700, fontSize: 20}}>Yoga</div><div style={{color: c.sub, fontSize: 15, marginTop: 4}}>Coach : Leila · Yoga & Pilates</div></div>
          </div>
          <div style={{marginTop: 26, display: 'flex', justifyContent: 'space-between', fontSize: 15, color: c.sub}}><span>Places réservées</span><span style={{color: c.text, fontWeight: 700}}>{f > 94 ? 9 : 8}/12</span></div>
          <div style={{height: 9, borderRadius: 5, background: c.soft, marginTop: 10}}><div style={{height: 9, borderRadius: 5, width: `${bar * 100}%`, background: `linear-gradient(90deg, ${colors.amber}, ${colors.ember})`}} /></div>
          <div style={{position: 'absolute', right: 16, left: 16, bottom: 18, height: 60, borderRadius: 14, background: done > 0.05 ? colors.success : colors.amber, color: done > 0.05 ? '#fff' : colors.ink, fontWeight: 700, fontSize: 18, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, visibility: f >= 168 ? 'hidden' : 'visible', transform: `scale(${tap ? 0.95 : 1})`}}>
            {done > 0.05 ? <><span style={{width: 32, height: 32, borderRadius: 16, background: '#fff', display: 'grid', placeItems: 'center', transform: `scale(${done})`}}><Check size={21} color={colors.success} strokeWidth={3.4} /></span>Réservation confirmée</> : 'Réserver'}
          </div>
        </Card>
      </Box>
      <Box x={16} y={622} w={358} h={110}><Card c={c} style={{height: '100%', opacity: 0.75}}><div style={{display: 'flex', gap: 14}}><div style={{width: 70, height: 48, borderRadius: 12, background: c.soft, display: 'grid', placeItems: 'center', fontWeight: 800, fontSize: 18}}>20:15</div><div><div style={{fontWeight: 700, fontSize: 18}}>Stretching</div><div style={{color: c.sub, fontSize: 15, marginTop: 4}}>Coach : Leila</div></div></div></Card></Box>
      <NavBar c={c} active={1} />
      <Box x={cx - 24} y={cy - 24} w={48} h={48} style={{borderRadius: 24, background: 'rgba(255,255,255,.35)', border: '2px solid rgba(255,255,255,.8)', opacity: co, transform: `scale(${tap ? 0.7 : 1})`}} />
    </Screen>
  );
};
