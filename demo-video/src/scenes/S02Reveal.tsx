import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {colors, copy} from '../config';
import {mix, pop, prog, range} from '../lib/anim';
import {useLayout} from '../lib/layout';
import {gradient} from '../theme';
import {KineticLines, fitLines} from '../components/KineticText';
import {Logo} from '../components/Logo';

/** 5-10 s: the amber line becomes the mountain, the wordmark rises behind it. */
export const Reveal: React.FC = () => {
  const f = useCurrentFrame();
  const {width, height, portrait} = useLayout();
  const w = portrait ? 860 : 880, h = (w * 670) / 1200, lineW = portrait ? 620 : 900;
  const out = prog(f, 130, 148);
  const top = height / 2 - h / 2 - (portrait ? 160 : 110);
  const l = prog(f, 0, 16);
  const lines = portrait ? [copy.reveal.line1, copy.reveal.line2] : [`${copy.reveal.line1} ${copy.reveal.line2}`];
  return (
    <AbsoluteFill style={{opacity: 1 - out, transform: `scale(${1 + out * 0.12 + f * 0.0002})`}}>
      <div style={{position: 'absolute', left: width / 2 - 600, top: height / 2 - 600, width: 1200, height: 1200, borderRadius: '50%', background: `radial-gradient(circle, ${colors.amber}55, transparent 60%)`, transform: `scale(${pop(f, 0, 20, 60)})`, opacity: range(f, 0, 60, 1, 0.35)}} />
      <div style={{position: 'absolute', left: width / 2 - mix(lineW, w * 0.8, l) / 2, top: mix(height / 2 - 5, top + h * 0.53, l), width: mix(lineW, w * 0.8, l), height: mix(10, 3, l), borderRadius: 5, background: gradient, opacity: 1 - prog(f, 12, 26)}} />
      <div style={{position: 'absolute', left: width / 2 - w / 2, top}}><Logo width={w} m={prog(f, 6, 40)} w={prog(f, 24, 54)} t={prog(f, 48, 66)} /></div>
      <div style={{position: 'absolute', left: 0, right: 0, top: top + h + (portrait ? 110 : 70), display: 'flex', justifyContent: 'center'}}>
        <KineticLines lines={lines} f={f} inAt={54} outAt={128} size={fitLines(lines, width - (portrait ? 140 : 400), portrait ? 76 : 62)} color={colors.white} align="center" stagger={8} accentLast={portrait ? colors.amber : undefined} />
      </div>
    </AbsoluteFill>
  );
};
