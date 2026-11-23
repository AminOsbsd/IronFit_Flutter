import {Easing, interpolate, spring} from 'remotion';
import {FPS} from '../config';

export const easeOut = Easing.bezier(0.16, 1, 0.3, 1);
export const easeInOut = Easing.bezier(0.76, 0, 0.24, 1);
const clamp = {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'} as const;

/** 0 -> 1 between two frames, eased and clamped. */
export const prog = (f: number, from: number, to: number, easing = easeOut) => interpolate(f, [from, to], [0, 1], {...clamp, easing});
export const mix = (a: number, b: number, p: number) => a + (b - a) * p;
export const range = (f: number, from: number, to: number, a: number, b: number, easing = easeOut) => mix(a, b, prog(f, from, to, easing));
/** Springy 0 -> 1 starting at a frame. */
export const pop = (f: number, at: number, damping = 13, stiffness = 130) => spring({frame: f - at, fps: FPS, config: {damping, stiffness, mass: 0.8}});
/** Keyframes: [[frame, value], ...], eased between each pair. */
export const kf = (f: number, keys: [number, number][], easing = easeInOut) =>
  keys.length === 1 ? keys[0][1] : interpolate(f, keys.map((k) => k[0]), keys.map((k) => k[1]), {...clamp, easing});
/** Gentle float, used everywhere so all motion shares one rhythm. */
export const float = (f: number, amp = 8, period = 120, phase = 0) => Math.sin((f / period) * Math.PI * 2 + phase) * amp;
export const fr = (n: number, d = 1) => n.toFixed(d).replace('.', ',');
