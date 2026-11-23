import {AbsoluteFill, Img, staticFile, useCurrentFrame} from 'remotion';
import {Dumbbell, Users} from 'lucide-react';
import {colors, copy, durations} from '../config';
import {kf, mix, pop, prog} from '../lib/anim';
import {useLayout} from '../lib/layout';
import {fonts, ui} from '../theme';
import {KineticLines, fitLines} from '../components/KineticText';
import {Avatar, Box, Card, Screen, Title} from '../components/ui';

/** Full-screen chapter card that opens the member part. */
export const MemberChapter: React.FC = () => {
  const f = useCurrentFrame();
  const {width, portrait} = useLayout();
  const out = durations.chMember - 24;
  const size = fitLines(copy.chMember.title, width - (portrait ? 140 : 500), portrait ? 130 : 170);
  const p = pop(f, 2), o = prog(f, out, out + 10), s = prog(f, 20, 40);
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', gap: 34, transform: `scale(${1 + f * 0.0007})`}}>
      <div style={{width: 120, height: 120, borderRadius: 36, background: colors.ink, display: 'grid', placeItems: 'center', transform: `scale(${p * (1 - o)}) rotate(${(1 - p) * -40}deg)`}}><Dumbbell size={64} color={colors.amber} strokeWidth={2.4} /></div>
      <KineticLines lines={copy.chMember.title} f={f} inAt={6} outAt={out} size={size} color={colors.ink} align="center" />
      <div style={{fontFamily: fonts.ui, fontSize: portrait ? 44 : 46, fontWeight: 500, color: '#2B1D00', opacity: s * (1 - o), transform: `translateY(${(1 - s) * 24}px)`}}>{copy.chMember.sub}</div>
    </AbsoluteFill>
  );
};

/** Coach chapter: the workspace switch from home_shell.dart (one account, two spaces). */
export const WorkspaceScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.light;
  const t = prog(f, 50, 66);
  const cx = kf(f, [[26, 320], [46, 284]]), cy = kf(f, [[26, 620], [46, 418]]), co = kf(f, [[24, 0], [32, 1], [58, 1], [68, 0]]);
  const seg = (i: number, label: string, I: typeof Users) => <div style={{flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, fontWeight: 700, fontSize: 15.5, color: c.text, zIndex: 1, opacity: i === 1 ? mix(0.75, 1, t) : mix(1, 0.75, t)}}><I size={19} />{label}</div>;
  return (
    <Screen c={c}>
      <Title>Profil</Title>
      <Box x={16} y={104} w={358} h={210} style={{borderRadius: 20, background: 'linear-gradient(135deg,#141519,#2B2C33)', color: '#fff', display: 'flex', alignItems: 'center', gap: 16, padding: 20}}><Avatar name="Sami" size={64} /><div><div style={{fontWeight: 800, fontSize: 21}}>Sami Ben Ali</div><div style={{color: 'rgba(255,255,255,.7)', fontSize: 15, marginTop: 5}}>Coach · membre · Musculation</div></div></Box>
      <Box x={20} y={348} style={{fontSize: 16, color: c.sub, fontWeight: 600}}>Espace affiché</Box>
      <Box x={16} y={386} w={358} h={62} style={{borderRadius: 16, border: `1.5px solid ${c.line}`, background: '#fff', display: 'flex', overflow: 'hidden', visibility: f >= durations.chCoach - 13 ? 'hidden' : 'visible'}}>
        <div style={{position: 'absolute', top: 0, left: mix(0, 178, t), width: 178, height: 62, background: colors.amber}} />
        {seg(0, 'Mon entraînement', Dumbbell)}{seg(1, 'Espace coach', Users)}
      </Box>
      {[['Mon entraînement', 'Ses séances, sa progression, ses cours'], ['Espace coach', 'Ses clients, programmes, présences']].map(([a, b], i) => <Box key={a} x={16} y={478 + i * 104} w={358} h={92}><Card c={c} style={{height: '100%', borderColor: (i === 1 ? t : 1 - t) > 0.5 ? colors.amber : c.line, borderWidth: 2, transform: `scale(${i === 1 ? 1 + 0.03 * Math.sin(t * Math.PI) : 1})`}}><div style={{fontWeight: 700, fontSize: 18}}>{a}</div><div style={{color: c.sub, fontSize: 15, marginTop: 7}}>{b}</div></Card></Box>)}
      <Box x={cx - 24} y={cy - 24} w={48} h={48} style={{borderRadius: 24, background: 'rgba(23,24,28,.22)', border: '2px solid rgba(23,24,28,.5)', opacity: co, transform: `scale(${f >= 46 && f < 54 ? 0.7 : 1})`}} />
    </Screen>
  );
};

/** Admin chapter: the launch splash, shown while the phone unfolds into a desktop window. */
export const AdminSplash: React.FC<{f: number; w: number; h: number}> = ({f, w, h}) => {
  const lw = Math.min(w * 0.5, 560);
  const p = prog(f, 10, 34);
  return (
    <div style={{position: 'absolute', left: 0, top: 0, width: w, height: h, background: `radial-gradient(circle at 50% 46%, #2A1E08, ${colors.ink} 60%)`, display: 'grid', placeItems: 'center'}}>
      <div style={{position: 'relative', width: lw, height: (lw * 670) / 1200, opacity: p, transform: `scale(${mix(0.9, 1, p) + f * 0.0003})`}}>{['mountain', 'wordmark', 'tagline'].map((n) => <Img key={n} src={staticFile(`brand/${n}.png`)} style={{position: 'absolute', inset: 0, width: '100%'}} />)}</div>
      <div style={{position: 'absolute', bottom: 60, left: w / 2 - 90, width: 180, height: 5, borderRadius: 3, background: 'rgba(255,255,255,.14)'}}><div style={{width: `${prog(f, 14, 96) * 100}%`, height: 5, borderRadius: 3, background: colors.amber}} /></div>
    </div>
  );
};
