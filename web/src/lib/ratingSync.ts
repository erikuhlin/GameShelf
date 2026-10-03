import { queryIGDB } from './igdb-server';
import { createClient } from '@supabase/supabase-js';
import { computeRatingsAndRanks, RawGameRatingData, DEFAULT_M_THRESHOLD } from './ratingFormula';

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

interface SyncOptions {
  batchSize?: number;
  maxBatches?: number;
  minVoteCount?: number;
  mThreshold?: number;
  supabaseClient?: any;
  onProgress?: (message: string) => void;
}

export async function syncIGDBRatings(options: SyncOptions = {}) {
  const {
    batchSize = 500,
    maxBatches = 0, // 0 = unlimited / until exhaust
    minVoteCount = 1,
    mThreshold = DEFAULT_M_THRESHOLD,
    onProgress = console.log,
  } = options;

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'http://127.0.0.1:54321';
  const supabaseKey =
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
    'dummy_key';

  if (typeof globalThis.WebSocket === 'undefined') {
    // @ts-ignore
    globalThis.WebSocket = class DummyWebSocket {};
  }

  const supabase =
    options.supabaseClient ||
    createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

  onProgress(`🚀 Starting IGDB rating sync (batchSize: ${batchSize}, minVoteCount: ${minVoteCount}, m: ${mThreshold})`);

  let lastId = 0;
  let batchIndex = 0;
  const rawGames: RawGameRatingData[] = [];

  // 1. Fetch games from IGDB with cursor pagination (id > lastId)
  while (true) {
    batchIndex++;
    if (maxBatches > 0 && batchIndex > maxBatches) {
      onProgress(`Reached max batches limit (${maxBatches}). Stopping fetch.`);
      break;
    }

    const whereClause = `game_type = 0 & rating_count >= ${minVoteCount} & id > ${lastId}`;
    const query = `
      fields id, name, slug, cover.image_id, first_release_date, genres.name, platforms.name, platforms.id, rating, rating_count, total_rating, total_rating_count;
      where ${whereClause};
      sort id asc;
      limit ${batchSize};
    `;

    try {
      const igdbData: any[] = await queryIGDB('games', query);

      if (!igdbData || igdbData.length === 0) {
        onProgress(`Batch ${batchIndex}: No more games returned. Fetch complete.`);
        break;
      }

      for (const item of igdbData) {
        const coverUrl = item.cover?.image_id
          ? `https://images.igdb.com/igdb/image/upload/t_cover_big/${item.cover.image_id}.jpg`
          : null;

        const releaseYear = item.first_release_date
          ? new Date(item.first_release_date * 1000).getUTCFullYear()
          : null;

        const genres = Array.isArray(item.genres)
          ? item.genres.map((g: any) => g.name).filter(Boolean)
          : [];

        const platforms = Array.isArray(item.platforms)
          ? item.platforms.map((p: any) => p.name).filter(Boolean)
          : [];

        const platform_ids = Array.isArray(item.platforms)
          ? item.platforms.map((p: any) => Number(p.id)).filter((id: number) => !isNaN(id))
          : [];

        // IGDB Top 100 uses User Rating (rating, rating_count)
        const userRating = Number(item.rating) || Number(item.total_rating) || 0;
        const userVoteCount = Number(item.rating_count) || Number(item.total_rating_count) || 0;

        rawGames.push({
          igdb_id: item.id,
          title: item.name,
          slug: item.slug,
          cover_url: coverUrl,
          release_year: releaseYear,
          first_release_date: item.first_release_date || null,
          genres,
          platforms,
          platform_ids,
          total_rating: userRating,
          total_rating_count: userVoteCount,
        });

        lastId = item.id;
      }

      onProgress(
        `Batch ${batchIndex}: Fetched ${igdbData.length} games (total so far: ${rawGames.length}, lastId: ${lastId})`
      );

      if (igdbData.length < batchSize) {
        onProgress(`Last batch was partial (${igdbData.length} < ${batchSize}). Fetch complete.`);
        break;
      }

      // IGDB rate limit is ~4 requests/second, so delay 280ms between requests
      await delay(280);
    } catch (err: any) {
      onProgress(`⚠️ Error in batch ${batchIndex}: ${err.message}`);
      throw err;
    }
  }

  if (rawGames.length === 0) {
    onProgress('No games found to process.');
    return { count: 0, globalC: 0 };
  }

  // 2. Compute Bayesian average weighted scores and ranks
  onProgress(`📊 Computing weighted ratings & rankings for ${rawGames.length} games...`);
  const computed = computeRatingsAndRanks(rawGames, mThreshold);

  // 3. Upsert to Supabase in chunks of 500
  onProgress(`💾 Saving to Supabase game_ratings table...`);
  const upsertChunkSize = 500;
  for (let i = 0; i < computed.length; i += upsertChunkSize) {
    const chunk = computed.slice(i, i + upsertChunkSize).map((g) => ({
      igdb_id: g.igdb_id,
      title: g.title,
      slug: g.slug || null,
      cover_url: g.cover_url || null,
      release_year: g.release_year || null,
      first_release_date: g.first_release_date || null,
      genres: g.genres,
      platforms: g.platforms,
      platform_ids: g.platform_ids,
      total_rating: g.total_rating,
      total_rating_count: g.total_rating_count,
      weighted_score: g.weighted_score,
      overall_rank: g.overall_rank,
      genre_ranks: g.genre_ranks,
      fetched_at: new Date().toISOString(),
      computed_at: new Date().toISOString(),
    }));

    const { error } = await supabase.from('game_ratings').upsert(chunk, {
      onConflict: 'igdb_id',
    });

    if (error) {
      onProgress(`❌ Error upserting chunk ${i / upsertChunkSize + 1}: ${error.message}`);
      throw error;
    }

    onProgress(
      `Saved rows ${i + 1} - ${Math.min(i + upsertChunkSize, computed.length)} / ${computed.length}`
    );
  }

  const top5 = computed.slice(0, 5).map((g) => ({
    rank: g.overall_rank,
    title: g.title,
    rating: g.total_rating,
    votes: g.total_rating_count,
    weighted: g.weighted_score,
  }));

  onProgress(`✅ Completed rating sync! Total games: ${computed.length}`);
  return {
    count: computed.length,
    top5,
  };
}
