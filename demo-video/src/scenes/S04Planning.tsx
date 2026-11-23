import {Bot, CalendarDays, ChevronLeft, ChevronRight, Info, RefreshCw, Search} from 'lucide-react';
import {Img, staticFile} from 'remotion';
import {colors} from '../config';
import {easeInOut, kf, mix, pop, prog} from '../lib/anim';
import {ui} from '../theme';
import {Box, Card, MemberArt, NavBar, Screen, Title} from '../components/ui';

const days: [string, string][] = [['Lun', '2 cours'], ['Mar', '2 cours'], ['Mer', '1 cours'], ['Jeu', '2 cours'], ['Ven', '1 cours'], ['Sam', '1 cours']];
const SCROLL = 96;

/** Rebuilt from planning_screen.dart and MemberSessionCard (member_design.dart). */
export const PlanningScreen: React.FC<{f: number}> = ({f}) => {
  const c = ui.member;
  const sel = prog(f, 30, 42), tap = f >= 84 && f < 94, booked = f >= 92, done = pop(f, 92, 14);
  const scroll = SCROLL * prog(f, 48, 66, easeInOut);
  const fab = 1 - prog(f, 46, 54);
  const bar = mix(8 / 12, 9 / 12, prog(f, 94, 114));
  const grow = prog(f, 92, 106);
  const cx = kf(f, [[12, 200], [28, 117], [46, 117], [64, 220], [82, 304]]), cy = kf(f, [[12, 620], [28, 360], [46, 420], [64, 640], [82, 516]]);
  const co = kf(f, [[10, 0], [18, 1], [96, 1], [104, 0]]);
  return (
    <Screen c={c}>
      <div style={{position: 'absolute', left: 0, right: 0, top: 46, zIndex: 2, background: c.bg, height: 54}}><Title>Planning</Title><Box x={288} y={14}><CalendarDays size={23} color={c.text} /></Box><Box x={338} y={14}><RefreshCw size={22} color={c.text} /></Box></div>
      <Box x={0} y={100} w={390} h={660} style={{overflow: 'hidden'}}>
        <div style={{position: 'absolute', left: 0, top: -scroll, width: 390, height: 760}}>
          <Box x={16} y={10} w={270}><div style={{fontSize: 21, fontWeight: 700}}>Trouvez votre rythme</div><div style={{fontSize: 15, color: c.sub, marginTop: 5}}>Réservez, participez, progressez.</div></Box>
          <Box x={286} y={2}><Img src={staticFile('brand/member-fitness.png')} style={{width: 90}} /></Box>
          <Box x={16} y={74} w={358} h={50} style={{border: `1px solid ${c.line}`, background: '#fff', borderRadius: 14, display: 'flex', alignItems: 'center', gap: 10, padding: '0 14px', color: c.sub, fontSize: 15}}><Search size={19} />Rechercher un cours ou un coach</Box>
          <Box x={16} y={136} h={34} style={{border: `1px solid ${c.line}`, borderRadius: 10, padding: '0 14px', display: 'flex', alignItems: 'center', fontSize: 14, fontWeight: 500}}>Mes réservations</Box>
          <Box x={12} y={180} w={366} h={34} style={{display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: 15}}><ChevronLeft size={22} /><span>Semaine du 2026-11-23</span><ChevronRight size={22} /></Box>
          <Box x={16} y={222} w={500} style={{display: 'flex', gap: 8}}>
            {days.map(([d, n], i) => {
              const on = (i === 1 ? sel : i === 0 ? 1 - sel : 0) > 0.5;
              return <div key={d} style={{width: 62, height: 64, flexShrink: 0, boxSizing: 'border-box', borderRadius: 16, border: `${i === 0 && !on ? 1.5 : 1}px solid ${on ? colors.amber : i === 0 ? c.primary : c.line}`, background: on ? colors.amber : c.card, color: on ? colors.ink : c.text, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4, transform: `scale(${i === 1 ? 1 + 0.08 * Math.sin(sel * Math.PI) : 1})`}}><span style={{fontWeight: 800, fontSize: 15}}>{d}</span><span style={{fontSize: 12, opacity: 0.85}}>{n}</span></div>;
            })}
          </Box>
          <Box x={18} y={300} style={{display: 'flex', alignItems: 'center', gap: 10}}><div style={{width: 4, height: 18, borderRadius: 2, background: colors.amber}} /><b style={{fontSize: 17, fontWeight: 600}}>{sel > 0.5 ? 'Mardi · 2026-11-24' : 'Lundi · 2026-11-23'}</b></Box>
          {/* Card: 214 px before booking, 286 px once the confirmation appears. */}
          <Box x={16} y={332} w={358} h={214 + 72 * grow} style={{opacity: prog(f, 8, 15)}}>
            <Card c={c} style={{height: '100%', position: 'relative'}}>
              <div style={{display: 'flex', gap: 14}}><MemberArt c={c} /><div style={{opacity: 0.2 + 0.8 * Math.abs(2 * sel - 1)}}><div style={{fontWeight: 800, fontSize: 19}}>{sel > 0.5 ? 'Yoga' : 'Musculation'}</div><div style={{fontSize: 15, marginTop: 8}}>{sel > 0.5 ? '2026-11-24 · 19:00' : '2026-11-23 · 18:00'}</div><div style={{color: c.sub, fontSize: 14, marginTop: 3}}>Coach : {sel > 0.5 ? 'Leila' : 'Sami Ben Ali'}</div></div></div>
              <div style={{height: 6, borderRadius: 4, background: '#FFE8CA', marginTop: 14}}><div style={{height: 6, borderRadius: 4, width: `${bar * 100}%`, background: c.primary}} /></div>
              <div style={{fontSize: 14, color: c.sub, marginTop: 6}}>{f > 98 ? 9 : 8}/12 places</div>
              {booked ? <div style={{position: 'absolute', left: 16, right: 16, top: 149, height: 60, boxSizing: 'border-box', borderRadius: 16, background: '#9653001a', color: '#965300', display: 'flex', gap: 9, padding: 11, fontSize: 14, lineHeight: 1.3, transform: `scale(${0.85 + 0.15 * done})`, opacity: Math.min(1, done), visibility: f >= 168 ? 'hidden' : 'visible'}}><Info size={20} style={{flexShrink: 0}} /><span>Votre présence sera vérifiée par votre coach après le cours.</span></div> : null}
              <div style={{position: 'absolute', right: 16, bottom: 16, height: 46, width: 112, boxSizing: 'border-box', borderRadius: 23, background: booked ? 'transparent' : c.primary, border: booked ? `1.5px solid ${c.sub}66` : 'none', color: booked ? colors.amberText : colors.ink, fontWeight: 600, fontSize: 16, display: 'grid', placeItems: 'center', transform: `scale(${tap ? 0.92 : 1})`}}>{booked ? 'Annuler' : 'Réserver'}</div>
            </Card>
          </Box>
          <Box x={16} y={560 + 72 * grow} w={358} h={180} style={{opacity: prog(f, 12, 22)}}><Card c={c} style={{height: '100%', display: 'flex', gap: 14}}><MemberArt c={c} /><div><div style={{fontWeight: 800, fontSize: 19}}>Stretching</div><div style={{fontSize: 15, marginTop: 8}}>{sel > 0.5 ? '2026-11-24' : '2026-11-23'} · 20:15</div><div style={{color: c.sub, fontSize: 14, marginTop: 3}}>Coach : Leila</div></div></Card></Box>
        </div>
      </Box>
      <NavBar c={c} active={1} />
      <Box x={318} y={688} w={56} h={56} style={{borderRadius: 28, background: c.primary, display: 'grid', placeItems: 'center', boxShadow: '0 8px 20px rgba(0,0,0,.28)', transform: `scale(${fab})`, opacity: fab}}><Bot size={28} color={colors.ink} /></Box>
      <Box x={cx - 24} y={cy - 24} w={48} h={48} style={{borderRadius: 24, background: 'rgba(23,24,28,.22)', border: '2px solid rgba(23,24,28,.5)', opacity: co, transform: `scale(${tap || (f >= 28 && f < 36) ? 0.7 : 1})`}} />
    </Screen>
  );
};
