import {Img, staticFile} from 'remotion';
import {mix} from '../lib/anim';

/** Official logo in three layers. m / w / t are the reveal progress of mountain, wordmark and tagline. */
export const Logo: React.FC<{width: number; m: number; w: number; t: number}> = ({width, m, w, t}) => {
  const h = (width * 670) / 1200;
  const img = {position: 'absolute' as const, left: 0, top: 0, width, height: h};
  return (
    <div style={{position: 'relative', width, height: h}}>
      <div style={{position: 'absolute', inset: 0, clipPath: `inset(0 ${(1 - m) * 50}% 0 ${(1 - m) * 50}%)`}}>
        <Img src={staticFile('brand/mountain.png')} style={{...img, transform: `translateY(${mix(26, 0, m)}%)`}} />
      </div>
      <div style={{position: 'absolute', left: 0, top: h * 0.495, width, height: h * 0.395, overflow: 'hidden'}}>
        <Img src={staticFile('brand/wordmark.png')} style={{...img, top: -h * 0.495, transform: `translateY(${(1 - w) * 42}%)`}} />
      </div>
      <Img src={staticFile('brand/tagline.png')} style={{...img, opacity: t, transform: `translateY(${(1 - t) * 18}px)`}} />
    </div>
  );
};
