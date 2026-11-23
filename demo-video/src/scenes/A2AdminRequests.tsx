import {Check} from 'lucide-react';
import {colors} from '../config';
import {kf, pop, prog} from '../lib/anim';
import {A, adminCard, useAdmin} from '../components/AdminShell';
import {Avatar} from '../components/ui';

const rows = [['Amira Jlassi', 'Trimestriel', '160,00 €', 78], ['Nour Ben Salah', 'Mensuel', '60,00 €', 124], ['Karim Haddad', 'Annuel', '550,00 €', 999]] as const;

/** Rebuilt from RequestsPage (admin_screens.dart). */
export const AdminRequests: React.FC<{f: number}> = ({f}) => {
  const {portrait, k} = useAdmin();
  const done = rows.filter((r) => f >= r[3]).length;
  return (
    <div style={{position: 'absolute', inset: 28, display: 'flex', flexDirection: 'column', gap: 18 * k}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 16}}><span style={{fontSize: 28 * k, fontWeight: 800}}>Demandes d’abonnement</span><span style={{background: colors.amber, color: colors.ink, borderRadius: 12, padding: '5px 15px', fontSize: 20 * k, fontWeight: 800}}>{rows.length - done}</span></div>
      {rows.map(([n, plan, price, at], i) => {
        const inn = prog(f, 10 + i * 8, 34 + i * 8), p = pop(f, at, 12), tap = f >= at - 8 && f < at;
        return (
          <div key={n} style={{...adminCard, borderRadius: 20, border: `2px solid ${f >= at ? colors.success : A.line}`, padding: `${20 * k}px ${22 * k}px`, display: 'flex', flexDirection: portrait ? 'column' : 'row', alignItems: portrait ? 'stretch' : 'center', gap: 20, opacity: inn, transform: `translateY(${(1 - inn) * 50}px)`}}>
            <div style={{flex: 1, display: 'flex', alignItems: 'center', gap: 18}}><Avatar name={n} size={62 * k} /><div><div style={{fontWeight: 700, fontSize: 23 * k}}>{n}</div><div style={{color: A.sub, fontSize: 19 * k, marginTop: 5}}>{plan} · <b style={{color: colors.amber}}>{price}</b></div></div></div>
            {f >= at ? (
              <div style={{display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 12, color: '#35C47C', fontWeight: 700, fontSize: 20 * k, height: 60 * k, transform: `scale(${0.7 + 0.3 * p})`}}><span style={{width: 40, height: 40, borderRadius: 20, background: colors.success, display: 'grid', placeItems: 'center'}}><Check size={25} color="#fff" strokeWidth={3.4} /></span>Abonnement activé</div>
            ) : (
              <div style={{display: 'flex', gap: 14}}>
                <div style={{flex: portrait ? 1 : undefined, height: 60 * k, padding: '0 28px', borderRadius: 15, border: `1.5px solid ${A.line}`, display: 'grid', placeItems: 'center', fontWeight: 700, fontSize: 19 * k}}>Refuser</div>
                <div style={{flex: portrait ? 1 : undefined, height: 60 * k, padding: '0 28px', borderRadius: 15, background: colors.amber, color: colors.ink, display: 'grid', placeItems: 'center', fontWeight: 700, fontSize: 19 * k, whiteSpace: 'nowrap', transform: `scale(${tap ? 0.93 : 1})`}}>Valider (payé)</div>
              </div>
            )}
          </div>
        );
      })}
      <div style={{position: 'absolute', right: portrait ? 180 : 130, top: kf(f, portrait ? [[50, 900], [70, 208], [98, 208], [116, 473]] : [[50, 560], [70, 84], [98, 84], [116, 208]]), width: 46, height: 46, borderRadius: 23, background: 'rgba(255,255,255,.35)', border: '2px solid rgba(255,255,255,.85)', opacity: kf(f, [[48, 0], [56, 1], [128, 1], [136, 0]])}} />
    </div>
  );
};
