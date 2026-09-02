export type PlayStatus =
  | 'notStarted'
  | 'playing'
  | 'paused'
  | 'completed'
  | 'abandoned';

export type LegacyPlayStatus =
  | 'Spelar nu'
  | 'Backlog'
  | 'Pausat'
  | 'Klar'
  | 'Avbrutet'
  | 'Önskelista';

export type GamePlayType = 'singlePlayer' | 'multiplayer' | 'coOp' | 'ongoing';

export type PlayPriority = 'none' | 'low' | 'normal' | 'high' | 'nextUp';

export const PLAY_STATUSES: PlayStatus[] = [
  'playing',
  'notStarted',
  'paused',
  'completed',
  'abandoned',
];

export interface GameTodoItem {
  id: string;
  title: string;
  isDone: boolean;
}

export interface Game {
  id: string;
  user_id?: string | null;
  title: string;
  platforms: string[];
  release_year?: number | null;
  genres: string[];
  developers: string[];
  status: PlayStatus;
  rating?: number | null; // 1-10
  igdb_rating?: number | null; // 0-10
  cover_url?: string | null;
  igdb_id?: number | null;
  first_release_date?: number | null;
  estimated_hours?: number | null;
  is_owned: boolean;
  notes: string;
  summary?: string;
  todos: GameTodoItem[];
  created_at?: string;
  updated_at?: string;
  is_backlog?: boolean;
  play_types?: GamePlayType[];
  priority?: PlayPriority;
  last_played_date?: string | null;
  completed_year?: number | null;
  completed_date?: string | null;
}

export interface GameCollection {
  id: string;
  user_id?: string | null;
  name: string;
  description: string;
  game_ids: string[];
  created_at?: string;
  updated_at?: string;
}

export interface IGDBSearchResult {
  id: number;
  name: string;
  cover?: {
    id: number;
    url?: string;
    image_id?: string;
  };
  first_release_date?: number;
  genres?: Array<{ id: number; name: string }>;
  involved_companies?: Array<{
    id: number;
    developer: boolean;
    company: { id: number; name: string };
  }>;
  platforms?: Array<{ id: number; name: string }>;
  total_rating?: number;
  rating?: number;
  summary?: string;
}
