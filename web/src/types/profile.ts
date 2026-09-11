// Profile and Spel-DNA Types for Gameshelf Web

export type SpelDNAArchetypeID =
  | 'story_driven_explorer'
  | 'rpg_completionist'
  | 'indie_connoisseur'
  | 'cozy_adventurer'
  | 'tactical_operator'
  | 'hardcore_challenger'
  | 'grand_strategist'
  | 'retro_archivist'
  | 'squad_strategist'
  | 'casual_collector'
  | 'genre_nomad'
  | 'souls_survivor'
  | 'open_world_wanderer'
  | 'backlog_titan'
  | 'atmosphere_hunter'
  | 'pixel_purist'
  | 'zen_cultivator'
  | 'completionist_prime';

export interface SpelDNATile {
  id: string;
  category: string;
  title: string;
  subtitle: string;
  icon: string;
  accentHex: string;
  detail: string;
}

export interface SpelDNAProfile {
  archetypeID: SpelDNAArchetypeID;
  title: string;
  description: string;
  icon: string;
  accentHex: string;
  supportingStats: string[];
  tiles?: SpelDNATile[];
}

export interface AvatarPreset {
  id: string;
  icon: string;
  name: string;
  gradientColors: [string, string];
}

export interface UserProfile {
  username: string;
  age: number;
  platforms: string[];
  favoriteGenres: string[];
  playFor: string[];
  favoriteGameIDs: string[];
  avatarType: string; // 'initial' | 'preset:...' | 'custom'
  avatarCustomImage?: string; // Base64 data URL
  annualGamingGoal: number;
  targetGameIDs?: string[];
  playingMood?: string;
  gamerBio?: string;
  playstyle?: string[];
  gotyByYear?: Record<string, string>;
}
