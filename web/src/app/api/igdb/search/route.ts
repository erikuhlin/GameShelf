import { NextRequest, NextResponse } from 'next/server';
import { queryIGDB } from '@/lib/igdb-server';
import { resolveGameAlias } from '@/lib/aliasResolver';

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const rawQ = searchParams.get('q')?.trim();
  const limit = Math.min(Number(searchParams.get('limit')) || 20, 50);

  if (!rawQ) {
    return NextResponse.json({ results: [] });
  }

  // Lös upp förkortningar/alias (t.ex. GTA V -> Grand Theft Auto V)
  const resolvedQ = resolveGameAlias(rawQ);

  try {
    // IGDB APICalypse query
    // Escape quotes in search query
    const sanitizedQ = resolvedQ.replace(/"/g, '\\"');
    const query = `
      search "${sanitizedQ}";
      fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary;
      limit ${limit};
    `;

    const data = await queryIGDB('games', query);

    // Transform covers to high-res t_cover_big if url exists
    const transformed = data.map((game: any) => {
      let coverUrl = game.cover?.url;
      if (coverUrl) {
        if (coverUrl.startsWith('//')) {
          coverUrl = 'https:' + coverUrl;
        }
        coverUrl = coverUrl.replace('/t_thumb/', '/t_cover_big/');
      } else if (game.cover?.image_id) {
        coverUrl = `https://images.igdb.com/igdb/image/upload/t_cover_big/${game.cover.image_id}.jpg`;
      }

      return {
        ...game,
        cover: game.cover ? { ...game.cover, url: coverUrl } : undefined,
      };
    });

    return NextResponse.json({ results: transformed });
  } catch (error: any) {
    console.error('Error searching IGDB:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to search IGDB' },
      { status: 500 }
    );
  }
}
