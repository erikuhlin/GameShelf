import { createClient } from '@supabase/supabase-js';
import { Game, GameCollection } from '@/types/game';

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

// Database response mapping helpers
export function mapSupabaseGame(row: any): Game {
  return {
    id: row.id,
    user_id: row.user_id,
    title: row.title,
    platforms: row.platforms || [],
    release_year: row.release_year,
    genres: row.genres || [],
    developers: row.developers || [],
    status: row.status || 'Backlog',
    rating: row.rating ? Math.round(Number(row.rating)) : undefined,
    igdb_rating: row.igdb_rating ? Math.round(Number(row.igdb_rating) * 10) / 10 : undefined,
    cover_url: row.cover_url,
    igdb_id: row.igdb_id ? Number(row.igdb_id) : undefined,
    first_release_date: row.first_release_date ? Number(row.first_release_date) : undefined,
    estimated_hours: row.estimated_hours,
    is_owned: row.is_owned ?? true,
    notes: row.notes || '',
    todos: Array.isArray(row.todos) ? row.todos : [],
    created_at: row.created_at,
    updated_at: row.updated_at,
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
