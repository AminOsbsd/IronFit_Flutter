import {ArrowRight, Bell, Bot, CreditCard, RefreshCw} from 'lucide-react';
import {Img, staticFile} from 'remotion';
import {colors, demo} from '../config';
import {prog} from '../lib/anim';
import {ui} from '../theme';
import {Badge, Box, Card, LogoMark, MemberArt, NavBar, Screen} from '../components/ui';

/** Member home (member_screens.dart), with the floating AI Coach button. */
export const MemberHome: React.FC<{f: number; pressed: boolean}> = ({f, pressed}) => {
  const c = ui.member;
  const art = prog(f, -4, 22);
  return (
    <Screen c={c}>
      <Box x={20} y={48} w={390}><LogoMark width={92} /></Box>
      <Box x={232} y={54} w={34} h={34} style={{borderRadius: 17, background: '#FFE8CA', color: '#492800', display: 'grid', placeItems: 'center', fontWeight: 600, fontSize: 16}}>{demo.member[0]}</Box>
      <Box x={286} y={60}><Bell size={23} color={c.text} /></Box>
      <Box x={338} y={60}><RefreshCw size={22} color={c.text} /></Box>
      <Box x={16} y={110} w={358} h={244} style={{borderRadius: 28, overflow: 'hidden', background: 'linear-gradient(135deg,#171717,#343235)', color: '#fff'}}>
        <div style={{position: 'absolute', right: -65, top: -65, width: 210, height: 210, borderRadius: 105, background: 'rgba(255,152,0,.15)'}} />
        <div style={{position: 'absolute', right: 14, top: 70 + (1 - art) * 24, opacity: art}}><Img src={staticFile('brand/member-fitness.png')} style={{width: 140}} /></div>
        <div style={{position: 'absolute', left: 22, top: 22, width: 206}}>
          <div style={{color: colors.amber, fontSize: 13, letterSpacing: '.09em'}}>Bonjour, {demo.member} 👋</div>
          <div style={{fontSize: 23, fontWeight: 800, lineHeight: 1.2, marginTop: 12}}>Prise de force — 4 semaines</div>
          <div style={{fontSize: 14, lineHeight: 1.35, color: 'rgba(255,255,255,.7)', marginTop: 8, width: 172}}>Retrouvez votre programme ou réservez un cours à la salle.</div>
        </div>
        <div style={{position: 'absolute', left: 22, bottom: 18, height: 44, borderRadius: 22, background: c.primary, color: colors.ink, display: 'flex', alignItems: 'center', gap: 9, padding: '0 20px', fontWeight: 600, fontSize: 15}}><ArrowRight size={18} />Ouvrir mon programme</div>
      </Box>
      <Box x={16} y={372} w={358} h={122}><Card c={c} style={{height: '100%', display: 'flex', alignItems: 'center', gap: 14}}><Badge icon={CreditCard} /><div><div style={{fontWeight: 600, fontSize: 18}}>Mensuel</div><div style={{color: c.sub, fontSize: 14, marginTop: 3}}>N° 0004 · Youssef Karray</div><div style={{display: 'inline-block', marginTop: 9, padding: '5px 12px', borderRadius: 14, background: '#1E9E5A22', color: colors.success, fontWeight: 700, fontSize: 13.5}}>Actif · 93 jours restants</div></div></Card></Box>
      <Box x={18} y={520} style={{display: 'flex', alignItems: 'center', gap: 10}}><div style={{width: 4, height: 18, borderRadius: 2, background: colors.amber}} /><b style={{fontSize: 18, fontWeight: 600}}>Mes prochains cours</b><span style={{color: colors.amberText, fontWeight: 600, fontSize: 15, marginLeft: 6}}>Planning</span></Box>
      <Box x={16} y={556} w={358} h={174}><Card c={c} style={{height: '100%', display: 'flex', gap: 14}}><MemberArt c={c} /><div><div style={{fontWeight: 800, fontSize: 18}}>Musculation</div><div style={{fontSize: 15, marginTop: 8}}>2026-11-23 · 18:00</div><div style={{color: c.sub, fontSize: 14, marginTop: 3}}>Coach : {demo.coach}</div></div></Card></Box>
      <NavBar c={c} active={0} />
      <Box x={318} y={688} w={56} h={56} style={{borderRadius: 28, background: c.primary, display: 'grid', placeItems: 'center', boxShadow: '0 8px 20px rgba(0,0,0,.28)', transform: `scale(${pressed ? 0.86 : 1 + 0.06 * Math.max(0, Math.sin(f / 5))})`}}><Bot size={28} color={colors.ink} /></Box>
    </Screen>
  );
};
