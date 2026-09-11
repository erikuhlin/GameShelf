// Profile store and avatar presets for Gameshelf Web
import { UserProfile, AvatarPreset } from '@/types/profile';

export const AVATAR_PRESETS: AvatarPreset[] = [
  { id: 'preset:gamepad', icon: '🎮', name: 'Gamer', gradientColors: ['#3A1414', '#120B0B'] },
  { id: 'preset:retro_alien', icon: '👾', name: 'Retro Pixel', gradientColors: ['#1C1E3A', '#0F1018'] },
  { id: 'preset:swords', icon: '⚔️', name: 'Fantasy RPG', gradientColors: ['#3A2A14', '#141008'] },
  { id: 'preset:wizard', icon: '🧙', name: 'Mage', gradientColors: ['#2A143A', '#100818'] },
  { id: 'preset:rocket', icon: '🚀', name: 'Sci-Fi', gradientColors: ['#14283A', '#081218'] },
  { id: 'preset:ninja', icon: '🥷', name: 'Ninja', gradientColors: ['#222224', '#0A0A0C'] },
  { id: 'preset:ghost', icon: '👻', name: 'Horror', gradientColors: ['#2A1420', '#140810'] },
  { id: 'preset:coffee', icon: '☕', name: 'Cozy Life', gradientColors: ['#3A2218', '#180E0A'] },
  { id: 'preset:crown', icon: '👑', name: 'Trophy Hunter', gradientColors: ['#3A3014', '#181408'] },
  { id: 'preset:target', icon: '🎯', name: 'Tactical', gradientColors: ['#282A14', '#121408'] },
  { id: 'preset:racer', icon: '🏎️', name: 'Racer', gradientColors: ['#3A1414', '#160808'] },
  { id: 'preset:lightning', icon: '⚡', name: 'Challenger', gradientColors: ['#3A142A', '#180812'] },
];

export const DEFAULT_PLATFORMS = [
  'PlayStation 5',
  'Xbox Series X',
  'PC',
  'Nintendo Switch',
  'Steam Deck',
  'PlayStation 4',
  'Xbox One',
  'Retro / Övrigt',
];

export const DEFAULT_GENRES = [
  'RPG',
  'Action',
  'Soulslike',
  'Skräck',
  'FPS',
  'Äventyr',
  'Öppen värld',
  'Strategi',
  'Roguelike',
  'Survival',
  'Metroidvania',
  'JRPG',
  'Simulator',
  'Plattform',
  'Pussel',
  'Sport',
  'Racing',
  'Fighting',
  'Indie',
  'Cozy',
  'Hack & Slash',
  'Smygspel',
  'Berättelsedrivet',
  'MMO',
];

export const DEFAULT_PLAY_FOR = [
  'Story',
  'Utforskning',
  'Action',
  'Tävling',
  'Avkoppling',
  'Utmaning',
  'Kreativitet',
  'Samarbete & Gemenskap',
  'Djup Lore & Världsbygge',
  'Nostalgi & Retro',
  '100% Completionism',
  'Snabba sessioner',
  'Adrenalin & Puls',
  'Taktik & Problemlösning',
];

export const DEFAULT_PLAYSTYLES = [
  'Singleplayer',
  'Co-op / Samarbete',
  'PvP / Multiplayer',
  'Trophy Hunter',
  'Casual / Avslappnad',
];

export const DEFAULT_PLAYING_MOODS = [
  'Utforska nya världar',
  'Mysigt & Avkopplande',
  'Brutal bossutmaning',
  'Djup story & lore',
  'Snabba matcher & action',
  'Klurig taktik & hjärngympa',
];

const PROFILE_STORAGE_KEY = 'gameshelf_user_profile';

export const DEFAULT_PROFILE: UserProfile = {
  username: '',
  age: 25,
  platforms: ['PlayStation 5', 'PC'],
  favoriteGenres: ['RPG', 'Action', 'Skräck'],
  playFor: ['Story', 'Utforskning'],
  favoriteGameIDs: [],
  avatarType: 'initial',
  annualGamingGoal: 12,
  targetGameIDs: [],
  playingMood: 'Utforska nya världar',
  gamerBio: '',
  playstyle: ['Singleplayer'],
  gotyByYear: {},
};

export function loadUserProfile(): UserProfile {
  if (typeof window === 'undefined') {
    return DEFAULT_PROFILE;
  }

  try {
    const raw = localStorage.getItem(PROFILE_STORAGE_KEY);
    if (!raw) {
      // Fallback till tidigare sparat namn om det finns
      const legacyName = localStorage.getItem('gameshelf_profile_name');
      if (legacyName) {
        return { ...DEFAULT_PROFILE, username: legacyName };
      }
      return DEFAULT_PROFILE;
    }
    const parsed = JSON.parse(raw);
    return {
      ...DEFAULT_PROFILE,
      ...parsed,
    };
  } catch {
    return DEFAULT_PROFILE;
  }
}

export function saveUserProfile(profile: UserProfile): void {
  if (typeof window === 'undefined') return;
  try {
    localStorage.setItem(PROFILE_STORAGE_KEY, JSON.stringify(profile));
    // Håll även legacy-namnet synkat
    localStorage.setItem('gameshelf_profile_name', profile.username);
    window.dispatchEvent(new Event('gameshelf_profile_updated'));
  } catch (e) {
    console.error('Kunde inte spara profilen i localStorage:', e);
  }
}
