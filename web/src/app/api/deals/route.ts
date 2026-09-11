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

function normalizeForComparison(title: string): string {
  return title
    .toLowerCase()
    .replace(/[:\-–'"™®]/g, '')
    .trim()
    .replace(/\s+/g, ' ');
}

function isTitleMatch(gameTitle: string, dealTitle: string): boolean {
  const clean1 = normalizeForComparison(gameTitle);
  const clean2 = normalizeForComparison(dealTitle);
  if (clean1 === clean2) return true;

  if (clean2.startsWith(clean1)) {
    const lower = dealTitle.toLowerCase();
    if (
      lower.includes('soundtrack') ||
      lower.includes('season pass') ||
      lower.includes('dlc') ||
      lower.includes('content') ||
      lower.includes('artbook')
    ) {
      return false;
    }
    return true;
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
