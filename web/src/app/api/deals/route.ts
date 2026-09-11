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
  '2': 'GamersGate',
  '3': 'GreenManGaming',
  '7': 'GOG',
  '11': 'Humble Store',
  '25': 'Epic Games',
  '31': 'Blizzard',
};

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const title = searchParams.get('title')?.trim();

  if (!title) {
    return NextResponse.json({ error: 'Title is required' }, { status: 400 });
  }

  try {
    const encoded = encodeURIComponent(title);
    const headers = { 'User-Agent': 'GameshelfApp/1.0' };

    // 1. Försök med exact=1
    let response = await fetch(`https://www.cheapshark.com/api/1.0/deals?title=${encoded}&exact=1`, {
      headers,
      next: { revalidate: 3600 },
    });

    let deals = response.ok ? await response.json() : [];

    // Om inga resultat, prova utan exact med pageSize=3
    if (!Array.isArray(deals) || deals.length === 0) {
      const fallbackResp = await fetch(`https://www.cheapshark.com/api/1.0/deals?title=${encoded}&pageSize=3`, {
        headers,
        next: { revalidate: 3600 },
      });
      if (fallbackResp.ok) {
        deals = await fallbackResp.json();
      }
    }

    if (!Array.isArray(deals) || deals.length === 0) {
      return NextResponse.json({ deal: null });
    }

    // Hitta bästa erbjudande (i första hand det med aktiv rea, annars första)
    const best = deals.find((d: any) => d.isOnSale === '1') || deals[0];
    const sPrice = parseFloat(best.salePrice) || 0;
    const nPrice = parseFloat(best.normalPrice) || 0;
    const savPct = parseFloat(best.savings) || 0;
    const onSale = best.isOnSale === '1' && savPct > 0;
    const storeID = best.storeID || '1';
    const storeName = STORE_NAMES[storeID] || 'Digital Butik';

    let dealURL: string | null = null;
    if (best.dealID) {
      dealURL = `https://www.cheapshark.com/redirect?dealID=${encodeURIComponent(best.dealID)}`;
    }

    let cheapestPriceEver: number | null = null;
    let isHistoricalLow = false;

    if (best.gameID) {
      try {
        const lookupResp = await fetch(`https://www.cheapshark.com/api/1.0/games?id=${best.gameID}`, {
          headers,
          next: { revalidate: 7200 },
        });
        if (lookupResp.ok) {
          const gameData = await lookupResp.json();
          if (gameData?.cheapestPriceEver?.price) {
            cheapestPriceEver = parseFloat(gameData.cheapestPriceEver.price);
            if (onSale && sPrice <= (cheapestPriceEver + 0.05)) {
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
