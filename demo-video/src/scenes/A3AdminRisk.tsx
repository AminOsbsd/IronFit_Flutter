import {BellRing, Check, TrendingDown} from 'lucide-react';
import {colors} from '../config';
import {pop, prog} from '../lib/anim';
import {A, adminCard, useAdmin} from '../components/AdminShell';

const rows = [['Karim Haddad', 68, '#D92D20', ['Inactif depuis 20 jours', 'Abonnement bientôt expiré'], 138], ['Amira Jlassi', 42, '#E58A00', ['Abonnement bientôt expiré'], 999], ['Nour Ben Salah', 37, '#E58A00', ['Moins de séances ce mois-ci'], 999]] as const;

/** Rebuilt from RiskPage (risk_screen.dart); score explained as in ChurnScorer.java. */
export const AdminRisk: React.FC<{f: number}> = ({f}) => {
  const {portrait, k} = useAdmin();
  const R = 37 * k, C = 2 * Math.PI * R;
  return (
    <div style={{position: 'absolute', inset: 28, display: 'flex', flexDirection: 'column', gap: 18 * k}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 14, fontSize: 28 * k, fontWeight: 800}}><TrendingDown size={32 * k} color={colors.ember} />Membres à risque</div>
      <div style={{color: A.sub, fontSize: 19 * k, marginTop: -8}}>Score = inactivité + régularité + abonnement</div>
      {rows.map(([n, s, col, why, at], i) => {
        const inn = prog(f, 16 + i * 10, 40 + i * 10), v = prog(f, 30 + i * 12, 84 + i * 12), p = pop(f, at, 12), tap = f >= at - 8 && f < at;
        return (
          <div key={n} style={{...adminCard, borderRadius: 20, padding: `${16 * k}px ${22 * k}px`, display: 'flex', flexWrap: portrait ? 'wrap' : 'nowrap', alignItems: 'center', gap: 22, opacity: inn, transform: `translateX(${(1 - inn) * 80}px)`}}>
            <div style={{position: 'relative', width: 90 * k, height: 90 * k, flexShrink: 0}}><svg width={90 * k} height={90 * k} style={{transform: 'rotate(-90deg)'}}><circle cx={45 * k} cy={45 * k} r={R} fill="none" stroke={A.soft} strokeWidth={9 * k} /><circle cx={45 * k} cy={45 * k} r={R} fill="none" stroke={col} strokeWidth={9 * k} strokeLinecap="round" strokeDasharray={C} strokeDashoffset={C * (1 - (s / 100) * v)} /></svg><div style={{position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', fontSize: 29 * k, fontWeight: 800}}>{Math.round(s * v)}</div></div>
            <div style={{flex: 1}}><div style={{fontWeight: 700, fontSize: 23 * k}}>{n}</div><div style={{display: 'flex', flexWrap: 'wrap', gap: 9, marginTop: 9}}>{why.map((w, j) => { const q = pop(f, 60 + i * 12 + j * 10); return <span key={w} style={{background: A.soft, borderRadius: 10, padding: '6px 13px', fontSize: 17 * k, transform: `scale(${q})`, whiteSpace: 'nowrap'}}>{w}</span>; })}</div></div>
            <div style={{height: 56 * k, width: portrait ? '100%' : undefined, padding: '0 26px', borderRadius: 15, background: f >= at ? colors.success : i === 0 ? colors.amber : A.soft, color: f >= at ? '#fff' : i === 0 ? colors.ink : A.text, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 11, fontWeight: 700, fontSize: 19 * k, whiteSpace: 'nowrap', boxSizing: 'border-box', transform: `scale(${tap ? 0.92 : f >= at ? 0.85 + 0.15 * p : 1})`}}>{f >= at ? <><Check size={23} strokeWidth={3} />Relance envoyée</> : <><BellRing size={21} />Relancer</>}</div>
          </div>
        );
      })}
    </div>
  );
};
