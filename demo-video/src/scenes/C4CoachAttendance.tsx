import {Check, Clock3, X} from 'lucide-react';
import {colors} from '../config';
import {pop, prog} from '../lib/anim';
import {ui} from '../theme';
import {Avatar, Box, Card, Screen} from '../components/ui';

const people = [['Youssef K.', 'present', 48], ['Amira J.', 'present', 70], ['Leila T.', 'present', 92], ['Karim H.', 'absent', 114], ['Nour B.', 'pending', 999]] as const;
const look = {present: ['Présent', colors.success, Check], absent: ['Absent', '#D92D20', X], pending: ['À vérifier', '#8A8D96', Clock3]} as const;

/** Rebuilt from ParticipantsPage (planning_screen.dart). */
export const CoachAttendanceScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.light;
  const ok = people.filter((p) => p[1] === 'present' && f >= p[2]).length;
  const bar = people.reduce((n, p) => n + (p[1] === 'present' ? prog(f, p[2], p[2] + 16) : 0), 0) / 5;
  return (
    <Screen c={c}>
      <Box x={20} y={58} style={{fontSize: 24, fontWeight: 700}}>Musculation · 18:00</Box>
      <Box x={20} y={92} style={{fontSize: 15.5, color: c.sub}}>Lundi 23 novembre</Box>
      <Box x={16} y={130} w={358} h={104} style={{borderRadius: 20, background: 'linear-gradient(135deg,#141519,#2B2C33)', color: '#fff', padding: 20}}><div style={{fontSize: 21, fontWeight: 700}}>{ok} / 5 présences confirmées</div><div style={{height: 10, borderRadius: 5, background: 'rgba(255,255,255,.18)', marginTop: 20}}><div style={{height: 10, borderRadius: 5, width: `${bar * 100}%`, background: colors.amber}} /></div></Box>
      {people.map(([n, st, at], i) => {
        const inn = prog(f, 6 + i * 5, 28 + i * 5), p = pop(f, at, 11);
        const [label, col, I] = look[f >= at ? st : 'pending'];
        return (
          <Box key={n} x={16} y={252 + i * 100} w={358} h={88} style={{opacity: inn, transform: `translateX(${(1 - inn) * 60}px)`}}>
            <Card c={c} style={{height: '100%', display: 'flex', alignItems: 'center', gap: 14, border: `2px solid ${f >= at ? col : c.line}`}}>
              <Avatar name={n} size={50} /><div style={{flex: 1, fontWeight: 700, fontSize: 18}}>{n}</div>
              <div style={{display: 'flex', alignItems: 'center', gap: 7, background: f >= at ? col : c.soft, color: f >= at ? '#fff' : c.sub, borderRadius: 12, padding: '9px 14px', fontWeight: 700, fontSize: 15.5, transform: `scale(${f >= at ? 0.8 + 0.2 * p : 1})`}}><I size={18} strokeWidth={3} />{label}</div>
            </Card>
          </Box>
        );
      })}
    </Screen>
  );
};
