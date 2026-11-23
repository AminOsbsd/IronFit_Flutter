import {CalendarCheck, CreditCard, Dumbbell, Users} from 'lucide-react';
import {colors, demo} from '../config';
import {pop, prog} from '../lib/anim';
import {A, adminCard, useAdmin} from '../components/AdminShell';

const icons = [Users, CreditCard, Dumbbell, CalendarCheck];
const fill: [string, number, number][] = [['Yoga', 9, 12], ['CrossFit', 8, 10], ['Musculation', 11, 15], ['Pilates', 7, 12]];
const bars = [38, 52, 47, 63, 58, 74];

/** Rebuilt from AdminHome (admin_screens.dart). Figures are demo data. */
export const AdminDash: React.FC<{f: number}> = ({f}) => {
  const {portrait, k} = useAdmin();
  return (
    <div style={{position: 'absolute', inset: 24, display: 'flex', flexDirection: 'column', gap: 18}}>
      <div style={{display: 'grid', gridTemplateColumns: portrait ? '1fr 1fr' : 'repeat(4,1fr)', gap: 16}}>
        {demo.kpis.map((q, i) => {
          const I = icons[i], p = pop(f, 10 + i * 6);
          return <div key={q.label} style={{...adminCard, padding: 18 * k, transform: `translateY(${(1 - p) * 40}px)`, opacity: Math.min(1, p)}}><I size={28 * k} color={colors.amber} /><div style={{fontSize: 44 * k, fontWeight: 800, marginTop: 6, fontVariantNumeric: 'tabular-nums'}}>{Math.round(q.value * prog(f, 14 + i * 6, 76 + i * 6))}</div><div style={{color: A.sub, fontSize: 18.5 * k, whiteSpace: 'nowrap'}}>{q.label}</div></div>;
        })}
      </div>
      <div style={{flex: 1, display: 'flex', flexDirection: portrait ? 'column' : 'row', gap: 16, minHeight: 0}}>
        <div style={{...adminCard, flex: 1, padding: 22, display: 'flex', flexDirection: 'column', minHeight: 0}}>
          <div style={{fontWeight: 700, fontSize: 21 * k}}>Revenus par mois</div>
          <div style={{flex: 1, display: 'flex', gap: 18, paddingTop: 18, minHeight: 0}}>{bars.map((b, i) => <div key={i} style={{flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8}}><div style={{flex: 1, width: '100%', position: 'relative'}}><div style={{position: 'absolute', bottom: 0, width: '100%', height: `${(b / 74) * 100 * prog(f, 36 + i * 4, 80 + i * 4)}%`, borderRadius: 9, background: i === 5 ? `linear-gradient(${colors.amber},${colors.ember})` : '#3A3C45'}} /></div><span style={{color: A.sub, fontSize: 16 * k}}>{['Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov'][i]}</span></div>)}</div>
        </div>
        <div style={{...adminCard, flex: 1, padding: 22}}>
          <div style={{fontWeight: 700, fontSize: 21 * k}}>Remplissage des cours</div>
          {fill.map(([n, a, b], i) => {
            const p = prog(f, 60 + i * 10, 104 + i * 10);
            return <div key={n} style={{marginTop: 17 * k}}><div style={{display: 'flex', justifyContent: 'space-between', fontSize: 18 * k, fontWeight: 600}}><span>{n}</span><span style={{color: A.sub}}>{Math.round(a * p)}/{b}</span></div><div style={{height: 11, borderRadius: 6, background: A.soft, marginTop: 8}}><div style={{height: 11, borderRadius: 6, width: `${(a / b) * 100 * p}%`, background: `linear-gradient(90deg,${colors.amber},${colors.ember})`}} /></div></div>;
          })}
        </div>
      </div>
    </div>
  );
};
