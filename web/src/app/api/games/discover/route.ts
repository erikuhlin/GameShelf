import { NextRequest, NextResponse } from 'next/server';
import { queryIGDB } from '@/lib/igdb-server';

export const revalidate = 300; // 5 minuters edge cache

// In-memory cache for ultra-fast response times & rate-limit protection
const DISCOVER_CACHE = new Map<string, { results: any[]; expiresAt: number }>();
const CACHE_TTL_MS = 15 * 60 * 1000; // 15 minuter

const GENRE_CLAUSES: Record<string, string> = {
  'Action': 'genres = (25, 4, 5, 31)',
  'Role-playing (RPG)': 'genres = (12)',
  'RPG': 'genres = (12)',
  'Adventure': 'genres = (31)',
  'Äventyr': 'genres = (31)',
  'Shooter': 'genres = (5, 24)',
  'Skjutspel': 'genres = (5, 24)',
  'Indie': 'genres = (32)',
  'Strategy': 'genres = (15, 11, 16, 24)',
  'Strategi': 'genres = (15, 11, 16, 24)',
  'Platform': 'genres = (8)',
  'Plattform': 'genres = (8)',
  'Racing': 'genres = (10)',
  'Fighting': 'genres = (4)',
  'Horror': 'themes = (19)',
  'Skräck': 'themes = (19)',
  'Simulator': 'genres = (13)',
  'Puzzle': 'genres = (9)',
  'Pussel': 'genres = (9)',
  'Sport': 'genres = (14)',
  'Arcade': 'genres = (33)',
  'Arkad': 'genres = (33)',
};

const PLATFORM_MAP: Record<string, number[]> = {
  ps5: [167, 48], // PS5 & PS4
  playstation: [167, 48],
  pc: [6], // PC Windows
  switch: [130], // Nintendo Switch
  nintendo: [130],
  xbox: [169, 49], // Xbox Series X|S & Xbox One
};

function formatGameCover(cover: any): string | null {
  if (!cover) return null;
  if (cover.url) {
    let rawUrl = cover.url;
    if (rawUrl.startsWith('//')) {
      rawUrl = 'https:' + rawUrl;
    }
    return rawUrl.replace('/t_thumb/', '/t_cover_big/');
  }
  if (cover.image_id) {
    return `https://images.igdb.com/igdb/image/upload/t_cover_big/${cover.image_id}.jpg`;
  }
  return null;
}

function isDlcOrExpansion(game: any): boolean {
  if (game.parent_game) return true;
  // IGDB game_type: 1 (DLC), 2 (Expansion), 3 (Bundle), 4 (Standalone Expansion), etc.
  if (game.game_type === 1 || game.game_type === 2) return true;
  // IGDB category: 1 (DLC), 2 (Expansion), 4 (Standalone expansion), 8 (Remake), 9 (Remaster), etc.
  if ([1, 2, 4].includes(game.category)) return true;
  return false;
}

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const category = searchParams.get('category') || 'trending';
  const genreParam = searchParams.get('genre')?.trim();
  const sortParam = searchParams.get('sort') || 'popularity';
  const eraParam = searchParams.get('era') || 'recent';
  const platformParam = searchParams.get('platform')?.toLowerCase() || 'all';
  const startDateParam = searchParams.get('start_date');
  const endDateParam = searchParams.get('end_date');
  const isHypedParam = searchParams.get('is_hyped') === 'true';
  const minHypeParam = searchParams.get('min_hype') ? Number(searchParams.get('min_hype')) : null;
  const limitParam = Math.min(Number(searchParams.get('limit')) || (category === 'upcoming' ? 60 : 25), 200);
  const excludeIdsParam = searchParams.get('exclude_ids') || '';
  const excludeIds = new Set(excludeIdsParam.split(',').map((id) => Number(id.trim())).filter(Boolean));

  const nowSeconds = Math.floor(Date.now() / 1000);
  const now = new Date();
  const todayStartTs = Math.floor(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0) / 1000);
  const cacheKey = `${category}_${genreParam || ''}_${sortParam}_${eraParam}_${platformParam}_${startDateParam || ''}_${endDateParam || ''}_${isHypedParam}_${limitParam}`;

  // 1. Svara omedelbart om cachat i minnet
  const cached = DISCOVER_CACHE.get(cacheKey);
  if (cached && cached.expiresAt > Date.now() && cached.results.length > 0) {
    const filtered = cached.results.filter((game: any) => !excludeIds.has(game.igdb_id));
    return NextResponse.json(
      { results: filtered },
      {
        headers: {
          'Cache-Control': 'public, s-maxage=900, stale-while-revalidate=1800',
        },
      }
    );
  }

  try {
    let results: any[] = [];

    // =========================================================================
    // 1. TRENDING (Äkta IGDB PopScore från popularity_primitives – identiskt med iOS)
    // =========================================================================
    if (category === 'trending' && !genreParam) {
      try {
        // Hämta toppsäljare (9), mest önskade kommande (10), Twitch (34), sökbesök (1), 24h-spelare (5), vill spela (2)
        const primQuery = `
          fields game_id, value, popularity_type;
          where popularity_type = (9, 10, 34, 1, 5, 2);
          sort value desc;
          limit 300;
        `;
        const primitives: any[] = await queryIGDB('popularity_primitives', primQuery);

        if (Array.isArray(primitives) && primitives.length > 0) {
          // Gruppera per typ för normaliserad rankningspoäng
          const groupedByType = new Map<number, any[]>();
          for (const p of primitives) {
            const list = groupedByType.get(p.popularity_type) || [];
            list.push(p);
            groupedByType.set(p.popularity_type, list);
          }

          interface MetaItem {
            score: number;
            bestType: number;
            bestTypeValue: number;
          }
          const metaMap = new Map<number, MetaItem>();

          for (const [type, items] of Array.from(groupedByType.entries())) {
            // Sortera efter värde
            items.sort((a, b) => (b.value || 0) - (a.value || 0));

            const typeWeight =
              type === 9 ? 1.6 : // Globala toppsäljare just nu
              type === 10 ? 1.5 : // Mest önskade kommande
              type === 34 ? 1.4 : // Twitch 24h tittartid
              type === 1 ? 1.2 :  // IGDB sökningar/besök
              type === 2 ? 1.1 :  // Vill spela
              type === 5 ? 0.8 :  // 24h peak samtidiga spelare
              1.0;

            const topSlice = items.slice(0, 50);
            for (let rank = 0; rank < topSlice.length; rank++) {
              const p = topSlice[rank];
              const rankScore = Math.max(10, 100 - rank * 2);
              const weightedScore = rankScore * typeWeight;

              let meta = metaMap.get(p.game_id);
              if (!meta) {
                meta = { score: 0, bestType: type, bestTypeValue: 0 };
              }
              meta.score += weightedScore;
              if (weightedScore > meta.bestTypeValue) {
                meta.bestTypeValue = weightedScore;
                meta.bestType = type;
              }
              metaMap.set(p.game_id, meta);
            }
          }

          // Ta topp 100 ID:n sorterade efter score
          const sortedGameIDs = Array.from(metaMap.keys()).sort(
            (a, b) => (metaMap.get(b)?.score || 0) - (metaMap.get(a)?.score || 0)
          );
          const topIDs = sortedGameIDs.slice(0, 100);

          if (topIDs.length > 0) {
            const gamesQuery = `
              fields name, summary, first_release_date, cover.url, cover.image_id, platforms.id, platforms.name, genres.name, themes.id, themes.name, total_rating, total_rating_count, hypes, category, game_type, parent_game, involved_companies.company.name, involved_companies.developer;
              where id = (${topIDs.join(',')}) & cover != null;
              limit ${topIDs.length};
            `;
            const gamesData: any[] = await queryIGDB('games', gamesQuery);

            // Filtrera bort DLC och olämpligt innehåll (tema 42 = Erotic)
            const cleanGames = (gamesData || []).filter((g: any) => {
              if (isDlcOrExpansion(g)) return false;
              if (g.themes?.some((t: any) => t.id === 42 || t.name?.toLowerCase().includes('erotic'))) return false;
              return true;
            });

            // Tillämpa aktualitetsbonus (Freshness multiplier)
            const oneYearAgo = nowSeconds - 365 * 24 * 3600;
            const threeYearsAgo = nowSeconds - 3 * 365 * 24 * 3600;

            const scoredGames = cleanGames.map((game: any) => {
              const meta = metaMap.get(game.id) || { score: 0, bestType: 1, bestTypeValue: 0 };
              let finalScore = meta.score;
              const release = game.first_release_date || 0;

              if (release >= todayStartTs || release === 0) {
                finalScore *= 1.4; // Kommande efterlängtat spel eller släpps idag
              } else if (release > oneYearAgo) {
                finalScore *= 1.35; // Släppt senaste 12 månaderna
              } else if (release > threeYearsAgo) {
                finalScore *= 1.0;
              } else {
                finalScore *= 0.65; // Äldre live-service / klassiker
              }

              // Normalisera betyg
              const ratingScore = game.total_rating || game.rating;
              const igdbRating = ratingScore ? Math.round((ratingScore / 10) * 10) / 10 : null;
              const isUpcoming = (game.first_release_date || 0) >= todayStartTs;

              // Skapa dagsaktuell, informativ badgeText baserat på faktiska mätpunkter
              let badgeText = '🔥 Trendar just nu';
              if (isUpcoming || meta.bestType === 10) {
                badgeText = '🚀 Efterlängtat';
              } else {
                switch (meta.bestType) {
                  case 9:
                    badgeText = '🏆 Toppsäljare';
                    break;
                  case 10:
                    badgeText = '🚀 Efterlängtat';
                    break;
                  case 34:
                    badgeText = '🔴 Het på Twitch';
                    break;
                  case 1:
                    badgeText = '🔥 Söktrend idag';
                    break;
                  case 5:
                    badgeText = '👥 Mest spelat idag';
                    break;
                  case 2:
                    badgeText = '✨ Önskelistas';
                    break;
                  case 3:
                    badgeText = '🎮 Spelas nu';
                    break;
                  default:
                    if (igdbRating && igdbRating >= 8.5) {
                      badgeText = `⭐ ${igdbRating} Betyg`;
                    } else {
                      badgeText = '🔥 Trendar just nu';
                    }
                }
              }

              const releaseYear = game.first_release_date
                ? new Date(game.first_release_date * 1000).getFullYear()
                : null;
              const platforms = (game.platforms || []).map((p: any) => p.name);
              const genres = (game.genres || []).map((g: any) => g.name);
              const developers = (game.involved_companies || [])
                .filter((c: any) => c.developer)
                .map((c: any) => c.company.name);

              return {
                id: String(game.id),
                igdb_id: game.id,
                title: game.name,
                release_year: releaseYear,
                first_release_date: game.first_release_date || null,
                platforms,
                genres,
                developers,
                cover_url: formatGameCover(game.cover),
                igdb_rating: igdbRating,
                summary: game.summary || null,
                hypes: game.hypes || 0,
                badge_text: badgeText,
                _score: finalScore,
                _total_rating: game.total_rating || 0,
              };
            });

            // Sortera baserat på sortParam
            if (sortParam === 'rating') {
              scoredGames.sort((a, b) => b._total_rating - a._total_rating);
            } else if (sortParam === 'newest') {
              scoredGames.sort((a, b) => (b.first_release_date || 0) - (a.first_release_date || 0));
            } else {
              scoredGames.sort((a, b) => b._score - a._score);
            }

            results = scoredGames.slice(0, limitParam);
          }
        }
      } catch (err) {
        console.warn('PopScore query failed, falling back to recent hot games:', err);
      }

      // Fallback om PopScore var tom eller misslyckades
      if (results.length === 0) {
        const sixMonthsAgo = nowSeconds - 180 * 24 * 3600;
        const fallbackQuery = `
          fields name, summary, first_release_date, cover.url, cover.image_id, platforms.name, genres.name, involved_companies.company.name, involved_companies.developer, total_rating, rating, hypes, category, game_type, parent_game;
          where first_release_date >= ${sixMonthsAgo} & cover != null & hypes > 0;
          sort hypes desc;
          limit ${limitParam};
        `;
        const hotData = await queryIGDB('games', fallbackQuery);
        results = (hotData || [])
          .filter((g: any) => !isDlcOrExpansion(g))
          .map((game: any) => {
            const ratingScore = game.total_rating || game.rating;
            const igdbRating = ratingScore ? Math.round((ratingScore / 10) * 10) / 10 : null;
            return {
              id: String(game.id),
              igdb_id: game.id,
              title: game.name,
              release_year: game.first_release_date ? new Date(game.first_release_date * 1000).getFullYear() : null,
              first_release_date: game.first_release_date || null,
              platforms: (game.platforms || []).map((p: any) => p.name),
              genres: (game.genres || []).map((g: any) => g.name),
              developers: (game.involved_companies || []).filter((c: any) => c.developer).map((c: any) => c.company.name),
              cover_url: formatGameCover(game.cover),
              igdb_rating: igdbRating,
              summary: game.summary || null,
              hypes: game.hypes || 0,
              badge_text: (game.first_release_date || 0) > nowSeconds ? '🚀 Efterlängtat' : '🔥 Trendar just nu',
            };
          });
      }
    }

    // =========================================================================
    // 2. UPCOMING / RELEASEKALENDER (Månadsfiltrering, Plattformar, Mest hypade)
    // =========================================================================
    else if (category === 'upcoming') {
      const conditions: string[] = ['cover != null'];

      const startTs = startDateParam ? Math.floor(Number(startDateParam)) : todayStartTs;
      conditions.push(`first_release_date >= ${startTs}`);

      if (endDateParam) {
        const endTs = Math.floor(Number(endDateParam));
        conditions.push(`first_release_date <= ${endTs}`);
      }

      if (minHypeParam) {
        conditions.push(`hypes >= ${minHypeParam}`);
      } else if (isHypedParam) {
        conditions.push('hypes > 0');
      }

      if (platformParam !== 'all' && PLATFORM_MAP[platformParam]) {
        conditions.push(`platforms = (${PLATFORM_MAP[platformParam].join(',')})`);
      }

      const sortClause = isHypedParam ? 'sort hypes desc;' : 'sort first_release_date asc;';
      const upcomingQuery = `
        fields name, summary, first_release_date, cover.url, cover.image_id, platforms.id, platforms.name, genres.name, involved_companies.company.name, involved_companies.developer, total_rating, rating, hypes, category, game_type, parent_game;
        where ${conditions.join(' & ')};
        ${sortClause}
        limit ${limitParam};
      `;

      const data: any[] = await queryIGDB('games', upcomingQuery);

      results = (data || [])
        .filter((g: any) => !isDlcOrExpansion(g))
        .map((game: any) => {
          const ratingScore = game.total_rating || game.rating;
          const igdbRating = ratingScore ? Math.round((ratingScore / 10) * 10) / 10 : null;

          return {
            id: String(game.id),
            igdb_id: game.id,
            title: game.name,
            release_year: game.first_release_date
              ? new Date(game.first_release_date * 1000).getFullYear()
              : null,
            first_release_date: game.first_release_date || null,
            platforms: (game.platforms || []).map((p: any) => p.name),
            genres: (game.genres || []).map((g: any) => g.name),
            developers: (game.involved_companies || [])
              .filter((c: any) => c.developer)
              .map((c: any) => c.company.name),
            cover_url: formatGameCover(game.cover),
            igdb_rating: igdbRating,
            summary: game.summary || null,
            hypes: game.hypes || 0,
            badge_text: (game.hypes && game.hypes >= 50) ? '🔥 Hett släpp' : '🚀 Kommande',
          };
        });
    }

    // =========================================================================
    // 3. TOP RATED / GENRES
    // =========================================================================
    else {
      let dateClause = '';
      if (eraParam === 'recent') {
        dateClause = `& first_release_date >= 1640995200 & first_release_date <= ${nowSeconds + 31536000}`;
      } else if (eraParam === 'prev_gen') {
        dateClause = `& first_release_date >= 1483228800 & first_release_date < 1640995200`;
      } else if (eraParam === 'classics') {
        dateClause = `& first_release_date < 1483228800`;
      }

      let igdbQuery = '';
      if (category === 'top_rated') {
        igdbQuery = `
          fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary, total_rating_count, category, game_type, parent_game;
          where total_rating_count >= 15 ${dateClause} & cover != null;
          sort total_rating desc;
          limit ${limitParam};
        `;
      } else if (genreParam && genreParam !== 'Alla genrer') {
        const genreClause = GENRE_CLAUSES[genreParam] || `genres.name = "${genreParam.replace(/"/g, '\\"')}"`;
        let sortClause = 'sort total_rating_count desc;';
        if (sortParam === 'rating') sortClause = 'sort total_rating desc;';
        else if (sortParam === 'newest') sortClause = 'sort first_release_date desc;';
        else if (sortParam === 'popularity') sortClause = 'sort total_rating_count desc;';

        igdbQuery = `
          fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary, total_rating_count, hypes, category, game_type, parent_game;
          where ${genreClause} & first_release_date >= 1577836800 & cover != null;
          ${sortClause}
          limit ${limitParam};
        `;
      } else {
        let sortClause = 'sort total_rating_count desc;';
        if (sortParam === 'rating') sortClause = 'sort total_rating desc;';
        else if (sortParam === 'newest') sortClause = 'sort first_release_date desc;';

        igdbQuery = `
          fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary, hypes, total_rating_count, category, game_type, parent_game;
          where first_release_date >= 1640995200 & total_rating_count >= 8 & cover != null;
          ${sortClause}
          limit ${limitParam};
        `;
      }

      const data = await queryIGDB('games', igdbQuery);
      results = (data || [])
        .filter((g: any) => !isDlcOrExpansion(g))
        .map((game: any) => {
          const ratingScore = game.total_rating || game.rating;
          const igdbRating = ratingScore ? Math.round((ratingScore / 10) * 10) / 10 : null;

          return {
            id: String(game.id),
            igdb_id: game.id,
            title: game.name,
            release_year: game.first_release_date ? new Date(game.first_release_date * 1000).getFullYear() : null,
            first_release_date: game.first_release_date || null,
            platforms: (game.platforms || []).map((p: any) => p.name),
            genres: (game.genres || []).map((g: any) => g.name),
            developers: (game.involved_companies || []).filter((c: any) => c.developer).map((c: any) => c.company.name),
            cover_url: formatGameCover(game.cover),
            igdb_rating: igdbRating,
            summary: game.summary || null,
            hypes: game.hypes || 0,
            badge_text: igdbRating && igdbRating >= 8.5 ? `⭐ ${igdbRating} Betyg` : null,
          };
        });
    }

    // Filtrera bort spel som redan finns i användarens bibliotek
    const filteredResults = results.filter((game: any) => !excludeIds.has(game.igdb_id));

    if (filteredResults.length > 0) {
      DISCOVER_CACHE.set(cacheKey, {
        results: filteredResults,
        expiresAt: Date.now() + CACHE_TTL_MS,
      });
    }

    return NextResponse.json(
      { results: filteredResults },
      {
        headers: {
          'Cache-Control': 'public, s-maxage=900, stale-while-revalidate=1800',
        },
      }
    );
  } catch (error: any) {
    console.error('Error in /api/games/discover:', error);
    const stale = DISCOVER_CACHE.get(cacheKey);
    if (stale && stale.results.length > 0) {
      return NextResponse.json({ results: stale.results });
    }
    return NextResponse.json(
      { error: 'Kunde inte hämta upptäcktsdata från IGDB' },
      { status: 500 }
    );
  }
}
