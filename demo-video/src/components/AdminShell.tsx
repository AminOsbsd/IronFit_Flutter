import {CalendarDays, Home, LayoutGrid, User} from 'lucide-react';
import {colors, demo} from '../config';
import {fonts, ui} from '../theme';
import {useLayout} from '../lib/layout';

export const A = ui.dark;
export const useAdmin = () => { const {portrait} = useLayout(); return {portrait, k: portrait ? 1.32 : 1}; };
export const adminCard: React.CSSProperties = {background: A.card, border: `1px solid ${A.line}`, borderRadius: 18, boxSizing: 'border-box'};
export const railWidth = (portrait: boolean) => (portrait ? 0 : 92);

/** Desktop window frame: title bar + the app's navigation rail (administration). Content slides inside it. */
export const AdminShell: React.FC<{w: number; h: number; active: number; children: React.ReactNode}> = ({w, h, active, children}) => {
  const {portrait} = useLayout();
  const rail = railWidth(portrait);
  return (
    <div style={{position: 'absolute', left: 0, top: 0, width: w, height: h, background: A.bg, color: A.text, fontFamily: fonts.ui, overflow: 'hidden'}}>
      <div style={{position: 'absolute', left: rail, right: 0, top: 46, bottom: 0, overflow: 'hidden'}}>{children}</div>
      <div style={{position: 'absolute', left: 0, right: 0, top: 0, height: 46, boxSizing: 'border-box', background: A.card, borderBottom: `1px solid ${A.line}`, display: 'flex', alignItems: 'center', gap: 9, padding: '0 20px'}}>{['#FF5F57', '#FEBC2E', '#28C840'].map((x) => <span key={x} style={{width: 13, height: 13, borderRadius: 7, background: x}} />)}<span style={{marginLeft: 14, color: A.sub, fontSize: 16, fontWeight: 600}}>IronFit · Administration</span><span style={{marginLeft: 'auto', color: A.sub, fontSize: 16}}>{demo.demoLabel}</span></div>
      {rail ? <div style={{position: 'absolute', left: 0, top: 46, bottom: 0, width: rail, boxSizing: 'border-box', borderRight: `1px solid ${A.line}`, background: A.card}}>
        <div style={{position: 'absolute', left: 19, top: 26 + active * 64, width: 54, height: 42, borderRadius: 14, background: colors.amber}} />
        {[Home, CalendarDays, LayoutGrid, User].map((I, i) => <div key={i} style={{position: 'absolute', left: 19, top: 26 + i * 64, width: 54, height: 42, display: 'grid', placeItems: 'center'}}><I size={24} color={Math.abs(active - i) < 0.5 ? colors.ink : A.sub} /></div>)}
      </div> : null}
    </div>
  );
};
