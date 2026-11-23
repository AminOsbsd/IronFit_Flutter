import {Html5Audio, Sequence, interpolate, staticFile} from 'remotion';
import {audio} from '../config';
import {SceneKey, TOTAL, starts} from '../timeline';

const at = (frame: number, src: string, volume: number, key: string) => <Sequence key={key} from={frame} durationInFrames={30} layout="none"><Html5Audio src={staticFile(src)} volume={volume} /></Sequence>;

export const Soundtrack: React.FC = () => {
  const base = audio.voiceover ? audio.musicVolumeUnderVoice : audio.musicVolume;
  const cuts = (Object.keys(starts) as SceneKey[]).filter((k) => k !== 'hook' && k !== 'reveal');
  const clicks = [starts.planning + 40, starts.planning + 80, starts.guided + 26, starts.guided + 71, starts.guided + 116, starts.chCoach + 48, starts.coachHome + 112, starts.coachProgram + 60, starts.coachProgram + 98, starts.coachProgram + 136, starts.coachProgram + 174, starts.coachFeedback + 126, starts.coachAttendance + 48, starts.coachAttendance + 70, starts.coachAttendance + 92, starts.coachAttendance + 114, starts.adminRequests + 72, starts.adminRequests + 118, starts.adminRisk + 132];
  const pops = [starts.aiCoach + 30, starts.aiCoach + 74, starts.planning + 88, starts.coaching + 62, starts.coachHome + 120, starts.coachFeedback + 152, starts.adminRequests + 78, starts.adminRequests + 124, starts.adminRisk + 138, starts.benefits + 15, starts.benefits + 30, starts.benefits + 45, starts.end + 45];
  return (
    <>
      <Html5Audio src={staticFile(audio.music)} volume={(f) => base * interpolate(f, [TOTAL - 30, TOTAL], [1, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'})} />
      {audio.voiceover ? <Html5Audio src={staticFile(audio.voiceover)} /> : null}
      {at(112, audio.whoosh, 0.5, 'collapse')}
      {cuts.map((k) => at(starts[k] - 12, audio.whoosh, 0.4, k))}
      {clicks.map((c) => at(c, audio.click, 0.45, `c${c}`))}
      {pops.map((c) => at(c, audio.pop, 0.35, `p${c}`))}
    </>
  );
};
