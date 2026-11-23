import {fitText} from '@remotion/layout-utils';
import {displayStyle, fonts} from '../theme';
import {prog} from '../lib/anim';

/** Largest size (up to max) at which every line fits the width: text can never overflow. */
export const fitLines = (lines: string[], width: number, max: number) =>
  Math.min(max, ...lines.map((text) => fitText({text, withinWidth: width, fontFamily: fonts.display, fontWeight: 800, letterSpacing: '-0.02em', additionalStyles: {fontStretch: '118%'}, validateFontIsLoaded: false}).fontSize * 0.97));

/** Lines that rise out of a mask, then leave upward. */
export const KineticLines: React.FC<{lines: string[]; f: number; inAt: number; outAt: number; size: number; color: string; align?: 'left' | 'center'; stagger?: number; accentLast?: string}> = ({lines, f, inAt, outAt, size, color, align = 'left', stagger = 5, accentLast}) => (
  <div style={{...displayStyle, fontSize: size, color, textAlign: align}}>
    {lines.map((l, i) => {
      const a = prog(f, inAt + i * stagger, inAt + i * stagger + 22);
      const b = prog(f, outAt + i * 2, outAt + i * 2 + 10, (t) => t * t * t);
      return (
        <div key={i} style={{overflow: 'hidden', paddingBottom: '0.16em', marginBottom: '-0.1em', paddingTop: '0.08em', marginTop: '-0.08em'}}>
          <div style={{whiteSpace: 'nowrap', transform: `translateY(${(1 - a) * 118 - b * 118}%)`, color: accentLast && i === lines.length - 1 ? accentLast : undefined}}>{l}</div>
        </div>
      );
    })}
  </div>
);
