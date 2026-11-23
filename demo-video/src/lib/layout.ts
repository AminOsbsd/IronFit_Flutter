import {useVideoConfig} from 'remotion';
export const useLayout = () => {
  const {width, height} = useVideoConfig();
  const portrait = height > width;
  return {width, height, portrait, margin: portrait ? 72 : 130};
};
