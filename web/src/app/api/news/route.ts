import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';
export const revalidate = 120; // 2 minuter

interface NewsItem {
  id: string;
  title: string;
  source: string;
  link: string;
  published: string;
  publishedTimestamp: number;
  image?: string | null;
  summary?: string;
  category: 'Recension' | 'Nyhet' | 'Trailer' | 'Uppdatering' | 'Guide' | 'Förhandstitt';
  platform?: 'PlayStation' | 'Xbox' | 'Nintendo' | 'PC' | 'Multi';
}

const FEEDS = [
  // 1. Svenska Spelmedier
  { name: 'Gamereactor Nyheter', source: 'Gamereactor SE', url: 'https://www.gamereactor.se/rss/rss.php?texttype=4' },
  { name: 'Gamereactor Recensioner', source: 'Gamereactor SE', url: 'https://www.gamereactor.se/rss/rss.php?texttype=1', defaultCategory: 'Recension' as const },
  { name: 'Gamereactor Förhandstittar', source: 'Gamereactor SE', url: 'https://www.gamereactor.se/rss/rss.php?texttype=2', defaultCategory: 'Förhandstitt' as const },

  // 2. Dedikerade Recensioner & Betyg
  { name: 'IGN Reviews', source: 'IGN', url: 'https://feeds.feedburner.com/ign/reviews', defaultCategory: 'Recension' as const },
  { name: 'Eurogamer Reviews', source: 'Eurogamer', url: 'https://www.eurogamer.net/feed/reviews', defaultCategory: 'Recension' as const },
  { name: 'Gamespot Reviews', source: 'GameSpot', url: 'https://www.gamespot.com/feeds/reviews/', defaultCategory: 'Recension' as const },
  { name: 'Push Square Reviews', source: 'Push Square', url: 'https://www.pushsquare.com/feeds/reviews', defaultCategory: 'Recension' as const, defaultPlatform: 'PlayStation' as const },
  { name: 'Nintendo Life Reviews', source: 'Nintendo Life', url: 'https://www.nintendolife.com/feeds/reviews', defaultCategory: 'Recension' as const, defaultPlatform: 'Nintendo' as const },
  { name: 'Pure Xbox Reviews', source: 'Pure Xbox', url: 'https://www.purexbox.com/feeds/reviews', defaultCategory: 'Recension' as const, defaultPlatform: 'Xbox' as const },

  // 3. Ledande Globala Spelmedier (Allmänt & Nyheter)
  { name: 'IGN', source: 'IGN', url: 'https://feeds.feedburner.com/ign/all' },
  { name: 'Eurogamer', source: 'Eurogamer', url: 'https://www.eurogamer.net/feed' },
  { name: 'PC Gamer', source: 'PC Gamer', url: 'https://www.pcgamer.com/rss/', defaultPlatform: 'PC' as const },
  { name: 'Gamespot Mashup', source: 'GameSpot', url: 'https://www.gamespot.com/feeds/mashup/' },
  { name: 'Push Square', source: 'Push Square', url: 'https://www.pushsquare.com/feeds/latest', defaultPlatform: 'PlayStation' as const },
  { name: 'Nintendo Life', source: 'Nintendo Life', url: 'https://www.nintendolife.com/feeds/latest', defaultPlatform: 'Nintendo' as const },
  { name: 'Pure Xbox', source: 'Pure Xbox', url: 'https://www.purexbox.com/feeds/latest', defaultPlatform: 'Xbox' as const },
  { name: 'Rock Paper Shotgun', source: 'Rock Paper Shotgun', url: 'https://www.rockpapershotgun.com/feed', defaultPlatform: 'PC' as const },
  { name: 'Destructoid', source: 'Destructoid', url: 'https://www.destructoid.com/feed/' },
  { name: 'Polygon', source: 'Polygon', url: 'https://www.polygon.com/rss/index.xml' },
  { name: 'Kotaku', source: 'Kotaku', url: 'https://kotaku.com/rss' },
  { name: 'VGC', source: 'VGC', url: 'https://www.videogameschronicle.com/feed/' },
  { name: 'GamesRadar', source: 'GamesRadar+', url: 'https://www.gamesradar.com/rss/' },
  { name: 'VG247', source: 'VG247', url: 'https://www.vg247.com/feed' },
  { name: 'PCGamesN', source: 'PCGamesN', url: 'https://www.pcgamesn.com/feed', defaultPlatform: 'PC' as const },
  { name: 'Gematsu', source: 'Gematsu', url: 'https://www.gematsu.com/feed' },
  { name: 'Siliconera', source: 'Siliconera', url: 'https://www.siliconera.com/feed/' },

  // 4. Officiella & Plattformsspecifika
  { name: 'Xbox Wire', source: 'Xbox Wire', url: 'https://news.xbox.com/en-us/feed/', defaultPlatform: 'Xbox' as const },
  { name: 'Nintendo Everything', source: 'Nintendo Everything', url: 'https://nintendoeverything.com/feed/', defaultPlatform: 'Nintendo' as const },
  { name: 'TouchArcade', source: 'TouchArcade', url: 'https://toucharcade.com/feed/' },
];

function extractImage(itemXml: string): string | null {
  // 1. media:content or media:thumbnail
  const mediaMatch = itemXml.match(/<media:(?:content|thumbnail)[^>]*url=["']([^"']+)["']/i);
  if (mediaMatch && mediaMatch[1]) return mediaMatch[1];

  // 2. enclosure url
  const enclosureMatch = itemXml.match(/<enclosure[^>]*url=["']([^"']+)["']/i);
  if (enclosureMatch && enclosureMatch[1]) return enclosureMatch[1];

  // 3. img tag inside description or content:encoded
  const imgMatch = itemXml.match(/<img[^>]*src=["']([^"']+)["']/i);
  if (imgMatch && imgMatch[1]) return imgMatch[1];

  return null;
}

function cleanText(str: string): string {
  return str
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/gi, '$1')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&#8217;/g, "'")
    .replace(/&#8216;/g, "'")
    .replace(/&#8220;/g, '"')
    .replace(/&#8221;/g, '"')
    .replace(/&#8211;/g, '–')
    .replace(/&#8212;/g, '—')
    .replace(/&nbsp;/g, ' ')
    .trim();
}

function parseFeedItems(
  xml: string,
  feedConfig: {
    name: string;
    source: string;
    defaultCategory?: 'Recension' | 'Nyhet' | 'Trailer' | 'Uppdatering' | 'Guide' | 'Förhandstitt';
    defaultPlatform?: 'PlayStation' | 'Xbox' | 'Nintendo' | 'PC' | 'Multi';
  }
): NewsItem[] {
  const items: NewsItem[] = [];
  const itemRegex = /<item[\s\S]*?<\/item>|<entry[\s\S]*?<\/entry>/gi;
  const matches = xml.match(itemRegex) || [];

  for (const itemXml of matches.slice(0, 50)) {
    try {
      const titleMatch = itemXml.match(/<title[\s\S]*?>([\s\S]*?)<\/title>/i);
      const rawTitle = titleMatch ? cleanText(titleMatch[1]) : '';
      if (!rawTitle) continue;

      let link = '';
      const linkMatch = itemXml.match(/<link[\s\S]*?>([\s\S]*?)<\/link>/i);
      if (linkMatch && linkMatch[1] && linkMatch[1].startsWith('http')) {
        link = linkMatch[1].trim();
      } else {
        const linkHrefMatch = itemXml.match(/<link[^>]*href=["']([^"']+)["']/i);
        if (linkHrefMatch && linkHrefMatch[1]) {
          link = linkHrefMatch[1].trim();
        }
      }

      const dateMatch =
        itemXml.match(/<pubDate[\s\S]*?>([\s\S]*?)<\/pubDate>/i) ||
        itemXml.match(/<published[\s\S]*?>([\s\S]*?)<\/published>/i) ||
        itemXml.match(/<updated[\s\S]*?>([\s\S]*?)<\/updated>/i);

      const pubDateStr = dateMatch ? cleanText(dateMatch[1]) : '';
      const pubDate = pubDateStr ? new Date(pubDateStr) : new Date();
      const timestamp = isNaN(pubDate.getTime()) ? Date.now() : pubDate.getTime();

      const descMatch =
        itemXml.match(/<description[\s\S]*?>([\s\S]*?)<\/description>/i) ||
        itemXml.match(/<summary[\s\S]*?>([\s\S]*?)<\/summary>/i);
      const summary = descMatch ? cleanText(descMatch[1]).slice(0, 220) : '';

      const image = extractImage(itemXml);

      // Extrahera RSS-kategorier
      const catMatches = itemXml.match(/<category[\s\S]*?>([\s\S]*?)<\/category>/gi) || [];
      const itemCategories = catMatches.map((c) => cleanText(c).toLowerCase());

      const lower = rawTitle.toLowerCase();
      const combinedText = (lower + ' ' + summary.toLowerCase() + ' ' + itemCategories.join(' '));

      // 1. Filtrera bort icke-spel (Bio, filmer, sport, politik & världshändelser)
      const nonGamingCategories = [
        'världens nyheter', 'sport', 'filmrecensioner', 'bio', 'filmer', 'film', 'blu-ray', 'tv-serier'
      ];
      const isNonGamingCat = itemCategories.some((c) => nonGamingCategories.includes(c.trim()));

      const nonGamingPhrases = [
        'movie review', 'filmrecension', 'film review', 'tv review', 'episode review', 'series review', 'season review',
        'toppar biolistan', 'på bio', 'biotoppen', 'box office', 'in theaters', 'coming to theaters',
        'fall movie preview', 'upcoming movie', 'trailer debut for movie', 'new movie trailer',
        'directors cut of film', 'netflix movie', 'kriget i ukraina', 'zelensky', 'vladimir putin',
        'donald trump', 'joe biden', 'kamala harris', 'högerextrema afd', 'valet i ', 'us open',
        'wimbledon', 'premier league', 'champions league', 'allsvenskan', 'herrsingel', 'damsingel',
        'tennisens', 'formula 1', 'formel 1'
      ];
      const hasNonGamingPhrase = nonGamingPhrases.some((p) => combinedText.includes(p));

      // Undantag om artikeln uttryckligen berör tv-spel
      const hasGamingSignal =
        combinedText.includes('video game') ||
        combinedText.includes('tv-spel') ||
        combinedText.includes('gameplay') ||
        combinedText.includes('ps5') ||
        combinedText.includes('xbox') ||
        combinedText.includes('nintendo') ||
        combinedText.includes('steam deck') ||
        combinedText.includes('speldemo');

      // TV-avsnitt / säsongsrecensioner och rena bio/film-artiklar
      const isTvOrMovie =
        /season\s+\d+.*episode\s+\d+/i.test(lower) ||
        /episode\s+\d+\s+review/i.test(lower) ||
        /season\s+\d+\s+review/i.test(lower) ||
        /series\s+review/i.test(lower) ||
        /movie\s+review/i.test(lower) ||
        /filmrecension/i.test(lower) ||
        /film\s+review/i.test(lower) ||
        (/\bmovies\b/i.test(lower) && (lower.includes('fall') || lower.includes('coming') || lower.includes('best') || lower.includes('watch') || lower.includes('top'))) ||
        (/\bfilmer\b/i.test(lower) && (lower.includes('bästa') || lower.includes('kommande') || lower.includes('höstens'))) ||
        lower.includes('box office') ||
        lower.includes('biolistan') ||
        lower.includes('biotoppen');

      if ((isNonGamingCat || hasNonGamingPhrase || isTvOrMovie) && !hasGamingSignal) {
        continue; // Hoppa över icke-spelrelaterade nyheter
      }

      // 2. Kategori-klassificering med strikt åtskillnad mellan Förhandstitt (Preview) och Recension (Review)
      const isPreview =
        lower.includes('preview') ||
        lower.includes('förhandstitt') ||
        lower.includes('hands-on') ||
        lower.includes('handson') ||
        lower.includes('first look') ||
        lower.includes('first-look') ||
        lower.includes('early impressions') ||
        lower.includes('sneak peek') ||
        itemCategories.some((c) => c.includes('preview') || c.includes('förhandstitt')) ||
        feedConfig.defaultCategory === 'Förhandstitt';

      let category: NewsItem['category'] = 'Nyhet';

      if (isPreview) {
        // Previews får ALDRIG Recension som kategori
        category = 'Förhandstitt';
      } else if (
        lower.startsWith('review:') ||
        lower.startsWith('recension:') ||
        lower.includes(' review') ||
        lower.includes(' recension') ||
        lower.includes('verdict') ||
        feedConfig.defaultCategory === 'Recension' ||
        feedConfig.name.includes('Reviews')
      ) {
        category = 'Recension';
      } else if (lower.includes('trailer') || lower.includes('gameplay video') || lower.includes('teaser trailer')) {
        category = 'Trailer';
      } else if (lower.includes('guide') || lower.includes('walkthrough') || lower.includes('how to')) {
        category = 'Guide';
      } else if (lower.includes('patch') || lower.includes('update') || lower.includes('hotfix') || lower.includes('uppdatering')) {
        category = 'Uppdatering';
      } else if (feedConfig.defaultCategory) {
        category = feedConfig.defaultCategory;
      }

      // Plattforms-klassificering
      let platform: NewsItem['platform'] = feedConfig.defaultPlatform || 'Multi';
      if (lower.includes('ps5') || lower.includes('ps4') || lower.includes('playstation')) {
        platform = 'PlayStation';
      } else if (lower.includes('xbox') || lower.includes('series x') || lower.includes('game pass')) {
        platform = 'Xbox';
      } else if (lower.includes('switch') || lower.includes('nintendo') || lower.includes('switch 2')) {
        platform = 'Nintendo';
      } else if (lower.includes('pc') || lower.includes('steam') || lower.includes('steam deck') || lower.includes('rtx')) {
        platform = 'PC';
      }

      items.push({
        id: `${feedConfig.source}-${timestamp}-${rawTitle.slice(0, 15)}`,
        title: rawTitle,
        source: feedConfig.source,
        link,
        published: pubDate.toISOString(),
        publishedTimestamp: timestamp,
        image,
        summary,
        category,
        platform,
      });
    } catch (e) {
      // Ignorera felaktiga element
    }
  }

  return items;
}

export async function GET(request: NextRequest) {
  try {
    const feedPromises = FEEDS.map(async (feed) => {
      try {
        const res = await fetch(feed.url, {
          signal: AbortSignal.timeout(3500),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
        });
        if (!res.ok) return [];
        const text = await res.text();
        return parseFeedItems(text, feed);
      } catch (err) {
        return [];
      }
    });

    const feedResults = await Promise.allSettled(feedPromises);
    let allNews: NewsItem[] = [];

    for (const result of feedResults) {
      if (result.status === 'fulfilled') {
        allNews.push(...result.value);
      }
    }

    // Sortera efter nyast först
    allNews.sort((a, b) => b.publishedTimestamp - a.publishedTimestamp);

    // Filtrera dubbletter
    const seenTitles = new Set<string>();
    const uniqueNews = allNews.filter((item) => {
      const simplified = item.title.toLowerCase().replace(/[^a-z0-9]/g, '');
      if (seenTitles.has(simplified)) return false;
      seenTitles.add(simplified);
      return true;
    });

    // Garantera att ALLA recensioner finns tillgängliga och inte trycks ut av dagsnyheter
    const reviews = uniqueNews.filter((item) => item.category === 'Recension');
    const generalNews = uniqueNews.filter((item) => item.category !== 'Recension');

    // Slå ihop alla färska recensioner med upp till 500 nyaste allmänna nyheter
    const combinedNews = [...reviews.slice(0, 250), ...generalNews.slice(0, 500)];
    combinedNews.sort((a, b) => b.publishedTimestamp - a.publishedTimestamp);

    return NextResponse.json(
      {
        news: combinedNews,
        reviewCount: reviews.length,
        totalCount: combinedNews.length,
      },
      {
        headers: {
          'Cache-Control': 'public, s-maxage=120, stale-while-revalidate=300',
        },
      }
    );
  } catch (error: any) {
    console.error('Error fetching news feeds:', error);
    return NextResponse.json(
      { error: 'Kunde inte hämta nyheter' },
      { status: 500 }
    );
  }
}
