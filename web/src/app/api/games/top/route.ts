import { NextRequest, NextResponse } from 'next/server';
import { supabase } from '@/lib/supabase';
import { LOW_VOTES_WARNING_THRESHOLD } from '@/lib/ratingFormula';

export async function GET(request: NextRequest) {
  const searchParams = request.nextUrl.searchParams;
  const limit = Math.min(Math.max(Number(searchParams.get('limit')) || 50, 1), 100);
  const offset = Math.max(Number(searchParams.get('offset')) || 0, 0);

  const platform = searchParams.get('platform')?.trim();
  const genre = searchParams.get('genre')?.trim();
  const yearFrom = searchParams.get('year_from');
  const yearTo = searchParams.get('year_to');

  try {
    let query = supabase
      .from('game_ratings')
      .select('*', { count: 'exact' })
      .gte('total_rating_count', 150);

    // 1. Filtrera på plattform
    if (platform && platform.toLowerCase() !== 'alla') {
      query = query.contains('platforms', [platform]);
    }

    // 2. Filtrera på genre
    if (genre && genre.toLowerCase() !== 'alla') {
      // Hantera både "RPG" och "Role-playing (RPG)"
      const searchGenre = genre.toLowerCase() === 'rpg' ? 'Role-playing (RPG)' : genre;
      query = query.contains('genres', [searchGenre]);
    }

    // 3. Filtrera på år
    if (yearFrom) {
      const fromY = parseInt(yearFrom, 10);
      if (!isNaN(fromY)) {
        query = query.gte('release_year', fromY);
      }
    }
    if (yearTo) {
      const toY = parseInt(yearTo, 10);
      if (!isNaN(toY)) {
        query = query.lte('release_year', toY);
      }
    }

    // Sortera alltid på weighted_score fallande
    query = query
      .order('weighted_score', { ascending: false })
      .order('total_rating_count', { ascending: false })
      .range(offset, offset + limit - 1);

    const { data, count, error } = await query;

    if (error) {
      console.error('Supabase query error in /api/games/top:', error);
      return NextResponse.json({ error: error.message }, { status: 500 });
    }

    // Formatera resultaten
    const results = (data || []).map((row: any, idx: number) => {
      const isLowVotes = (row.total_rating_count || 0) < LOW_VOTES_WARNING_THRESHOLD;
      return {
        id: Number(row.igdb_id),
        title: row.title,
        slug: row.slug,
        cover_url: row.cover_url,
        release_year: row.release_year,
        first_release_date: row.first_release_date,
        genres: row.genres || [],
        platforms: row.platforms || [],
        platform_ids: row.platform_ids || [],
        total_rating: row.total_rating,
        total_rating_count: row.total_rating_count,
        weighted_score: row.weighted_score,
        // rankWithinList är 1-indexerad för aktuell filtrerad lista
        rank: offset + idx + 1,
        overall_rank: row.overall_rank,
        genre_ranks: row.genre_ranks || {},
        is_low_votes: isLowVotes,
      };
    });

    return NextResponse.json({
      results,
      totalCount: count || results.length,
      hasMore: (count ? offset + results.length < count : results.length === limit),
      offset,
      limit,
    });
  } catch (err: any) {
    console.error('Unexpected error in /api/games/top:', err);
    return NextResponse.json({ error: err.message || 'Internt serverfel' }, { status: 500 });
  }
}
