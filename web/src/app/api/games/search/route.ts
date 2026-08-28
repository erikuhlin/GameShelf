import { NextRequest, NextResponse } from 'next/server';
import { queryIGDB } from '@/lib/igdb-server';

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const q = searchParams.get('q')?.trim();
  const limit = Math.min(Number(searchParams.get('limit')) || 25, 50);

  if (!q) {
    return NextResponse.json({ results: [] });
  }

  try {
    // Sanera söksträngen
    const sanitizedQ = q.replace(/"/g, '\\"');
    const query = `
      search "${sanitizedQ}";
      fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary;
      limit ${limit};
    `;

    const data = await queryIGDB('games', query);

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
