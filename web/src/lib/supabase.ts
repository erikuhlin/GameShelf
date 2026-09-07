import { createClient } from '@supabase/supabase-js';
import { Game, GameCollection } from '@/types/game';
import { normalizePlayStatus, inferPlayTypes } from './statusHelper';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'dummy_key';

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});

export function normalizeIgdbRating(val: any): number | undefined {
  if (val === null || val === undefined) return undefined;
  const num = Number(val);
  if (isNaN(num) || num <= 0) return undefined;
  // Om värdet är > 10 har det sparats på en 0-100 skala (t.ex. 84.5 -> 8.5)
  if (num > 10) {
    return Math.round((num / 10) * 10) / 10;
  }
  // Om värdet är <= 5.0 beror det oftast på den tidigare iOS-buggen där totalRating (0-100) delades med 20.0
  // (t.ex. 84 / 20 = 4.2 -> ska vara 8.4 på en 0-10 skala)
  if (num <= 5.0) {
    return Math.round((num * 2) * 10) / 10;
  }
  // Redan på en 0-10 skala (t.ex. 8.4)
  return Math.round(num * 10) / 10;
}

// Database response mapping helpers
export function mapSupabaseGame(row: any): Game {
  const normalized = normalizePlayStatus(row.status);
  const isOwned =
    normalized.is_owned_override !== undefined
      ? normalized.is_owned_override
      : (row.is_owned ?? true);

  const genres = row.genres || [];
  const title = row.title || '';
  const storedTypes = Array.isArray(row.play_types) ? row.play_types : null;
  const playTypes =
    storedTypes && storedTypes.length > 0 && !(storedTypes.length === 1 && storedTypes[0] === 'singlePlayer')
      ? storedTypes
      : inferPlayTypes({ title, genres });

  return {
    id: row.id,
    user_id: row.user_id,
    title: row.title,
    platforms: row.platforms || [],
    release_year: row.release_year,
    genres,
    developers: row.developers || [],
    status: normalized.status,
    rating: row.rating ? Math.round(Number(row.rating)) : undefined,
    igdb_rating: normalizeIgdbRating(row.igdb_rating),
    cover_url: row.cover_url,
    igdb_id: row.igdb_id ? Number(row.igdb_id) : undefined,
    first_release_date: row.first_release_date ? Number(row.first_release_date) : undefined,
    estimated_hours: row.estimated_hours,
    is_owned: isOwned,
    notes: row.notes || '',
    todos: Array.isArray(row.todos) ? row.todos : [],
    created_at: row.created_at,
    updated_at: row.updated_at,
    is_backlog: row.is_backlog !== undefined ? Boolean(row.is_backlog) : normalized.is_backlog,
    play_types: playTypes,
    last_played_date: row.last_played_date || null,
    completed_year: row.completed_year !== undefined && row.completed_year !== null ? Number(row.completed_year) : null,
    completed_date: row.completed_date || null,
    story_progress: row.story_progress || null,
    hours_played:
      row.hours_played !== undefined && row.hours_played !== null
        ? Number(row.hours_played)
        : null,
    progress_note: row.progress_note || null,
    note_updated_at: row.note_updated_at || null,
  };
}

export function mapSupabaseCollection(row: any): GameCollection {
  return {
    id: row.id,
    user_id: row.user_id,
    name: row.name,
    description: row.description || '',
    game_ids: row.game_ids || [],
    created_at: row.created_at,
    updated_at: row.updated_at,
  };
}
