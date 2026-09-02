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
  | 'genre_nomad';

export interface SpelDNAProfile {
  archetypeID: SpelDNAArchetypeID;
  title: string;
  description: string;
  icon: string;
  accentHex: string;
  supportingStats: string[];
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
}
