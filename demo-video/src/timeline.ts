import {durations} from './config';
export type SceneKey = keyof typeof durations;
let t = 0;
export const starts = {} as Record<SceneKey, number>;
for (const k of Object.keys(durations) as SceneKey[]) {
  starts[k] = t;
  t += durations[k];
}
export const TOTAL = t;
export const endOf = (k: SceneKey) => starts[k] + durations[k];
