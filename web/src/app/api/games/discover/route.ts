import { NextRequest, NextResponse } from 'next/server';
import { queryIGDB } from '@/lib/igdb-server';

export const revalidate = 300; // 5 minuters edge cache

const GENRE_MAP: Record<string, string> = {
  'RPG': 'Role-playing (RPG)',
  'Rollspel': 'Role-playing (RPG)',
  'Role-playing (RPG)': 'Role-playing (RPG)',
  'Action': 'Shooter, Hack and slash/Beat \'em up',
  'Äventyr': 'Adventure',
  'Adventure': 'Adventure',
  'Skjutspel': 'Shooter',
  'Shooter': 'Shooter',
  'Indie': 'Indie',
  'Strategi': 'Strategy, Real Time Strategy (RTS), Turn-based strategy (TBS)',
  'Strategy': 'Strategy',
  'Plattform': 'Platform',
  'Platform': 'Platform',
  'Racing': 'Racing',
  'Fighting': 'Fighting',
  'Skräck': 'Adventure', // Often tagged as Horror themes in IGDB
  'Horror': 'Adventure',
  'Simulator': 'Simulator',
  'Pussel': 'Puzzle',
  'Puzzle': 'Puzzle',
  'Sport': 'Sport',
  'Open World': 'Adventure',
};

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const category = searchParams.get('category') || 'trending';
  const genreParam = searchParams.get('genre')?.trim();
  const sortParam = searchParams.get('sort') || 'popularity';
  const limitParam = Math.min(Number(searchParams.get('limit')) || 25, 60);
  const excludeIdsParam = searchParams.get('exclude_ids') || '';
  const excludeIds = new Set(excludeIdsParam.split(',').map((id) => Number(id.trim())).filter(Boolean));

  const nowSeconds = Math.floor(Date.now() / 1000);
  const minReleaseTimestamp = 1546300800; // 2019-01-01 för rikare genrekatalog

  try {
    let igdbQuery = '';

    if (category === 'upcoming') {
      igdbQuery = `
        fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary, hypes;
        where first_release_date > ${nowSeconds} & cover != null;
        sort hypes desc;
        limit ${limitParam};
      `;
    } else if (category === 'top_rated') {
      igdbQuery = `
        fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary, total_rating_count;
        where (rating >= 85 | total_rating >= 85) & total_rating_count >= 10 & cover != null;
        sort rating desc;
        limit ${limitParam};
      `;
    } else if (genreParam && genreParam !== 'Alla genrer') {
      const mappedGenre = GENRE_MAP[genreParam] || genreParam;
      const sanitizedGenre = mappedGenre.replace(/"/g, '\\"');

      let sortClause = 'sort rating desc;';
      if (sortParam === 'newest') sortClause = 'sort first_release_date desc;';
      else if (sortParam === 'popularity') sortClause = 'sort total_rating_count desc;';
      else if (sortParam === 'rating') sortClause = 'sort total_rating desc;';

      igdbQuery = `
        fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary, total_rating_count, hypes;
        where genres.name = "${sanitizedGenre}" & (total_rating >= 70 | rating >= 70 | hypes >= 5) & cover != null;
        ${sortClause}
        limit ${limitParam};
      `;
    } else {
      // Trending default (Heta spel just nu)
      let sortClause = 'sort hypes desc;';
      if (sortParam === 'rating') sortClause = 'sort total_rating desc;';
      else if (sortParam === 'newest') sortClause = 'sort first_release_date desc;';

      igdbQuery = `
        fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary, hypes, total_rating_count;
        where first_release_date >= ${minReleaseTimestamp} & (rating >= 75 | total_rating >= 75 | hypes >= 10 | total_rating_count >= 20) & cover != null;
        ${sortClause}
        limit ${limitParam};
      `;
    }

    let data: any[] = [];
    try {
      data = await queryIGDB('games', igdbQuery);
    } catch (e) {
      const fallbackQuery = `
        fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary;
        where cover != null;
        sort first_release_date desc;
        limit ${limitParam};
      `;
      data = await queryIGDB('games', fallbackQuery);
    }

    // Formatera resultaten och exkludera spel som redan finns i användarens bibliotek
    const results = (data || [])
      .filter((game: any) => !excludeIds.has(game.id))
      .map((game: any) => {
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
          id: String(game.id),
          igdb_id: game.id,
          title: game.name,
          release_year: releaseYear,
          first_release_date: game.first_release_date || null,
          platforms,
          genres,
          developers,
          cover_url: coverUrl,
          igdb_rating: igdbRating,
          summary: game.summary || null,
          hypes: game.hypes || 0,
        };
      });

    return NextResponse.json({ results });
  } catch (error: any) {
    console.error('Error in /api/games/discover:', error);
    return NextResponse.json(
      { error: 'Kunde inte hämta upptäcktsdata från IGDB' },
      { status: 500 }
    );
  }
}
