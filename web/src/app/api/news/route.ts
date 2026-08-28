import { NextRequest, NextResponse } from 'next/server';

export const revalidate = 300; // Cache in 5 minutes

interface NewsItem {
  id: string;
  title: string;
  source: string;
  link: string;
  published: string;
  publishedTimestamp: number;
  image?: string | null;
  summary?: string;
  category?: string;
}

const FEEDS = [
  { name: 'IGN', url: 'https://www.ign.com/rss' },
  { name: 'Eurogamer', url: 'https://www.eurogamer.net/api/frontpage.rss' },
  { name: 'PC Gamer', url: 'https://www.pcgamer.com/rss/' },
  { name: 'Polygon', url: 'https://www.polygon.com/rss/index.xml' },
  { name: 'Kotaku', url: 'https://kotaku.com/rss' },
  { name: 'PlayStation Blog', url: 'https://blog.playstation.com/feed/' },
  { name: 'Xbox Wire', url: 'https://news.xbox.com/en-us/feed/' },
  { name: 'Nintendo Life', url: 'https://www.nintendolife.com/feeds/latest' },
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
    .replace(/&nbsp;/g, ' ')
    .trim();
}

function parseFeedItems(xml: string, sourceName: string): NewsItem[] {
  const items: NewsItem[] = [];
  const itemRegex = /<item[\s\S]*?<\/item>|<entry[\s\S]*?<\/entry>/gi;
  const matches = xml.match(itemRegex) || [];

  for (const itemXml of matches.slice(0, 15)) {
    try {
      const titleMatch = itemXml.match(/<title[\s\S]*?>([\s\S]*?)<\/title>/i);
      const title = titleMatch ? cleanText(titleMatch[1]) : '';
      if (!title) continue;

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
      const summary = descMatch ? cleanText(descMatch[1]).slice(0, 200) : '';

      const image = extractImage(itemXml);

      let category = 'Nyhet';
      const lower = title.toLowerCase();
      if (lower.includes('review') || lower.includes('recension')) category = 'Recension';
      else if (lower.includes('trailer') || lower.includes('gameplay')) category = 'Trailer';
      else if (lower.includes('update') || lower.includes('patch')) category = 'Uppdatering';
      else if (lower.includes('preview') || lower.includes('hands-on')) category = 'Förhandstitt';

      items.push({
        id: `${sourceName}-${timestamp}-${title.slice(0, 15)}`,
        title,
        source: sourceName,
        link,
        published: pubDate.toISOString(),
        publishedTimestamp: timestamp,
        image,
        summary,
        category,
      });
    } catch (e) {
      // Ignorera felaktiga element
    }
  }

  return items;
}

export async function GET(request: NextRequest) {
  try {
    const feedPromises = FEEDS.map(async (f) => {
      try {
        const res = await fetch(f.url, {
          headers: {
            'User-Agent': 'Gameshelf/1.0 (Web News Aggregator; +https://mygameshelf.vercel.app)',
          },
          next: { revalidate: 300 },
        });
        if (!res.ok) return [];
        const text = await res.text();
        return parseFeedItems(text, f.name);
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

    // Ta bort eventuella dubbletter i rubrik
    const seenTitles = new Set<string>();
    const uniqueNews = allNews.filter((item) => {
      const simplified = item.title.toLowerCase().replace(/[^a-z0-9]/g, '');
      if (seenTitles.has(simplified)) return false;
      seenTitles.add(simplified);
      return true;
    });

    return NextResponse.json({
      news: uniqueNews.slice(0, 60),
    });
  } catch (error: any) {
    console.error('Error fetching news feeds:', error);
    return NextResponse.json(
      { error: 'Kunde inte hämta nyheter' },
      { status: 500 }
    );
  }
}
