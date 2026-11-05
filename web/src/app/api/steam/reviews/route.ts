import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';
export const revalidate = 3600; // Cacha i 1 timme

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  let appId = searchParams.get('appId')?.trim();
  const title = searchParams.get('title')?.trim();

  // Fallback: slå upp Steam App ID via titel om appId saknas
  if (!appId && title) {
    try {
      const searchRes = await fetch(
        `https://store.steampowered.com/api/storesearch/?term=${encodeURIComponent(title)}&l=english&cc=US`
      );
      if (searchRes.ok) {
        const searchData = await searchRes.json();
        if (searchData.items && searchData.items.length > 0) {
          const lower = title.toLowerCase();
          const match = searchData.items.find(
            (i: any) => i.name.toLowerCase() === lower
          ) || searchData.items[0];
          appId = String(match.id);
        }
      }
    } catch (_) {}
  }

  if (!appId) {
    return NextResponse.json({ error: 'Missing or unresolvable appId/title' }, { status: 400 });
  }

  try {
    const url = `https://api.steampowered.com/IUserReviewsService/GetAppReviews/v1/?appid=${encodeURIComponent(
      appId
    )}&language=all&purchase_type=all&num_per_page=3&filter=all`;

    const res = await fetch(url, {
      headers: {
        'Accept': 'application/json',
      },
      next: { revalidate: 3600 },
    });

    if (!res.ok) {
      return NextResponse.json(
        { error: `Steam API responded with status ${res.status}` },
        { status: res.status }
      );
    }

    const data = await res.json();
    // Packa upp Steamworks Web API:s { response: { query_summary, reviews } }
    const unwrapped = data.response || data;
    return NextResponse.json({
      success: 1,
      query_summary: unwrapped.query_summary,
      reviews: unwrapped.reviews,
    });
  } catch (error: any) {
    console.error('Error fetching Steam reviews:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to fetch Steam reviews' },
      { status: 500 }
    );
  }
}
