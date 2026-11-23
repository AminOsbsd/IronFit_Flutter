import {loadFont} from '@remotion/fonts';
import {staticFile} from 'remotion';
import {colors} from './config';

export const fonts = {display: 'ArchivoVar', ui: 'RobotoVar'};
loadFont({family: fonts.display, url: staticFile('fonts/archivo-latin-standard-normal.woff2'), weight: '100 900', stretch: '62% 125%'});
loadFont({family: fonts.ui, url: staticFile('fonts/roboto-latin-wght-normal.woff2'), weight: '100 900'});

export const gradient = `linear-gradient(135deg, ${colors.amber}, ${colors.ember})`;
export const displayStyle = {fontFamily: fonts.display, fontWeight: 800, fontStretch: '118%', letterSpacing: '-0.02em', lineHeight: 1.06} as const;
export const shadow = {soft: '0 30px 80px rgba(0,0,0,.28)', card: '0 6px 18px rgba(0,0,0,.08)'};

/** Colors used inside the phone, taken from AppTheme (app_theme.dart) and memberTheme (member_design.dart). */
export const ui = {
  light: {bg: '#F6F4F0', card: '#FBFAF8', text: '#17181C', sub: '#5A5D66', line: '#E4DFD8', soft: '#EFECE7', accent: colors.amberDeep, primary: colors.amber, nav: colors.amber, radius: 16},
  dark: {bg: '#0B0B0D', card: '#18191D', text: '#F1F1F3', sub: '#A8ABB4', line: '#2F3139', soft: '#24262C', accent: colors.amber, primary: colors.amber, nav: colors.amber, radius: 16},
  member: {bg: '#F7F5F2', card: '#FDFCFA', text: '#17181C', sub: '#5A5D66', line: '#EDE8E1', soft: '#F1EDE7', accent: '#FF9800', primary: '#FF9800', nav: '#FFB23F', radius: 24},
  memberDark: {bg: '#0B0B0D', card: '#18191D', text: '#F1F1F3', sub: '#A8ABB4', line: '#2F3139', soft: '#24262C', accent: '#FF9800', primary: '#FF9800', nav: '#FFB23F', radius: 24},
};
export type Ui = typeof ui.light;
