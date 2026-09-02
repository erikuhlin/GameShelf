import { NextRequest, NextResponse } from 'next/server';
import { queryIGDB } from '@/lib/igdb-server';
import { resolveGameAlias } from '@/lib/aliasResolver';

// Plattform-mappning till IGDB IDs
const PLATFORM_ID_MAP: Record<string, string> = {
  // PlayStation
  ps5: '167',
  ps4: '48',
  ps3: '9',
  ps2: '8',
  ps1: '7',
  psp: '38',
  psvita: '46',
  playstation: '167, 48, 9, 8, 7, 38, 46',
  'playstation 5': '167',
  'playstation 4': '48',
  'playstation 3': '9',
  'playstation 2': '8',
  'playstation 1': '7',

  // Xbox
  xbox_series: '169',
  xbox_one: '49',
  xbox_360: '12',
  xbox_original: '11',
  xbox: '169, 49, 12, 11',
  'xbox series x/s': '169',
  'xbox 360': '12',

  // Nintendo
  switch: '130',
  'nintendo switch': '130',
  wii_u: '41',
  wii: '5',
  gamecube: '21',
  n64: '4',
  snes: '19',
  nes: '18',
  gba: '24',
  gbc: '22',
  gb: '33',
  ds: '20',
  '3ds': '37',
  nintendo: '130, 41, 5, 21, 4, 19, 18, 24, 22, 33, 20, 37',

  // PC
  pc: '6',
  windows: '6',
};

// Genre-mappning till IGDB IDs
const GENRE_ID_MAP: Record<string, { type: 'genre' | 'theme'; ids: string }> = {
  action: { type: 'genre', ids: '25, 4, 5, 31' },
  'role-playing (rpg)': { type: 'genre', ids: '12' },
  rpg: { type: 'genre', ids: '12' },
  adventure: { type: 'genre', ids: '31' },
  äventyr: { type: 'genre', ids: '31' },
  shooter: { type: 'genre', ids: '5, 24' },
  skjutspel: { type: 'genre', ids: '5, 24' },
  strategy: { type: 'genre', ids: '15, 11, 16, 24' },
  strategi: { type: 'genre', ids: '15, 11, 16, 24' },
  platform: { type: 'genre', ids: '8' },
  plattform: { type: 'genre', ids: '8' },
  racing: { type: 'genre', ids: '10' },
  fighting: { type: 'genre', ids: '4' },
  horror: { type: 'theme', ids: '19' },
  skräck: { type: 'theme', ids: '19' },
  indie: { type: 'genre', ids: '32' },
  simulator: { type: 'genre', ids: '13' },
  puzzle: { type: 'genre', ids: '9' },
  pussel: { type: 'genre', ids: '9' },
  sport: { type: 'genre', ids: '14' },
  arcade: { type: 'genre', ids: '33' },
  arkad: { type: 'genre', ids: '33' },
};

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const rawQ = searchParams.get('q')?.trim() || '';
  const limit = Math.min(Number(searchParams.get('limit')) || 25, 50);

  // Filterparametrar
  const platformParam = searchParams.get('platform')?.trim().toLowerCase() || '';
  const genreParam = searchParams.get('genre')?.trim().toLowerCase() || '';
  const yearFrom = searchParams.get('year_from');
  const yearTo = searchParams.get('year_to');
  const minRating = Number(searchParams.get('min_rating')) || 0;
  const developerParam = searchParams.get('developer')?.trim() || '';
  const gameMode = searchParams.get('game_mode'); // 1 = Single, 2 = Multi, 3 = Co-op
  const sortParam = searchParams.get('sort') || 'popularity';
  const preset = searchParams.get('preset');

  // Om ingen fråga och inga filter, returnera tomt
  const hasFilters =
    Boolean(platformParam) ||
    Boolean(genreParam) ||
    Boolean(yearFrom) ||
    Boolean(yearTo) ||
    minRating > 0 ||
    Boolean(developerParam) ||
    Boolean(gameMode) ||
    Boolean(preset);

  if (!rawQ && !hasFilters) {
    return NextResponse.json({ results: [] });
  }

  const resolvedQ = rawQ ? resolveGameAlias(rawQ) : '';

  try {
    const whereConditions: string[] = ['cover != null'];

    // 1. Plattform-villkor
    if (platformParam && platformParam !== 'alla') {
      const mappedPlatformIds = PLATFORM_ID_MAP[platformParam] || (Number(platformParam) ? platformParam : null);
      if (mappedPlatformIds) {
        whereConditions.push(`platforms = (${mappedPlatformIds})`);
      }
    }

    // 2. Genre/Tema-villkor
    if (genreParam && genreParam !== 'alla') {
      const genreMapping = GENRE_ID_MAP[genreParam];
      if (genreMapping) {
        if (genreMapping.type === 'theme') {
          whereConditions.push(`themes = (${genreMapping.ids})`);
        } else {
          whereConditions.push(`genres = (${genreMapping.ids})`);
        }
      }
    }

    // 3. Årsintervall / Tidsmaskin
    if (yearFrom) {
      const fromY = parseInt(yearFrom, 10);
      if (!isNaN(fromY)) {
        const fromTimestamp = Math.floor(new Date(fromY, 0, 1).getTime() / 1000);
        whereConditions.push(`first_release_date >= ${fromTimestamp}`);
      }
    }
    if (yearTo) {
      const toY = parseInt(yearTo, 10);
      if (!isNaN(toY)) {
        const toTimestamp = Math.floor(new Date(toY, 11, 31, 23, 59, 59).getTime() / 1000);
        whereConditions.push(`first_release_date <= ${toTimestamp}`);
      }
    }

    // 4. Betyg
    if (minRating > 0) {
      whereConditions.push(`total_rating >= ${minRating}`);
    }

    // 5. Utvecklare
    if (developerParam) {
      const sanitizedDev = developerParam.replace(/"/g, '\\"');
      whereConditions.push(`involved_companies.company.name ~ *"${sanitizedDev}"*`);
    }

    // 6. Spelläge
    if (gameMode) {
      whereConditions.push(`game_modes = (${gameMode})`);
    }

    // 7. Smarta förval / Presets
    if (preset === 'trending') {
      const threeMonthsAgo = Math.floor(Date.now() / 1000) - 90 * 86400;
      whereConditions.push(`first_release_date >= ${threeMonthsAgo}`);
    } else if (preset === 'masterpieces') {
      whereConditions.push(`total_rating >= 88 & total_rating_count >= 20`);
    } else if (preset === 'retro_2000s') {
      whereConditions.push(`first_release_date >= 946684800 & first_release_date <= 1167609600 & total_rating >= 75`);
    }

    let igdbQuery = '';
    const fields =
      'fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary, total_rating_count, hypes;';

    // Om fritext finns, använder vi IGDB "search"
    if (resolvedQ) {
      const sanitizedQ = resolvedQ.replace(/"/g, '\\"');
      const wherePart = whereConditions.length > 0 ? `where ${whereConditions.join(' & ')};` : '';
      igdbQuery = `
        search "${sanitizedQ}";
        ${fields}
        ${wherePart}
        limit ${limit};
      `;
    } else {
      // Ingen fritext (t.ex. tidsmaskin eller filterutforskning)
      let sortClause = 'sort total_rating_count desc;';
      if (sortParam === 'rating' || preset === 'masterpieces') {
        sortClause = 'sort total_rating desc;';
      } else if (sortParam === 'newest') {
        sortClause = 'sort first_release_date desc;';
      } else if (sortParam === 'oldest') {
        sortClause = 'sort first_release_date asc;';
      } else if (preset === 'trending') {
        sortClause = 'sort hypes desc;';
      }

      const wherePart = whereConditions.length > 0 ? `where ${whereConditions.join(' & ')};` : '';
      igdbQuery = `
        ${fields}
        ${wherePart}
        ${sortClause}
        limit ${limit};
      `;
    }

    const data = await queryIGDB('games', igdbQuery);

    // Formatera resultaten med högupplösta omslagsbilder
    const results = (data || []).map((game: any) => {
      let coverUrl: string | null = null;
      if (game.cover?.url) {
        let rawUrl = game.cover.url;
        if (rawUrl.startsWith('//')) {
          rawUrl = 'https:' + rawUrl;
        }
        coverUrl = rawUrl.replace('/t_thumb/', '/t_cover_big/');
      } else if (game.cover?.image_id) {
        coverUrl = `https://images.igdb.com/igdb/image/upload/t_cover_big/${game.cover.image_id}.jpg`;
      }

      const releaseYear = game.first_release_date
        ? new Date(game.first_release_date * 1000).getFullYear()
        : null;

      const platforms = (game.platforms || []).map((p: any) => p.name);
      const genres = (game.genres || []).map((g: any) => g.name);
      const developers = (game.involved_companies || [])
        .filter((c: any) => c.developer)
        .map((c: any) => c.company.name);

      const ratingScore = game.total_rating || game.rating;
      const igdbRating = ratingScore ? Math.round((ratingScore / 10) * 10) / 10 : null;

      return {
        id: game.id,
        title: game.name,
        release_year: releaseYear,
        first_release_date: game.first_release_date || null,
        platforms,
        genres,
        developers,
        cover_url: coverUrl,
        igdb_rating: igdbRating,
        summary: game.summary || '',
      };
    });

    return NextResponse.json({ results });
  } catch (error: any) {
    console.error('Error in IGDB /api/games/search:', error);
    return NextResponse.json(
      { error: error.message || 'Kunde inte söka i IGDB' },
      { status: 500 }
    );
  }
}
