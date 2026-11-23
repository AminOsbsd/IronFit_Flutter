import {Bell, CheckCircle2, MessageSquareText, Send} from 'lucide-react';
import {colors, demo} from '../config';
import {pop, prog} from '../lib/anim';
import {ui} from '../theme';
import {Avatar, Box, Card, Screen} from '../components/ui';

/** Rebuilt from WorkoutCard and its comment dialog (program_screens.dart). */
export const CoachFeedbackScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.dark;
  const text = demo.comment.slice(0, Math.max(0, Math.floor((f - 46) / 1.15)));
  const sent = pop(f, 134, 13), note = pop(f, 152, 14), tap = f >= 124 && f < 134;
  return (
    <Screen c={c}>
      <Box x={20} y={58} style={{fontSize: 24, fontWeight: 700}}>Séances de Youssef</Box>
      <Box x={16} y={106} w={358} h={210} style={{opacity: prog(f, 4, 20)}}>
        <Card c={c} style={{height: '100%'}}>
          <div style={{display: 'flex', gap: 14, alignItems: 'center'}}><Avatar name="Youssef" size={50} /><div><div style={{fontWeight: 700, fontSize: 18}}>Youssef Karray</div><div style={{color: c.sub, fontSize: 14.5, marginTop: 3}}>Prise de force · 65 min</div></div></div>
          <div style={{display: 'flex', alignItems: 'center', gap: 8, marginTop: 18, fontSize: 16}}><CheckCircle2 size={21} color="#35C47C" />« Séance A, bonnes sensations »</div>
          <div style={{marginTop: 18, fontSize: 14.5, color: c.sub, display: 'flex', justifyContent: 'space-between'}}><span>Difficulté ressentie</span><b style={{color: c.text}}>7/10</b></div>
          <div style={{display: 'flex', gap: 5, marginTop: 9}}>{Array.from({length: 10}).map((_, i) => <div key={i} style={{flex: 1, height: 11, borderRadius: 5, background: i < 7 * prog(f, 18, 42) ? colors.amber : c.soft}} />)}</div>
        </Card>
      </Box>
      <Box x={16} y={334} w={358} h={250} style={{borderRadius: 18, background: c.card, border: `2px solid ${sent > 0.1 ? '#35C47C' : colors.amber}`, padding: 18, opacity: prog(f, 22, 38), transform: `translateY(${(1 - prog(f, 22, 40)) * 40}px)`}}>
        <div style={{display: 'flex', gap: 10, alignItems: 'center', fontWeight: 700, fontSize: 17, color: sent > 0.1 ? '#35C47C' : colors.amber}}>{sent > 0.1 ? <CheckCircle2 size={22} /> : <MessageSquareText size={22} />}{sent > 0.1 ? 'Commentaire envoyé' : 'Commentaire'}</div>
        <div style={{marginTop: 14, fontSize: 20, lineHeight: 1.42, minHeight: 90}}>{text || <span style={{color: c.sub}}>Retour, conseils…</span>}{f > 40 && f < 124 && Math.floor(f / 8) % 2 ? <span style={{color: colors.amber}}>|</span> : null}</div>
        <div style={{position: 'absolute', right: 18, bottom: 18, height: 50, padding: '0 22px', borderRadius: 13, background: colors.amber, color: colors.ink, display: 'flex', alignItems: 'center', gap: 10, fontWeight: 700, fontSize: 17, transform: `scale(${(tap ? 0.92 : 1) * (1 - Math.min(1, sent))})`}}><Send size={19} />Envoyer</div>
      </Box>
      <Box x={16} y={612} w={358} h={110} style={{borderRadius: 20, background: '#fff', color: '#17181C', display: 'flex', alignItems: 'center', gap: 14, padding: '0 18px', boxShadow: '0 24px 50px rgba(0,0,0,.5)', opacity: Math.min(1, note), transform: `translateY(${(1 - note) * 120}px)`}}>
        <div style={{width: 52, height: 52, borderRadius: 16, background: colors.amber, display: 'grid', placeItems: 'center', flexShrink: 0}}><Bell size={27} color={colors.ink} style={{transform: `rotate(${f > 152 ? Math.sin((f - 152) / 2.4) * 22 * Math.exp(-(f - 152) / 16) : 0}deg)`}} /></div>
        <div><div style={{fontSize: 13.5, color: '#5A5D66', fontWeight: 600}}>Chez Youssef</div><div style={{fontWeight: 700, fontSize: 17, marginTop: 4, lineHeight: 1.25}}>Nouveau commentaire de votre coach</div></div>
      </Box>
    </Screen>
  );
};
