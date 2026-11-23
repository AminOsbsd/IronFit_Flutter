/**
 * Everything you are likely to edit: copy, colors, durations, audio.
 * Durations are in frames (30 fps). The music runs at 120 BPM, so 15 frames = 1 beat:
 * keep durations multiples of 15 to stay on the beat.
 */
export const FPS = 30;
export const BEAT = 15;

export const colors = {
  ink: '#0B0B0D',
  charcoal: '#17181C',
  graphite: '#2A2B30',
  amber: '#FFB547',
  amberDeep: '#E08A00',
  amberText: '#A35C00',
  ember: '#FF6B2C',
  paper: '#F6F4F0',
  white: '#FFFFFF',
  success: '#1E9E5A',
};

export const durations = {
  hook: 150,
  reveal: 150,
  // Member
  chMember: 90,
  aiCoach: 180,
  planning: 180,
  guided: 180,
  progress: 180,
  coaching: 180,
  // Coach
  chCoach: 120,
  coachHome: 210,
  coachProgram: 270,
  coachFeedback: 210,
  coachAttendance: 210,
  // Administrator
  chAdmin: 120,
  adminDash: 240,
  adminRequests: 210,
  adminRisk: 240,
  adminManage: 180,
  // Closing
  benefits: 150,
  end: 150,
};

/** Replace the files in public/audio (same names) or change the paths here. */
export const audio = {
  music: 'audio/music.wav',
  whoosh: 'audio/whoosh.wav',
  click: 'audio/click.wav',
  pop: 'audio/pop.wav',
  /** Optional: put a narration in public/audio and set e.g. 'audio/voiceover.wav'. Music is then lowered. */
  voiceover: null as string | null,
  musicVolume: 0.8,
  musicVolumeUnderVoice: 0.28,
};

export const copy = {
  hook: ['Trop d’applis.', 'Trop d’excuses.', 'Zéro progrès ?'],
  reveal: { line1: 'Votre salle. Votre coach.', line2: 'Une seule app.' },
  aiCoach: {
    eyebrow: 'AI Coach',
    title: ['Un coach IA', 'qui vous connaît'],
    sub: 'Des conseils basés sur vos vraies séances.',
    chips: ['Vos séances', 'Vos mesures'],
  },
  planning: {
    eyebrow: 'Planning',
    title: ['Réservez', 'en un geste'],
    sub: 'Vos cours, à la date de votre choix.',
    chips: ['Places en direct', 'Chaque semaine'],
  },
  guided: {
    eyebrow: 'Séance guidée',
    title: ['Série', 'après série'],
    sub: 'Minuteur, répétitions, charges réelles.',
    chips: ['Repos chronométré', 'Reprise possible'],
  },
  progress: {
    eyebrow: 'Ma progression',
    title: ['Voyez', 'la différence'],
    sub: 'Poids, masse grasse et meilleures charges.',
    chips: ['Poids', 'Meilleures charges'],
  },
  coaching: {
    eyebrow: 'Coaching',
    title: ['Un vrai coach', 'à vos côtés'],
    sub: 'Programmes et retours personnalisés.',
    chips: ['Programmes', 'Commentaires'],
  },
  chMember: { title: ['Côté membre'], sub: 'S’entraîner, réserver, progresser.' },
  chCoach: {
    eyebrow: 'Côté coach',
    title: ['Un compte,', 'deux espaces'],
    sub: 'Son entraînement. Et celui de ses clients.',
  },
  coachHome: {
    eyebrow: 'Espace coach',
    title: ['Vos clients,', 'en un regard'],
    sub: 'Suivis, séances à commenter, demandes.',
    chips: ['Demandes de suivi', 'À commenter'],
  },
  coachProgram: {
    eyebrow: 'Programmes',
    title: ['Des programmes', 'sur mesure'],
    sub: 'Exercices, séries, charges et repos.',
    chips: ['Pour un client', 'Modifiable'],
  },
  coachFeedback: {
    eyebrow: 'Séances',
    title: ['Commentez', 'chaque séance'],
    sub: 'Le membre reçoit une notification.',
    chips: ['Difficulté ressentie', 'Notification'],
  },
  coachAttendance: {
    eyebrow: 'Présences',
    title: ['Pointez', 'vos cours'],
    sub: 'Présent, absent ou à vérifier.',
    chips: ['Cours du jour', 'Par date'],
  },
  chAdmin: {
    eyebrow: 'Côté administration',
    title: ['Toute la salle,', 'une seule vue'],
    sub: 'Pilotage, abonnements, fidélisation.',
  },
  adminDash: {
    eyebrow: 'Tableau de bord',
    title: ['Pilotez', 'votre salle'],
    sub: 'Membres, abonnements, séances, présences.',
  },
  adminRequests: {
    eyebrow: 'Abonnements',
    title: ['Validez', 'les demandes'],
    sub: 'Paiement enregistré, accès activé.',
  },
  adminRisk: {
    eyebrow: 'Fidélisation',
    title: ['Retenez', 'vos membres'],
    sub: 'Un score expliqué, une relance en un clic.',
  },
  adminManage: {
    eyebrow: 'Administration',
    title: ['Tout gérer', 'au même endroit'],
    sub: 'Comptes, cours, tarifs, stock, annonces.',
  },
  benefits: {
    title: ['Pensée pour', 'toute la salle.'],
    items: [
      { value: 3, label: 'espaces : membre, coach, admin' },
      { value: 1, label: 'seule app, une seule connexion' },
      { value: 'IA', label: 'intégrée, sur vos données' },
    ],
  },
  end: { cta: 'Prenez le contrôle.', roles: ['Membre', 'Coach', 'Admin'] },
};

/** Fictional demo data shown inside the mockups. */
export const demo = {
  member: 'Youssef',
  coach: 'Sami Ben Ali',
  question: 'Que faire à ma prochaine séance ?',
  reply: [
    'Bravo pour ta régularité !',
    '- Squat : 4 × 6-8 à 72,5 kg',
    '- Développé couché : 60 kg',
    '- Repos : 2 min',
    'Vise un RPE de 7 à 8 et note ta séance.',
  ],
  weights: [82.5, 81.9, 81.4, 80.6],
  comment: 'Bravo ! On augmente le squat de 2,5 kg la prochaine fois.',
  kpis: [
    { label: 'Membres', value: 128 },
    { label: 'Abonnements actifs', value: 96 },
    { label: 'Séances (7 j)', value: 214 },
    { label: 'Présences aujourd’hui', value: 37 },
  ],
  demoLabel: 'Données de démonstration',
};
