import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';
export const revalidate = 86400; // Cacha i 24 timmar

const METACRITIC_API_KEY = '1MOZgmNFxvmljaQR1X9KAij9Mo4xAY3u';
const USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

// Enkel minnescache för att undvika onödiga anrop vid snabba sidbyten
const memoryCache = new Map<string, { data: any; cachedAt: number }>();
const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 timmar

function normalizeTitle(t: string): string {
  return t
    .toLowerCase()
    .replace(/[:’'’\-–—.,!?]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const title = searchParams.get('title')?.trim();

  if (!title) {
    return NextResponse.json({ error: 'Missing title parameter' }, { status: 400 });
  }

  const cacheKey = normalizeTitle(title);
  const now = Date.now();
  const cached = memoryCache.get(cacheKey);
  if (cached && now - cached.cachedAt < CACHE_TTL_MS) {
    return NextResponse.json(cached.data);
  }

  try {
    // 1. Sök efter spelet på Metacritic
    const searchUrl = `https://backend.metacritic.com/finder/metacritic/search/${encodeURIComponent(
      title
    )}/web?offset=0&limit=5&mcoTypeId=13&componentName=search&componentType=SearchResult&apiKey=${METACRITIC_API_KEY}`;

    const searchRes = await fetch(searchUrl, {
      headers: {
        'User-Agent': USER_AGENT,
        'Accept': 'application/json',
      },
      next: { revalidate: 86400 },
    });

    if (!searchRes.ok) {
      return NextResponse.json({ found: false, error: 'Metacritic search failed' }, { status: 200 });
    }

    const searchJson = await searchRes.json();
    const items = searchJson?.data?.items || [];
    if (items.length === 0) {
      return NextResponse.json({ found: false }, { status: 200 });
    }

    // Hitta bästa matchning (exakt titelmatch eller första)
    const normSearch = normalizeTitle(title);
    const matchedItem =
      items.find((i: any) => normalizeTitle(i.title || '') === normSearch) ||
      items.find((i: any) => normalizeTitle(i.title || '').includes(normSearch)) ||
      items[0];

    const slug = matchedItem.slug;
    if (!slug) {
      return NextResponse.json({ found: false }, { status: 200 });
    }

    // 2. Hämta produktdetaljer med alla plattformsbetyg och recensionsantal
    const detailUrl = `https://backend.metacritic.com/games/metacritic/${encodeURIComponent(
      slug
    )}/web?componentName=product&componentType=Product&apiKey=${METACRITIC_API_KEY}`;

    const detailRes = await fetch(detailUrl, {
      headers: {
        'User-Agent': USER_AGENT,
        'Accept': 'application/json',
      },
      next: { revalidate: 86400 },
    });

    let leadScore = matchedItem.criticScoreSummary?.score ?? null;
    let reviewCount: number | null = null;
    let mustPlay: boolean = Boolean(matchedItem.mustPlay);
    let sentiment: string | null = null;
    let platforms: Array<{
      name: string;
      slug: string;
      score: number | null;
      reviewCount: number | null;
      isLeadPlatform: boolean;
    }> = [];

    if (detailRes.ok) {
      const detailJson = await detailRes.json();
      const product = detailJson?.data?.item;
      if (product) {
        if (typeof product.criticScoreSummary?.score === 'number') {
          leadScore = product.criticScoreSummary.score;
        }
        if (typeof product.criticScoreSummary?.reviewCount === 'number') {
          reviewCount = product.criticScoreSummary.reviewCount;
        }
        if (product.criticScoreSummary?.sentiment) {
          sentiment = product.criticScoreSummary.sentiment;
        }
        if (typeof product.mustPlay === 'boolean') {
          mustPlay = product.mustPlay;
        }

        if (Array.isArray(product.platforms)) {
          platforms = product.platforms.map((p: any) => ({
            name: p.name || 'Okänd',
            slug: p.slug || '',
            score: typeof p.criticScoreSummary?.score === 'number' ? p.criticScoreSummary.score : null,
            reviewCount: typeof p.criticScoreSummary?.reviewCount === 'number' ? p.criticScoreSummary.reviewCount : null,
            isLeadPlatform: Boolean(p.isLeadPlatform),
          }));
        }
      }
    }

    const payload = {
      found: leadScore !== null,
      title: matchedItem.title,
      slug: slug,
      url: `https://www.metacritic.com/game/${slug}/`,
      metascore: leadScore,
      reviewCount: reviewCount,
      mustPlay: mustPlay,
      sentiment: sentiment,
      platforms: platforms,
    };

    memoryCache.set(cacheKey, { data: payload, cachedAt: now });
    return NextResponse.json(payload);
  } catch (err: any) {
    console.error('Metacritic API error:', err);
    return NextResponse.json({ found: false, error: err?.message || 'Unknown error' }, { status: 200 });
  }
}
