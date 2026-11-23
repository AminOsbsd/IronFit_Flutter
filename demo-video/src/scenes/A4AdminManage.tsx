import {Activity, BadgePercent, CalendarDays, ClipboardCheck, CreditCard, Dumbbell, Megaphone, ShoppingBag, UserRound, Users, Wallet, Wrench} from 'lucide-react';
import {colors} from '../config';
import {pop, prog} from '../lib/anim';
import {A, adminCard, useAdmin} from '../components/AdminShell';

/** The module tiles of ModulesGrid (home_shell.dart + module.dart), with their real titles. */
const tiles = [[Users, 'Membres'], [UserRound, 'Coachs'], [CalendarDays, 'Séances & réservations'], [CreditCard, 'Abonnements & tarifs'], [BadgePercent, 'Promotions & offres'], [Wallet, 'Paiements'], [Wrench, 'Matériel'], [ShoppingBag, 'Boutique & stock'], [Megaphone, 'Annonces'], [Activity, 'Suivi physique'], [ClipboardCheck, 'Présences'], [Dumbbell, 'Suivis coaching']] as const;

export const AdminManage: React.FC<{f: number}> = ({f}) => {
  const {portrait, k} = useAdmin();
  const focus = Math.floor(Math.max(0, f - 70) / 15) % tiles.length;
  return (
    <div style={{position: 'absolute', inset: 26, display: 'grid', gridTemplateColumns: portrait ? '1fr 1fr' : 'repeat(4,1fr)', gridAutoRows: '1fr', gap: 18}}>
      {tiles.map(([I, t], i) => {
        const p = pop(f, 10 + i * 4, 14), on = f > 70 && i === focus ? 1 - prog(f, 70 + (f - 70 - ((f - 70) % 15)) + 8, 70 + (f - 70 - ((f - 70) % 15)) + 15) : 0;
        return <div key={t} style={{...adminCard, padding: 20 * k, display: 'flex', flexDirection: 'column', justifyContent: 'space-between', opacity: Math.min(1, p), transform: `scale(${(0.7 + 0.3 * p) * (1 + on * 0.04)})`, border: `2px solid ${on > 0.1 ? colors.amber : A.line}`}}><div style={{width: 58 * k, height: 58 * k, borderRadius: 18, background: on > 0.1 ? colors.amber : `${colors.amber}2E`, display: 'grid', placeItems: 'center'}}><I size={31 * k} color={on > 0.1 ? colors.ink : colors.amber} /></div><div style={{fontWeight: 700, fontSize: 21 * k, lineHeight: 1.2}}>{t}</div></div>;
      })}
    </div>
  );
};
