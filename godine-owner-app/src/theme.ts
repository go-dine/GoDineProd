// Go Dine Theme — matches web dashboard CSS variables exactly
export const COLORS = {
  bg: '#050505',
  surface1: '#0e0e0e',
  surface2: '#151515',
  surface3: '#1c1c1c',

  lime: '#b6ff2a',
  limeAlpha08: 'rgba(182,255,42,0.08)',
  limeAlpha18: 'rgba(182,255,42,0.18)',
  limeAlpha30: 'rgba(182,255,42,0.30)',

  white: '#f0f0ec',
  muted: '#6b6b67',
  border: 'rgba(255,255,255,0.07)',
  borderLight: 'rgba(255,255,255,0.15)',

  red: '#ff4444',
  redAlpha: 'rgba(255,68,68,0.1)',
  redBorder: 'rgba(255,68,68,0.2)',

  green: '#4ade80',
  greenAlpha: 'rgba(74,222,128,0.12)',

  amber: '#fbbf24',
  amberAlpha: 'rgba(251,191,36,0.12)',
};

export const RADIUS = {
  sm: 10,
  md: 16,
  lg: 24,
  full: 100,
};

export const SPACING = {
  xs: 4,
  sm: 8,
  md: 14,
  lg: 20,
  xl: 28,
  xxl: 40,
};

export const FONTS = {
  regular: { fontWeight: '400' as const },
  medium: { fontWeight: '500' as const },
  semibold: { fontWeight: '600' as const },
  bold: { fontWeight: '700' as const },
  extrabold: { fontWeight: '800' as const },
};
