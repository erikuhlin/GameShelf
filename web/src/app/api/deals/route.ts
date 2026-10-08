import { NextRequest, NextResponse } from 'next/server';

export const dynamic = 'force-dynamic';
export const revalidate = 300; // 5 minuter

export interface GameDealResponse {
  gameTitle: string;
  isOnSale: boolean;
  salePrice: number;
  normalPrice: number;
  savingsPercent: number;
  storeID: string;
  storeName: string;
  dealID: string;
  steamAppID: string | null;
  dealURL: string | null;
  cheapestPriceEver: number | null;
  isHistoricalLow: boolean;
  fetchedAt: string;
}

const STORE_NAMES: Record<string, string> = {
  '1': 'Steam',
  '7': 'GOG',
  '25': 'Epic Games Store',
};

const ROMAN_NUMERAL_MAP: Record<string, string> = {
  I: '1', II: '2', III: '3', IV: '4', V: '5',
  VI: '6', VII: '7', VIII: '8', IX: '9', X: '10',
  XI: '11', XII: '12', XIII: '13', XIV: '14', XV: '15',
  XVI: '16', XVII: '17', XVIII: '18', XIX: '19', XX: '20',
  XXI: '21', XXII: '22', XXIII: '23', XXIV: '24', XXV: '25',
  XXVI: '26', XXVII: '27', XXVIII: '28', XXIX: '29', XXX: '30'
};

const RECOGNIZED_EDITION_WORDS = new Set([
  'edition', 'definitive', 'remastered', 'remake', 'enhanced', 'deluxe',
  'special', 'gold', 'goty', 'game', 'year', 'complete', 'anniversary',
  'bundle', 'directors', 'cut', 'vr', 'standard', 'collector', 'collectors',
  'premium', 'ultimate'
]);

function tokenizeForMatching(title: string): string[] {
  return title
    .toLowerCase()
    .replace(/[:\-–'"™®()]/g, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .map(token => {
      const upper = token.toUpperCase();
      return ROMAN_NUMERAL_MAP[upper] || token;
    });
}

function isSequenceNumber(token: string): boolean {
  const num = parseInt(token, 10);
  if (isNaN(num)) return false;
  // Årtal (1970–2040) betraktas inte som sekvensnummer
  return num < 1970 || num > 2040;
}

function isTitleMatch(gameTitle: string, dealTitle: string): boolean {
  const t1 = tokenizeForMatching(gameTitle);
  const t2 = tokenizeForMatching(dealTitle);

  if (t1.length === 0 || t2.length === 0) return false;
  if (t1.join(' ') === t2.join(' ')) return true;

  const lowerDeal = dealTitle.toLowerCase();
  const badWords = ['soundtrack', 'season pass', 'dlc', 'content', 'artbook', 'ost'];
  if (badWords.some(bw => lowerDeal.includes(bw))) return false;

  // Identifiera sekvensnummer (filtrera bort årtal som 2005, 2015 etc.)
  const numbers1 = t1.filter(isSequenceNumber);
  const numbers2 = t2.filter(isSequenceNumber);

  // Om sekvensnumren skiljer sig (t.ex. GTA VI vs GTA Vice City eller Fallout 3 vs Fallout 4)
  if (numbers1.length !== numbers2.length || !numbers1.every((n, i) => n === numbers2[i])) {
    return false;
  }

  // Om dealTitle börjar med hela gameTitle
  if (t2.length >= t1.length) {
    const prefixMatches = t1.every((tok, idx) => tok === t2[idx]);
    if (prefixMatches) return true;
  }

  // Om gameTitle är längre än dealTitle, men resten bara är utgåveord
  if (t1.length > t2.length) {
    const prefixMatches = t2.every((tok, idx) => tok === t1[idx]);
    if (prefixMatches) {
      const remainder = t1.slice(t2.length);
      if (remainder.every(tok => RECOGNIZED_EDITION_WORDS.has(tok))) {
        return true;
      }
    }
  }

  return false;
}

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const title = searchParams.get('title')?.trim();

  if (!title) {
    return NextResponse.json({ error: 'Title is required' }, { status: 400 });
  }

  try {
    const encoded = encodeURIComponent(title);
    const headers = { 'User-Agent': 'GameshelfApp/1.0' };

    // 1. Försök med exact=1 och endast butikerna Steam (1), GOG (7), Epic Games Store (25)
    let response = await fetch(
      `https://www.cheapshark.com/api/1.0/deals?title=${encoded}&storeID=1,7,25&exact=1`,
      {
        headers,
        next: { revalidate: 3600 },
      }
    );

    let deals = response.ok ? await response.json() : [];

    // Om inga resultat, prova utan exact med pageSize=5
    if (!Array.isArray(deals) || deals.length === 0) {
      const fallbackResp = await fetch(
        `https://www.cheapshark.com/api/1.0/deals?title=${encoded}&storeID=1,7,25&pageSize=5`,
        {
          headers,
          next: { revalidate: 3600 },
        }
      );
      if (fallbackResp.ok) {
        deals = await fallbackResp.json();
      }
    }

    if (!Array.isArray(deals) || deals.length === 0) {
      return NextResponse.json({ deal: null });
    }

    // Filtrera strikt till endast Steam (1), GOG (7) och Epic Games (25)
    const validStoresDeals = deals.filter((d: any) => {
      const stID = String(d.storeID || '');
      return stID === '1' || stID === '7' || stID === '25';
    });

    // Strikt titelverifiering: förhindra att DLC, expansioner eller fel spel matchar
    const matchingDeals = validStoresDeals.filter((d: any) => {
      return isTitleMatch(title, d.title || '');
    });

    if (matchingDeals.length === 0) {
      return NextResponse.json({ deal: null });
    }

    // Hitta bästa erbjudande (i första hand det med aktiv rea och högst rabatt)
    const onSaleDeals = matchingDeals.filter(
      (d: any) => d.isOnSale === '1' && (parseFloat(d.savings) || 0) > 0
    );
    let best: any;
    if (onSaleDeals.length > 0) {
      best = onSaleDeals.reduce((max: any, curr: any) =>
        (parseFloat(curr.savings) || 0) > (parseFloat(max.savings) || 0) ? curr : max
      );
    } else {
      best = matchingDeals[0];
    }

    const sPrice = parseFloat(best.salePrice) || 0;
    const nPrice = parseFloat(best.normalPrice) || 0;
    const savPct = parseFloat(best.savings) || 0;
    const onSale = best.isOnSale === '1' && savPct > 0;
    const storeID = String(best.storeID || '1');
    const storeName = STORE_NAMES[storeID] || 'PC Store';

    let dealURL: string | null = null;
    if (storeID === '1' && best.steamAppID) {
      dealURL = `https://store.steampowered.com/app/${best.steamAppID}`;
    } else if (best.dealID) {
      dealURL = `https://www.cheapshark.com/redirect?dealID=${best.dealID}`;
    }

    let cheapestPriceEver: number | null = null;
    let isHistoricalLow = false;

    if (best.gameID) {
      try {
        const lookupResp = await fetch(
          `https://www.cheapshark.com/api/1.0/games?id=${best.gameID}`,
          {
            headers,
            next: { revalidate: 7200 },
          }
        );
        if (lookupResp.ok) {
          const gameData = await lookupResp.json();
          if (gameData?.cheapestPriceEver?.price) {
            cheapestPriceEver = parseFloat(gameData.cheapestPriceEver.price);
            if (onSale && sPrice <= cheapestPriceEver + 0.05) {
              isHistoricalLow = true;
            }
          }
        }
      } catch (e) {
        // Ignorera fel för lookup
      }
    }

    const result: GameDealResponse = {
      gameTitle: best.title || title,
      isOnSale: onSale,
      salePrice: sPrice,
      normalPrice: nPrice,
      savingsPercent: savPct,
      storeID,
      storeName,
      dealID: best.dealID || '',
      steamAppID: best.steamAppID || null,
      dealURL,
      cheapestPriceEver,
      isHistoricalLow,
      fetchedAt: new Date().toISOString(),
    };

    return NextResponse.json({ deal: result });
  } catch (error: any) {
    return NextResponse.json({ error: error.message || 'Failed to fetch deals' }, { status: 500 });
  }
}
