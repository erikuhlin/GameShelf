import { NextRequest, NextResponse } from 'next/server';
import { queryIGDB } from '@/lib/igdb-server';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  const igdbId = params.id;

  if (!igdbId || isNaN(Number(igdbId))) {
    return NextResponse.json({ error: 'Invalid IGDB ID' }, { status: 400 });
  }

  try {
    const query = `
      where id = ${igdbId};
      fields name, cover.url, cover.image_id, first_release_date, genres.name, involved_companies.company.name, involved_companies.developer, platforms.name, total_rating, rating, summary, time_to_beat.*;
      limit 1;
    `;

    const data = await queryIGDB('games', query);

    if (!data || data.length === 0) {
      return NextResponse.json({ error: 'Game not found' }, { status: 400 });
    }

    const game = data[0];
    let coverUrl = game.cover?.url;
    if (coverUrl) {
      if (coverUrl.startsWith('//')) {
        coverUrl = 'https:' + coverUrl;
      }
      coverUrl = coverUrl.replace('/t_thumb/', '/t_cover_big/');
    } else if (game.cover?.image_id) {
      coverUrl = `https://images.igdb.com/igdb/image/upload/t_cover_big/${game.cover.image_id}.jpg`;
    }

    return NextResponse.json({
      game: {
        ...game,
        cover: game.cover ? { ...game.cover, url: coverUrl } : undefined,
      },
    });
  } catch (error: any) {
    console.error('Error fetching IGDB game detail:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to fetch IGDB game detail' },
      { status: 500 }
    );
  }
}
