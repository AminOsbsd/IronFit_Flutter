import type {LucideIcon} from 'lucide-react';
import {Img, staticFile} from 'remotion';
import {Bot, CalendarDays, Compass, Dumbbell, Home, User} from 'lucide-react';
import {colors} from '../config';
import {Ui, fonts, shadow} from '../theme';

/** Small pieces rebuilt from common_widgets.dart / home_shell.dart. Phone canvas: 390 x 844. */
export const PHONE = {w: 390, h: 844};

export const StatusBar: React.FC<{c: Ui}> = ({c}) => (
  <div style={{height: 46, padding: '14px 28px 0', display: 'flex', justifyContent: 'space-between', fontFamily: fonts.ui, fontWeight: 600, fontSize: 15, color: c.text}}>
    <span>18:00</span>
    <span style={{display: 'flex', gap: 5, alignItems: 'center'}}>
      <span style={{width: 16, height: 11, borderRadius: 3, background: c.text, opacity: 0.9}} />
      <span style={{width: 24, height: 12, borderRadius: 4, border: `1.6px solid ${c.text}`, padding: 1.5}}><span style={{display: 'block', width: '78%', height: '100%', borderRadius: 1.5, background: c.text}} /></span>
    </span>
  </div>
);

const tabs: [LucideIcon, string][] = [[Home, 'Accueil'], [CalendarDays, 'Planning'], [Compass, 'Explorer'], [Dumbbell, 'Mon espace'], [User, 'Profil']];
export const NavBar: React.FC<{c: Ui; active: number}> = ({c, active}) => (
  <div style={{position: 'absolute', left: 0, right: 0, bottom: 0, height: 84, background: c.card, borderTop: `1px solid ${c.line}`, display: 'flex', paddingTop: 10}}>
    {tabs.map(([Icon, label], i) => (
      <div key={label} style={{flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4}}>
        <div style={{width: 54, height: 32, borderRadius: 14, display: 'grid', placeItems: 'center', background: i === active ? c.nav : 'transparent'}}><Icon size={20} color={i === active ? colors.ink : c.sub} /></div>
        <span style={{fontFamily: fonts.ui, fontSize: 11.5, fontWeight: i === active ? 800 : 500, color: i === active ? c.text : c.sub}}>{label}</span>
      </div>
    ))}
  </div>
);

export const Screen: React.FC<{c: Ui; children: React.ReactNode}> = ({c, children}) => (
  <div style={{position: 'absolute', inset: 0, background: c.bg, color: c.text, fontFamily: fonts.ui, overflow: 'hidden'}}><StatusBar c={c} />{children}</div>
);
export const Title: React.FC<{children: React.ReactNode}> = ({children}) => <div style={{fontSize: 25, fontWeight: 700, padding: '10px 20px 4px', letterSpacing: '-0.01em'}}>{children}</div>;
export const Card: React.FC<{c: Ui; style?: React.CSSProperties; children?: React.ReactNode}> = ({c, style, children}) => (
  <div style={{background: c.card, border: `1px solid ${c.line}`, borderRadius: c.radius, padding: 16, boxShadow: shadow.card, boxSizing: 'border-box', ...style}}>{children}</div>
);
export const Avatar: React.FC<{name: string; size?: number}> = ({name, size = 44}) => (
  <div style={{width: size, height: size, borderRadius: '50%', background: colors.amber, color: colors.ink, display: 'grid', placeItems: 'center', fontWeight: 800, fontSize: size * 0.42, flexShrink: 0}}>{name[0]}</div>
);
export const Badge: React.FC<{icon?: LucideIcon; size?: number}> = ({icon: Icon = Bot, size = 44}) => (
  <div style={{width: size, height: size, borderRadius: size * 0.3, background: `${colors.amber}40`, display: 'grid', placeItems: 'center', flexShrink: 0}}><Icon size={size * 0.52} color={colors.amberDeep} /></div>
);
/** Official logo with charcoal lettering (light surfaces), as on the member home. */
export const LogoMark: React.FC<{width: number}> = ({width}) => (
  <div style={{position: 'relative', width, height: (width * 670) / 1200}}>
    {['mountain', 'wordmark', 'tagline'].map((n) => <Img key={n} src={staticFile(`brand/${n}.png`)} style={{position: 'absolute', inset: 0, width, filter: n === 'mountain' ? undefined : 'brightness(.09)'}} />)}
  </div>
);
/** MemberIllustration inside its tinted tile (member_design.dart). */
export const MemberArt: React.FC<{c: Ui; size?: number}> = ({c, size = 82}) => (
  <div style={{width: size, height: size, borderRadius: 18, background: c.soft, display: 'grid', placeItems: 'center', flexShrink: 0}}><Img src={staticFile('brand/member-fitness.png')} style={{width: size}} /></div>
);
/** Absolute box helper, so morph anchors match the UI exactly. */
export const Box: React.FC<{x: number; y: number; w?: number; h?: number; style?: React.CSSProperties; children?: React.ReactNode}> = ({x, y, w, h, style, children}) => (
  <div style={{position: 'absolute', left: x, top: y, width: w, height: h, boxSizing: 'border-box', ...style}}>{children}</div>
);
