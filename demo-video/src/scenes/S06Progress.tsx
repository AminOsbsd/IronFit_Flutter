import {Trophy} from 'lucide-react';
import {colors, demo} from '../config';
import {fr, pop, prog} from '../lib/anim';
import {fonts, ui} from '../theme';
import {Box, Card, NavBar, Screen, Title} from '../components/ui';

const W = 310, H = 150, min = 80.2, max = 82.8;
const points = demo.weights.map((w, i) => [(i / (demo.weights.length - 1)) * W, ((max - w) / (max - min)) * H]);

/** Rebuilt from ProgressView (member_screens.dart) and TrainingProgress (program_screens.dart). */
export const ProgressScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.memberDark;
  const draw = prog(f, 14, 74);
  const path = points.reduce((d, [x, y], i) => (i ? `${d} C ${points[i - 1][0] + W / 6} ${points[i - 1][1]}, ${x - W / 6} ${y}, ${x} ${y}` : `M ${x} ${y}`), '');
  const first = demo.weights[0], lastW = demo.weights[demo.weights.length - 1];
  const stat = (x: number, label: string, v: string, unit: string) => <Box x={x} y={104} w={172} h={104}><Card c={c} style={{height: '100%'}}><div style={{color: c.sub, fontSize: 15}}>{label}</div><div style={{fontSize: 30, fontWeight: 800, marginTop: 8, fontVariantNumeric: 'tabular-nums'}}>{v} <span style={{fontSize: 17}}>{unit}</span></div></Card></Box>;
  return (
    <Screen c={c}>
      <Title>Ma progression</Title>
      {stat(16, 'Poids', fr(first + (lastW - first) * draw), 'kg')}
      {stat(202, 'Masse grasse', fr(19.5 - 1.3 * draw), '%')}
      <Box x={16} y={222} w={358} h={270}><Card c={c} style={{height: '100%'}}><div style={{fontWeight: 700, fontSize: 17}}>Poids (kg)</div></Card></Box>
      <Box x={38} y={290} w={W} h={H}>
        <svg width={W + 24} height={H + 40} style={{overflow: 'visible'}}>
          {[0, 0.5, 1].map((g) => <line key={g} x1={0} x2={W} y1={H * g} y2={H * g} stroke={c.line} strokeWidth={1.5} />)}
          <defs><linearGradient id="ln" x1="0" x2="1"><stop stopColor={c.primary} /><stop offset="1" stopColor={colors.ember} /></linearGradient><linearGradient id="ar" x1="0" x2="0" y1="0" y2="1"><stop stopColor={c.primary} stopOpacity={0.3} /><stop offset="1" stopColor={c.primary} stopOpacity={0} /></linearGradient><clipPath id="cp"><rect x={-10} y={-20} width={(W + 30) * draw} height={H + 60} /></clipPath></defs>
          <g clipPath="url(#cp)"><path d={`${path} L ${W} ${H + 14} L 0 ${H + 14} Z`} fill="url(#ar)" /><path d={path} fill="none" stroke="url(#ln)" strokeWidth={6} strokeLinecap="round" /></g>
          {points.map(([x, y], i) => <circle key={i} cx={x} cy={y} r={i === points.length - 1 && f >= 168 ? 0 : 8 * pop(f, 14 + i * 15, 12)} fill={i === points.length - 1 ? colors.ember : c.primary} stroke={c.card} strokeWidth={3} />)}
          {['S1', 'S2', 'S3', 'S4'].map((s, i) => <text key={s} x={points[i][0]} y={H + 34} fill={c.sub} fontSize={14} textAnchor="middle" fontFamily={fonts.ui}>{s}</text>)}
        </svg>
      </Box>
      <Box x={20} y={510} style={{fontSize: 18, fontWeight: 700}}>Meilleures charges</Box>
      {[['Squat', '72,5 kg'], ['Développé couché', '60 kg'], ['Soulevé de terre', '90 kg']].map(([n, v], i) => {
        const p = prog(f, 62 + i * 10, 84 + i * 10);
        return <Box key={n} x={16} y={544 + i * 70} w={358} h={60} style={{opacity: p, transform: `translateX(${(1 - p) * 60}px)`}}><Card c={c} style={{height: '100%', padding: '0 16px', display: 'flex', alignItems: 'center', gap: 14}}><Trophy size={22} color={c.primary} /><span style={{flex: 1, fontSize: 17, fontWeight: 600}}>{n}</span><b style={{fontSize: 18, color: c.primary}}>{v}</b></Card></Box>;
      })}
      <NavBar c={c} active={3} />
    </Screen>
  );
};
