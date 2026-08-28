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
      fields name, summary, storyline, first_release_date, cover.url, cover.image_id, platforms.name, genres.name, total_rating, rating, aggregated_rating, involved_companies.company.name, involved_companies.developer, involved_companies.publisher, collection.name, similar_games.name, similar_games.cover.image_id, similar_games.first_release_date, similar_games.total_rating, screenshots.image_id, artworks.image_id, videos.name, videos.video_id, game_modes.name, themes.name, age_ratings.category, age_ratings.rating;
      limit 1;
    `;

    const data = await queryIGDB('games', query);

    if (!data || data.length === 0) {
      return NextResponse.json({ error: 'Game not found' }, { status: 400 });
    }

    const game = data[0];

    // Formatera omslag
    let coverUrl = game.cover?.url;
    if (coverUrl) {
      if (coverUrl.startsWith('//')) {
        coverUrl = 'https:' + coverUrl;
      }
      coverUrl = coverUrl.replace('/t_thumb/', '/t_cover_big/');
    } else if (game.cover?.image_id) {
      coverUrl = `https://images.igdb.com/igdb/image/upload/t_cover_big/${game.cover.image_id}.jpg`;
    }

    // Formatera skärmdumpar & artworks
    const screenshots = (game.screenshots || []).map((s: any) => ({
      id: s.id,
      url: `https://images.igdb.com/igdb/image/upload/t_screenshot_big/${s.image_id}.jpg`,
      fullUrl: `https://images.igdb.com/igdb/image/upload/t_1080p/${s.image_id}.jpg`,
    }));

    const artworks = (game.artworks || []).map((a: any) => ({
      id: a.id,
      url: `https://images.igdb.com/igdb/image/upload/t_screenshot_big/${a.image_id}.jpg`,
      fullUrl: `https://images.igdb.com/igdb/image/upload/t_1080p/${a.image_id}.jpg`,
    }));

    // Formatera utvecklare och utgivare
    const developers = (game.involved_companies || [])
      .filter((c: any) => c.developer)
      .map((c: any) => c.company.name);

    const publishers = (game.involved_companies || [])
      .filter((c: any) => c.publisher)
      .map((c: any) => c.company.name);

    // Formatera spellägen och teman
    const gameModes = (game.game_modes || []).map((m: any) => m.name);
    const themes = (game.themes || []).map((t: any) => t.name);

    // Formatera trailers
    const videos = (game.videos || []).map((v: any) => ({
      name: v.name || 'Trailer',
      videoId: v.video_id,
    }));

    // Formatera liknande spel
    const similarGames = (game.similar_games || []).map((sg: any) => ({
      id: sg.id,
      title: sg.name,
      coverUrl: sg.cover?.image_id
        ? `https://images.igdb.com/igdb/image/upload/t_cover_big/${sg.cover.image_id}.jpg`
        : null,
      releaseYear: sg.first_release_date
        ? new Date(sg.first_release_date * 1000).getFullYear()
        : null,
      rating: sg.total_rating ? Math.round((sg.total_rating / 10) * 10) / 10 : null,
    }));

    // Hämta speltid (HowLongToBeat)
    let timeToBeat: { mainStory: number | null; mainExtra: number | null; completionist: number | null } | null = null;
    try {
      const ttbData = await queryIGDB(
        'game_time_to_beats',
        `where game_id = ${igdbId}; fields hastily, normally, completely, game_id; limit 1;`
      );
      if (ttbData && ttbData.length > 0) {
        const ttb = ttbData[0];
        timeToBeat = {
          mainStory: ttb.normally ? Math.round(ttb.normally / 3600) : (ttb.hastily ? Math.round(ttb.hastily / 3600) : null),
          mainExtra: ttb.hastily && ttb.normally ? Math.round((ttb.normally + ttb.hastily) / 7200) : (ttb.normally ? Math.round(ttb.normally / 3600) : null),
          completionist: ttb.completely ? Math.round(ttb.completely / 3600) : null,
        };
      }
    } catch (ttbErr) {
      // Ignorera ttb fel
    }

    return NextResponse.json({
      game: {
        ...game,
        cover: game.cover ? { ...game.cover, url: coverUrl } : undefined,
        cover_url: coverUrl,
        screenshots,
        artworks,
        developers,
        publishers,
        gameModes,
        themes,
        videos,
        similarGames,
        timeToBeat,
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
