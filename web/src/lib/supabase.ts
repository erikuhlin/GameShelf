import { createClient } from '@supabase/supabase-js';
import { Game, GameCollection } from '@/types/game';
import { normalizePlayStatus, inferPlayTypes } from './statusHelper';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || 'dummy_key';

export * from './gamePayload';

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

/**
 * Normaliserar och självläker ett spelobjekt (från Supabase eller localStorage).
 * Säkerställer att ägda spel (med aktiv status, backlog, betyg, timmar, etc.) aldrig felaktigt markeras som önskelista.
 */
export function normalizeLocalGame(g: any): Game {
  const { notes: cleanNotes, meta } = unpackGameNotes(g.notes);
  const normalized = normalizePlayStatus(g.status);

  const isBacklog =
    meta.is_backlog !== undefined
      ? Boolean(meta.is_backlog)
      : g.is_backlog !== undefined
      ? Boolean(g.is_backlog)
      : normalized.is_backlog;

  // Strikt och självläkande ägarskapsberäkning:
  // 1. Spel som är under spelning, klara, pausade, avbrutna, i backlog eller har betyg/genomspelningsdata är ALLTID ägda (is_owned: true).
  const hasPlayHistoryOrActiveStatus =
    normalized.status === 'playing' ||
    normalized.status === 'completed' ||
    normalized.status === 'paused' ||
    isBacklog ||
    (g.rating !== undefined && g.rating !== null && Number(g.rating) > 0) ||
    (g.completed_year !== undefined && g.completed_year !== null) ||
    (meta.completed_year !== undefined && meta.completed_year !== null) ||
    Boolean(meta.completed_date || g.completed_date) ||
    Boolean(meta.hours_played && Number(meta.hours_played) > 0) ||
    Boolean(meta.story_progress);

  let isOwned: boolean;
  if (hasPlayHistoryOrActiveStatus) {
    isOwned = true;
  } else if (normalized.is_owned_override !== undefined) {
    isOwned = normalized.is_owned_override;
  } else if (meta.is_owned !== undefined && meta.is_owned !== null) {
    isOwned = Boolean(meta.is_owned);
  } else if (g.is_owned !== undefined && g.is_owned !== null) {
    isOwned = Boolean(g.is_owned);
  } else {
    // Standard för bibliotekspel är ägt
    isOwned = true;
  }

  const title = g.title || '';
  const genres = g.genres || [];
  const storedTypes = Array.isArray(g.play_types)
    ? g.play_types
    : Array.isArray(meta.play_types)
    ? meta.play_types
    : null;
  const playTypes =
    storedTypes && storedTypes.length > 0 && !(storedTypes.length === 1 && storedTypes[0] === 'singlePlayer')
      ? storedTypes
      : inferPlayTypes({ title, genres });

  return {
    ...g,
    id: g.id || crypto.randomUUID(),
    title,
    genres,
    platforms: g.platforms || [],
    developers: g.developers || [],
    status: normalized.status,
    is_backlog: isBacklog,
    is_owned: isOwned,
    igdb_rating: normalizeIgdbRating(g.igdb_rating),
    rating: g.rating ? Math.round(Number(g.rating)) : undefined,
    play_types: playTypes,
    notes: cleanNotes,
    todos: Array.isArray(g.todos) ? g.todos : [],
  };
}

// Database response mapping helpers
export function mapSupabaseGame(row: any): Game {
  const mapped = normalizeLocalGame(row);
  const isCompleted = mapped.status === 'completed' || (row.status as string) === 'Klar';
  const currentYear = new Date().getFullYear();
  const fallbackYear = row.updated_at
    ? new Date(row.updated_at).getFullYear()
    : row.created_at
    ? new Date(row.created_at).getFullYear()
    : currentYear;

  const { meta } = unpackGameNotes(row.notes);
  const completedYear =
    meta.completed_year !== undefined && meta.completed_year !== null
      ? Number(meta.completed_year)
      : row.completed_year !== undefined && row.completed_year !== null
      ? Number(row.completed_year)
      : null;

  const completedDate =
    meta.completed_date ||
    row.completed_date ||
    (isCompleted ? row.updated_at || row.created_at || new Date().toISOString() : null);

  return {
    ...mapped,
    id: row.id,
    user_id: row.user_id,
    cover_url: row.cover_url,
    igdb_id: row.igdb_id ? Number(row.igdb_id) : undefined,
    first_release_date: row.first_release_date ? Number(row.first_release_date) : undefined,
    estimated_hours: row.estimated_hours,
    created_at: row.created_at,
    updated_at: row.updated_at,
    completed_year: completedYear,
    completed_date: completedDate,
    last_played_date: meta.last_played_date || row.last_played_date || null,
    story_progress: meta.story_progress || row.story_progress || (isCompleted ? 'completed' : null),
    hours_played:
      meta.hours_played !== undefined && meta.hours_played !== null
        ? Number(meta.hours_played)
        : row.hours_played !== undefined && row.hours_played !== null
        ? Number(row.hours_played)
        : null,
    progress_note: meta.progress_note || row.progress_note || null,
    note_updated_at: meta.note_updated_at || row.note_updated_at || null,
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
