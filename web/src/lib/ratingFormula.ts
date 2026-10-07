/**
 * Rating formula and Bayesian average calculation for Gameshelf
 * 
 * Formula:
 * WR = (v / (v + m)) * R + (m / (v + m)) * C
 * 
 * Where:
 * - R = Game's average rating (total_rating from IGDB, 0-100)
 * - v = Number of votes (total_rating_count from IGDB)
 * - m = Minimum votes threshold for full weight (committed value: 75)
 * - C = Global average rating across the dataset (typically ~71.5)
 */

export const DEFAULT_M_THRESHOLD = 100;
export const LOW_VOTES_WARNING_THRESHOLD = 50;
export const DEFAULT_GLOBAL_C = 79.0;
export const MIN_TOPLIST_VOTES = 150;

export interface RawGameRatingData {
  igdb_id: number;
  title: string;
  slug?: string;
  cover_url?: string | null;
  release_year?: number | null;
  first_release_date?: number | null;
  genres: string[];
  platforms: string[];
  platform_ids: number[];
  total_rating: number; // 0-100
  total_rating_count: number;
}

export interface ComputedGameRating extends RawGameRatingData {
  weighted_score: number; // 0-100 (rounded to 2 decimal places)
  overall_rank: number;
  genre_ranks: Record<string, number>;
  is_low_votes: boolean;
}

/**
 * Calculates weighted score using Bayesian average
 */
export function calculateWeightedRating(
  rating: number,
  voteCount: number,
  globalMean: number,
  mThreshold: number = DEFAULT_M_THRESHOLD
): number {
  if (voteCount <= 0 || rating <= 0) return 0;
  const v = voteCount;
  const m = mThreshold;
  const r = rating;
  const c = globalMean;

  const wr = (v / (v + m)) * r + (m / (v + m)) * c;
  return Math.round(wr * 100) / 100;
}

/**
 * Calculates global mean C and assigns weighted_score and ranks (overall and per-genre)
 */
export function computeRatingsAndRanks(
  games: RawGameRatingData[],
  mThreshold: number = DEFAULT_M_THRESHOLD,
  customGlobalC?: number
): ComputedGameRating[] {
  if (games.length === 0) return [];

  // Use configured benchmark C (default 79.0 as used by IGDB Top 100)
  const globalC = customGlobalC !== undefined ? customGlobalC : DEFAULT_GLOBAL_C;

  // 2. Compute weighted score for each game
  const computedList: Array<ComputedGameRating> = games.map((game) => {
    const weighted_score = calculateWeightedRating(
      game.total_rating,
      game.total_rating_count,
      globalC,
      mThreshold
    );
    return {
      ...game,
      weighted_score,
      overall_rank: 0,
      genre_ranks: {},
      is_low_votes: game.total_rating_count < LOW_VOTES_WARNING_THRESHOLD,
    };
  });

  // 3. Sort descending by weighted_score, secondary sort by total_rating_count
  computedList.sort((a, b) => {
    if (b.weighted_score !== a.weighted_score) {
      return b.weighted_score - a.weighted_score;
    }
    return b.total_rating_count - a.total_rating_count;
  });

  // 4. Assign overall rank (only games with >= MIN_TOPLIST_VOTES qualify for official rankings)
  let rankCounter = 1;
  for (let i = 0; i < computedList.length; i++) {
    if (computedList[i].total_rating_count >= MIN_TOPLIST_VOTES) {
      computedList[i].overall_rank = rankCounter++;
    } else {
      computedList[i].overall_rank = null as any;
    }
  }

  // 5. Assign genre-specific ranks (for top 100 in each genre)
  const genreCounters: Record<string, number> = {};
  for (const game of computedList) {
    if (game.total_rating_count >= MIN_TOPLIST_VOTES) {
      for (const genre of game.genres) {
        const currentRank = (genreCounters[genre] || 0) + 1;
        genreCounters[genre] = currentRank;
        if (currentRank <= 100) {
          game.genre_ranks[genre] = currentRank;
        }
      }
    }
  }

  return computedList;
}
