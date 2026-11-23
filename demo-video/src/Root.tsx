import {Composition} from 'remotion';
import {FPS} from './config';
import {TOTAL} from './timeline';
import {Video} from './Video';
export const Root: React.FC = () => (
  <>
    <Composition id="Demo" component={Video} durationInFrames={TOTAL} fps={FPS} width={1920} height={1080} />
    <Composition id="DemoVertical" component={Video} durationInFrames={TOTAL} fps={FPS} width={1080} height={1920} />
  </>
);
