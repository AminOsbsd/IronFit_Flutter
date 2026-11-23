import {CheckCircle2, MessageSquareText} from 'lucide-react';
import {colors, demo} from '../config';
import {pop, prog} from '../lib/anim';
import {ui} from '../theme';
import {Avatar, Box, Card, Screen} from '../components/ui';

/** Rebuilt from app/lib/screens/program_screens.dart (program detail + coach comment). */
export const CoachingScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.light;
  const ex = [['Squat', '4 × 6-8 · 70 kg · repos 2 min'], ['Développé couché', '4 × 6-8 · 60 kg · repos 2 min'], ['Soulevé de terre', '3 × 5 · 90 kg · repos 3 min']];
  const m = pop(f, 62, 13);
  return (
    <Screen c={c}>
      <Box x={20} y={58} w={350} style={{fontSize: 22, fontWeight: 700}}>Prise de force — 4 semaines</Box>
      <Box x={16} y={102} w={358} h={96}><Card c={c} style={{height: '100%', display: 'flex', alignItems: 'center', gap: 14}}><div style={{opacity: prog(f, 10, 14)}}><Avatar name={demo.coach} size={58} /></div><div><div style={{fontWeight: 700, fontSize: 18}}>Coach : {demo.coach}</div><div style={{color: c.sub, fontSize: 15, marginTop: 4}}>Objectif : Force</div></div></Card></Box>
      <Box x={20} y={218} style={{fontSize: 18, fontWeight: 700}}>Exercices</Box>
      {ex.map(([n, d], i) => {
        const p = prog(f, 14 + i * 8, 36 + i * 8);
        return <Box key={n} x={16} y={252 + i * 84} w={358} h={74} style={{opacity: p, transform: `translateY(${(1 - p) * 30}px)`}}><Card c={c} style={{height: '100%', padding: '12px 16px'}}><div style={{fontWeight: 700, fontSize: 17}}>{n}</div><div style={{color: c.sub, fontSize: 15, marginTop: 4}}>{d}</div></Card></Box>;
      })}
      <Box x={20} y={520} style={{fontSize: 18, fontWeight: 700, opacity: prog(f, 40, 54)}}>Dernière séance</Box>
      <Box x={16} y={554} w={358} h={234} style={{opacity: prog(f, 42, 58)}}>
        <Card c={c} style={{height: '100%'}}>
          <div style={{display: 'flex', alignItems: 'center', gap: 10, fontWeight: 700, fontSize: 17}}><CheckCircle2 size={23} color={colors.success} />Séance A · 65 min</div>
          <div style={{color: c.sub, fontSize: 15, marginTop: 8}}>Difficulté 7/10 · bonnes sensations</div>
          <div style={{marginTop: 16, background: `${colors.amber}33`, border: `2px solid ${colors.amber}`, borderRadius: 16, padding: 15, fontSize: 18, lineHeight: 1.42, fontWeight: 500, transform: `scale(${m})`, transformOrigin: '0 0', opacity: Math.min(1, m), display: 'flex', gap: 12}}><MessageSquareText size={24} color={colors.amberDeep} style={{flexShrink: 0, marginTop: 2}} /><span>{demo.comment}</span></div>
        </Card>
      </Box>
    </Screen>
  );
};
