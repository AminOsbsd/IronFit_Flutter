import {Activity, Bell, Bot, CalendarCheck, CalendarDays, ClipboardCheck, CreditCard, Dumbbell, Gauge, HeartHandshake, LayoutGrid, MessageSquareText, Pencil, RotateCcw, Scale, ShieldCheck, Sparkles, Ticket, Timer, TrendingUp, Trophy, UserPlus, UserRound, Users} from 'lucide-react';
import type {LucideIcon} from 'lucide-react';
import {useEffect, useState} from 'react';
import {AbsoluteFill, Sequence, continueRender, delayRender} from 'remotion';
import {copy, durations} from './config';
import {Background} from './components/Background';
import {Callout} from './components/Callout';
import {Device, phoneSide, usePhonePos} from './components/Device';
import {FeatureText} from './components/FeatureText';
import {Soundtrack} from './components/Soundtrack';
import {useLayout} from './lib/layout';
import {Hook} from './scenes/S01Hook';
import {Reveal} from './scenes/S02Reveal';
import {MemberChapter} from './scenes/C0Chapters';
import {Benefits} from './scenes/S09Benefits';
import {End} from './scenes/S10End';
import {SceneKey, starts} from './timeline';
import {fonts} from './theme';

type PhoneKey = 'aiCoach' | 'planning' | 'guided' | 'progress' | 'coaching' | 'chCoach' | 'coachHome' | 'coachProgram' | 'coachFeedback' | 'coachAttendance';
const phone: {key: PhoneKey; icon: LucideIcon; chips?: LucideIcon[]}[] = [
  {key: 'aiCoach', icon: Bot, chips: [Dumbbell, Activity]},
  {key: 'planning', icon: CalendarDays, chips: [Ticket, CalendarDays]},
  {key: 'guided', icon: Timer, chips: [Timer, RotateCcw]},
  {key: 'progress', icon: TrendingUp, chips: [Scale, Trophy]},
  {key: 'coaching', icon: UserRound, chips: [Sparkles, MessageSquareText]},
  {key: 'chCoach', icon: Users},
  {key: 'coachHome', icon: HeartHandshake, chips: [UserPlus, MessageSquareText]},
  {key: 'coachProgram', icon: ClipboardCheck, chips: [UserRound, Pencil]},
  {key: 'coachFeedback', icon: MessageSquareText, chips: [Gauge, Bell]},
  {key: 'coachAttendance', icon: CalendarCheck, chips: [CalendarDays, ClipboardCheck]},
];
const admin: {key: 'chAdmin' | 'adminDash' | 'adminRequests' | 'adminRisk' | 'adminManage'; icon: LucideIcon}[] = [
  {key: 'chAdmin', icon: ShieldCheck},
  {key: 'adminDash', icon: Gauge},
  {key: 'adminRequests', icon: CreditCard},
  {key: 'adminRisk', icon: HeartHandshake},
  {key: 'adminManage', icon: LayoutGrid},
];

const Features: React.FC = () => {
  const {portrait} = useLayout();
  const pos = usePhonePos();
  return (
    <>
      {phone.map(({key, icon}, i) => <FeatureText key={key} scene={key} icon={icon} side={phoneSide(i) === 'right' ? 'left' : 'right'} eyebrow={copy[key].eyebrow} title={copy[key].title} sub={copy[key].sub} />)}
      {admin.map(({key, icon}) => <FeatureText key={key} scene={key} icon={icon} side="top" eyebrow={copy[key].eyebrow} title={portrait ? copy[key].title : [copy[key].title.join(' ')]} sub={copy[key].sub} />)}
      <Device />
      {phone.map(({key, chips}, n) => {
        const outer = phoneSide(n) === 'right' ? 1 : -1;
        const texts = (copy[key] as {chips?: string[]}).chips ?? [];
        return (chips ?? []).map((icon, i) => <Callout key={key + i} scene={key} icon={icon} text={texts[i]} cx={pos.x} cy={pos.y} x={portrait ? (i ? 345 : -350) : i ? outer * 196 : outer * -206} y={portrait ? (i ? 500 : -548) : i ? 372 : -350} at={30 + i * 15} phase={i * 2} />);
      })}
    </>
  );
};

/** Waits for the brand fonts so text is measured and drawn correctly on every frame. */
const useFonts = () => {
  const [ready, setReady] = useState(false);
  const [handle] = useState(() => delayRender('fonts'));
  useEffect(() => {
    Promise.all([document.fonts.load(`800 40px ${fonts.display}`), document.fonts.load(`400 20px ${fonts.ui}`)]).then(() => { setReady(true); continueRender(handle); });
  }, [handle]);
  return ready;
};

export const Video: React.FC = () => {
  const ready = useFonts();
  if (!ready) return null;
  const seq = (k: SceneKey, node: React.ReactNode) => <Sequence name={k} from={starts[k]} durationInFrames={durations[k]}>{node}</Sequence>;
  return (
    <AbsoluteFill style={{background: '#0B0B0D'}}>
      <Background />
      {seq('hook', <Hook />)}
      {seq('reveal', <Reveal />)}
      {seq('chMember', <MemberChapter />)}
      <Features />
      {seq('benefits', <Benefits />)}
      {seq('end', <End />)}
      <Soundtrack />
    </AbsoluteFill>
  );
};
