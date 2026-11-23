import {Bot, Send, X} from 'lucide-react';
import {colors, demo} from '../config';
import {pop, prog} from '../lib/anim';
import {ui} from '../theme';
import {Badge, Box, Screen} from '../components/ui';

/** Rebuilt from app/lib/widgets/ai_coach.dart (chat panel). */
export const AiCoachScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.light;
  const q = pop(f, 30), dots = f >= 52 && f < 74;
  const words = demo.reply.join('\n').split(/(?<=[ \n])/);
  const shown = Math.floor(prog(f, 74, 132, (t) => t) * words.length);
  return (
    <Screen c={c}>
      <Box x={0} y={46} w={390} h={74} style={{display: 'flex', alignItems: 'center', gap: 12, padding: '0 18px', borderBottom: `1px solid ${c.line}`}}>
        <Badge icon={Bot} />
        <div style={{flex: 1}}><div style={{fontWeight: 700, fontSize: 18}}>AI Coach</div><div style={{fontSize: 13, color: c.sub}}>Votre coach virtuel IronFit</div></div>
        <X size={22} color={c.text} />
      </Box>
      <Box x={0} y={150} w={390} style={{textAlign: 'center'}}>
        <div style={{width: 78, height: 78, margin: '0 auto', borderRadius: '50%', background: `linear-gradient(135deg, ${colors.amber}, ${colors.ember})`, display: 'grid', placeItems: 'center', transform: `scale(${pop(f, 8)})`}}><Bot size={40} color={colors.ink} /></div>
        <div style={{fontWeight: 700, fontSize: 19, marginTop: 14, opacity: prog(f, 14, 26)}}>Bonjour {demo.member} !</div>
      </Box>
      <Box x={60} y={316} w={312} style={{display: 'flex', justifyContent: 'flex-end'}}>
        <div style={{background: colors.amber, color: colors.ink, borderRadius: '18px 18px 4px 18px', padding: '13px 16px', fontSize: 17, fontWeight: 500, whiteSpace: 'nowrap', transform: `scale(${q})`, transformOrigin: '100% 100%', opacity: Math.min(1, q)}}>{demo.question}</div>
      </Box>
      {dots ? (
        <Box x={18} y={386} w={92} h={46} style={{background: c.soft, borderRadius: 18, display: 'flex', gap: 7, alignItems: 'center', justifyContent: 'center'}}>
          {[0, 1, 2].map((i) => <div key={i} style={{width: 10, height: 10, borderRadius: 5, background: c.sub, opacity: 0.35 + 0.65 * Math.max(0, Math.sin((f - 52) / 4 - i))}} />)}
        </Box>
      ) : null}
      {f >= 74 ? (
        <Box x={18} y={386} w={348} h={236} style={{background: c.soft, visibility: f >= 168 ? 'hidden' : 'visible', borderRadius: '18px 18px 18px 4px', padding: '18px 20px', fontSize: 21, lineHeight: 1.48, transformOrigin: '0 0', transform: `scale(${0.94 + 0.06 * prog(f, 74, 86)})`, whiteSpace: 'pre-wrap'}}>
          {words.slice(0, shown).join('')}
        </Box>
      ) : null}
      <Box x={16} y={764} w={300} h={54} style={{border: `2px solid ${c.accent}`, borderRadius: 14, background: '#fff', color: c.sub, fontSize: 16, display: 'flex', alignItems: 'center', paddingLeft: 16}}>Écrivez votre message…</Box>
      <Box x={326} y={768} w={48} h={48} style={{borderRadius: 24, background: colors.amber, display: 'grid', placeItems: 'center'}}><Send size={21} color={colors.ink} /></Box>
    </Screen>
  );
};
