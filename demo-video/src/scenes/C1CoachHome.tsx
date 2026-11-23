import {Check, Dumbbell, MessageSquareText, TrendingDown, Users} from 'lucide-react';
import {colors, durations} from '../config';
import {kf, pop, prog} from '../lib/anim';
import {ui} from '../theme';
import {Avatar, Box, Card, Screen} from '../components/ui';

const kpis = [[Users, 'Clients suivis', 12], [Dumbbell, 'Programmes actifs', 9], [TrendingDown, 'Séances clients (7 j)', 21], [MessageSquareText, 'Séances à commenter', 4]] as const;

/** Rebuilt from CoachHome (coach_screens.dart). */
export const CoachHomeScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.dark;
  const done = pop(f, 120, 12), tap = f >= 110 && f < 120;
  const cx = kf(f, [[84, 340], [108, 296]]), cy = kf(f, [[84, 800], [108, 640]]), co = kf(f, [[82, 0], [90, 1], [122, 1], [130, 0]]);
  return (
    <Screen c={c}>
      <Box x={20} y={58} style={{fontSize: 24, fontWeight: 700}}>Coach Sami</Box>
      <Box x={16} y={104} w={358} h={92} style={{borderRadius: 20, background: 'linear-gradient(135deg,#1F2025,#34353D)', padding: 18, opacity: prog(f, 10, 16)}}><div style={{color: colors.amber, fontSize: 13.5, fontWeight: 700, letterSpacing: '0.08em'}}>ESPACE COACH</div><div style={{fontSize: 22, fontWeight: 800, marginTop: 8}}>Sami Ben Ali</div></Box>
      {kpis.map(([I, label, v], i) => {
        const p = pop(f, 16 + i * 6);
        return <Box key={label} x={16 + (i % 2) * 183} y={212 + Math.floor(i / 2) * 136} w={175} h={124} style={{opacity: Math.min(1, p), transform: `scale(${0.8 + 0.2 * p})`}}><Card c={c} style={{height: '100%'}}><I size={25} color={colors.amber} /><div style={{fontSize: 32, fontWeight: 800, marginTop: 6}}>{Math.round(v * prog(f, 20 + i * 6, 56 + i * 6))}</div><div style={{fontSize: 14.5, color: c.sub, whiteSpace: 'nowrap'}}>{label}</div></Card></Box>;
      })}
      <Box x={20} y={494} style={{fontSize: 18, fontWeight: 700, opacity: prog(f, 48, 60)}}>Demandes de suivi</Box>
      <Box x={16} y={526} w={358} h={154} style={{opacity: prog(f, 52, 68), transform: `translateY(${(1 - prog(f, 52, 70)) * 30}px)`}}>
        <Card c={c} style={{height: '100%'}}>
          <div style={{display: 'flex', gap: 14, alignItems: 'center'}}><Avatar name="Amira" size={50} /><div><div style={{fontWeight: 700, fontSize: 18}}>Amira Jlassi</div><div style={{color: c.sub, fontSize: 15, marginTop: 3}}>Souhaite être suivie</div></div></div>
          <div style={{display: 'flex', gap: 12, marginTop: 18}}>
            {done < 0.05 ? <div style={{flex: 1, height: 50, borderRadius: 12, border: `1.5px solid ${c.line}`, display: 'grid', placeItems: 'center', fontWeight: 700, fontSize: 16}}>Refuser</div> : null}
            <div style={{flex: 1, height: 50, borderRadius: 12, background: done > 0.05 ? colors.success : colors.amber, color: done > 0.05 ? '#fff' : colors.ink, display: 'flex', gap: 8, alignItems: 'center', justifyContent: 'center', fontWeight: 700, fontSize: 16, transform: `scale(${tap ? 0.94 : 1})`}}>{done > 0.05 ? <><Check size={22} strokeWidth={3} style={{transform: `scale(${done})`}} />Suivi accepté</> : 'Accepter'}</div>
          </div>
        </Card>
      </Box>
      <Box x={16} y={696} w={358} h={86} style={{opacity: prog(f, 60, 76)}}><Card c={c} style={{height: '100%', display: 'flex', alignItems: 'center', gap: 14}}><TrendingDown size={28} color={colors.ember} /><div><div style={{fontWeight: 700, fontSize: 16.5}}>Membres à risque d’abandon</div><div style={{color: c.sub, fontSize: 14.5, marginTop: 3}}>Vos clients qui décrochent</div></div></Card></Box>
      <Box x={cx - 24} y={cy - 24} w={48} h={48} style={{borderRadius: 24, background: 'rgba(255,255,255,.35)', border: '2px solid rgba(255,255,255,.8)', opacity: co * (f < durations.coachHome ? 1 : 0), transform: `scale(${tap ? 0.7 : 1})`}} />
    </Screen>
  );
};
