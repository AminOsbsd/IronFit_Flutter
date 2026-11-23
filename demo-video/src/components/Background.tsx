import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {BEAT, colors} from '../config';
import {easeInOut, float, prog} from '../lib/anim';
import {useLayout} from '../lib/layout';
import {SceneKey, starts} from '../timeline';

export type Tone = 'dark' | 'light' | 'amber';
export const tone: Record<SceneKey, Tone> = {
  hook: 'dark', reveal: 'dark',
  chMember: 'amber', aiCoach: 'dark', planning: 'light', guided: 'dark', progress: 'light', coaching: 'dark',
  chCoach: 'amber', coachHome: 'light', coachProgram: 'dark', coachFeedback: 'light', coachAttendance: 'dark',
  chAdmin: 'amber', adminDash: 'dark', adminRequests: 'light', adminRisk: 'dark', adminManage: 'light',
  benefits: 'dark', end: 'dark',
};

const Fill: React.FC<{t: Tone; f: number}> = ({t, f}) => {
  const dark = t === 'dark', amber = t === 'amber';
  const {width, height} = useLayout();
  const m = Math.max(width, height);
  const beat = Math.exp(-(f % BEAT) / 5);
  return (
    <AbsoluteFill style={{background: amber ? `linear-gradient(120deg, ${colors.amber} 15%, #FF9340 100%)` : dark ? colors.ink : colors.paper, overflow: 'hidden'}}>
      <div style={{position: 'absolute', width: m, height: m, borderRadius: '50%', left: width * 0.55 + float(f, 60, 400), top: -m * 0.45 + float(f, 50, 340, 1), background: `radial-gradient(circle, ${amber ? '#FFFFFF66' : colors.amber + (dark ? '30' : '48')} 0%, transparent 62%)`, opacity: 0.85 + beat * 0.15}} />
      <div style={{position: 'absolute', width: m * 0.9, height: m * 0.9, borderRadius: '50%', left: -m * 0.35 + float(f, 60, 380, 2), top: height * 0.5 + float(f, 40, 300), background: `radial-gradient(circle, ${colors.ember}${dark ? '22' : '2E'} 0%, transparent 62%)`}} />
      <svg width={width} height={height} style={{position: 'absolute', opacity: amber ? 0.1 : dark ? 0.05 : 0.06}}>
        {[0, 1, 2].map((i) => (
          <path key={i} transform={`translate(${width * 0.5 + float(f, 24, 500, i)} ${height * (0.62 + i * 0.16)})`} d={`M${-width} 420 L${-width * 0.35} 60 L${-width * 0.22} 130 L0 -140 L${width * 0.22} 110 L${width * 0.3} 50 L${width} 420`} fill="none" stroke={dark ? colors.amber : colors.charcoal} strokeWidth={10} />
        ))}
      </svg>
    </AbsoluteFill>
  );
};

/** Backgrounds change through a diagonal wipe with an amber leading edge, always on the beat. */
export const Background: React.FC = () => {
  const f = useCurrentFrame();
  const keys = Object.keys(tone) as SceneKey[];
  return (
    <AbsoluteFill>
      {keys.map((k, i) => {
        const changes = i > 0 && tone[keys[i - 1]] !== tone[k];
        if (i > 0 && !changes) return null;
        const from = starts[k] - 14;
        const next = keys.slice(i + 1).find((n) => tone[n] !== tone[k]);
        if (f < (i ? from : 0) || (next && f > starts[next] + 20)) return null;
        const p = i ? prog(f, from, starts[k] + 14, easeInOut) : 1;
        const x = -40 + p * 190;
        const x2 = x + (p < 1 ? 9 : 0);
        return (
          <AbsoluteFill key={k}>
            {i > 0 && p < 1 ? <AbsoluteFill style={{background: `linear-gradient(90deg, ${colors.ember}, ${colors.amber})`, clipPath: `polygon(-50% 0, ${x2}% 0, ${x2 - 30}% 100%, -50% 100%)`}} /> : null}
            <AbsoluteFill style={p < 1 ? {clipPath: `polygon(-50% 0, ${x}% 0, ${x - 30}% 100%, -50% 100%)`} : undefined}>
              <Fill t={tone[k]} f={f} />
            </AbsoluteFill>
          </AbsoluteFill>
        );
      })}
    </AbsoluteFill>
  );
};
