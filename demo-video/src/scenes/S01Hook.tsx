import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {BEAT, colors, copy, durations} from '../config';
import {easeInOut, float, mix, prog} from '../lib/anim';
import {useLayout} from '../lib/layout';
import {displayStyle, gradient} from '../theme';
import {fitLines} from '../components/KineticText';

const WORD_AT = [BEAT, BEAT * 3, BEAT * 5];

/** 0-5 s: a pile of generic apps, three punches on the beat, then everything collapses into one amber line. */
export const Hook: React.FC = () => {
  const f = useCurrentFrame();
  const {width, height, portrait} = useLayout();
  const col = prog(f, 112, 138, easeInOut);
  const size = fitLines(copy.hook, width - (portrait ? 150 : 420), portrait ? 150 : 190);
  const lineW = portrait ? 620 : 900;
  return (
    <AbsoluteFill>
      {Array.from({length: 22}).map((_, i) => {
        const a = i * 2.399, rad = 0.2 + 0.36 * Math.sqrt((i + 1) / 22) * 1.5;
        const x = width / 2 + Math.cos(a) * rad * width * 0.62, y = height / 2 + Math.sin(a) * rad * height * 0.62;
        const inn = prog(f, i * 2, i * 2 + 24), s = 84 + (i % 4) * 22;
        return <div key={i} style={{position: 'absolute', left: mix(x, width / 2, col) + float(f, 14, 110, i), top: mix(y, height / 2, col) + float(f, 18, 130, i * 1.7), width: s, height: s, borderRadius: s * 0.26, transform: `translate(-50%,-50%) rotate(${float(f, 9, 160, i)}deg) scale(${inn * (1 - col * 0.96)})`, background: i % 5 === 0 ? `linear-gradient(135deg,${colors.ember}55,${colors.amber}33)` : 'linear-gradient(145deg,#2d2f37,#1a1b20)', border: '1.5px solid rgba(255,255,255,.1)', boxShadow: '0 18px 40px rgba(0,0,0,.4)', opacity: 0.62, display: 'grid', placeItems: 'center'}}><div style={{width: '46%', height: 8, borderRadius: 4, background: 'rgba(255,255,255,.28)', boxShadow: '0 16px 0 rgba(255,255,255,.14), 0 -16px 0 rgba(255,255,255,.14)'}} /></div>;
      })}
      <AbsoluteFill style={{background: `radial-gradient(ellipse at center, ${colors.ink}F2 18%, ${colors.ink}99 45%, transparent 75%)`, opacity: prog(f, 4, 20) * (1 - col)}} />
      {copy.hook.map((w, i) => {
        const s = WORD_AT[i], e = i < 2 ? WORD_AT[i + 1] - 4 : 112;
        if (f < s - 3 || f > e + 12) return null;
        const p = prog(f, s - 3, s + 7), o = i < 2 ? prog(f, e, e + 6) : prog(f, 112, 124);
        return <AbsoluteFill key={w} style={{alignItems: 'center', justifyContent: 'center'}}><div style={{...displayStyle, fontSize: size, color: i === 2 ? colors.amber : colors.white, whiteSpace: 'nowrap', transform: `scale(${mix(1.7, 1, p) + (f - s) * 0.0007}) translateY(${i < 2 ? -o * 40 : 0}px) scaleY(${i === 2 ? 1 - o * 0.95 : 1})`, filter: p < 1 ? `blur(${(1 - p) * 16}px)` : undefined, opacity: p * (1 - o)}}>{w}</div></AbsoluteFill>;
      })}
      <div style={{position: 'absolute', left: width / 2 - (lineW * prog(f, 120, 150, easeInOut)) / 2, top: height / 2 - 5, width: lineW * prog(f, 120, 150, easeInOut), height: 10, borderRadius: 5, background: gradient, boxShadow: `0 0 60px ${colors.amber}AA`, opacity: f >= 118 && f <= durations.hook ? 1 : 0}} />
    </AbsoluteFill>
  );
};
