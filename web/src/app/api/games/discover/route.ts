import { NextRequest, NextResponse } from 'next/server';
import { queryIGDB } from '@/lib/igdb-server';

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const excludeIdsParam = searchParams.get('exclude_ids') || '';
  const excludeIds = new Set(excludeIdsParam.split(',').map((id) => Number(id.trim())).filter(Boolean));

  // Nuvarande generation: från 2021 (timestamp: 1609459200)
  const minReleaseTimestamp = 1609459200; // 2021-01-01

  try {
    // Bygg IGDB query för aktuella, högt rankade spel
    let igdbQuery = `
      fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary, hypes;
      where first_release_date >= ${minReleaseTimestamp} & (rating >= 75 | total_rating >= 75 | hypes >= 10) & cover != null;
      sort rating desc;
      limit 40;
    `;

    let data: any[] = [];
    try {
      data = await queryIGDB('games', igdbQuery);
    } catch (e) {
      // Fallback query if sorting/filters are strict
      const fallbackQuery = `
        fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary;
        where first_release_date >= ${minReleaseTimestamp} & cover != null;
        sort first_release_date desc;
        limit 30;
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
          platforms,
          genres,
          developers,
          cover_url: coverUrl,
          igdb_rating: igdbRating,
          summary: game.summary || '',
          is_owned: false,
          status: 'Önskelista',
        };
      });

    return NextResponse.json({ results });
  } catch (error: any) {
    console.error('Error in /api/games/discover:', error);
    return NextResponse.json(
      { error: error.message || 'Kunde inte hämta spelförslag' },
      { status: 500 }
    );
  }
}
