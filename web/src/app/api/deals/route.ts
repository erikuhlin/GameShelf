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
  '4': 'Amazon',
  '5': 'GameStop',
  '6': 'Direct2Drive',
  '7': 'GOG',
  '8': 'EA / Origin',
  '9': 'Get Games',
  '10': 'Shiny Loot',
  '11': 'Humble Store',
  '12': 'Desura',
  '13': 'Ubisoft Store',
  '14': 'IndieGameStand',
  '15': 'Fanatical',
  '16': 'Gamesrocket',
  '17': 'Games Republic',
  '18': 'SilaGames',
  '19': 'Playfield',
  '20': 'ImperialGames',
  '21': 'WinGameStore',
  '22': 'FunStock',
  '23': 'GameBillet',
  '24': 'Voidu',
  '25': 'Epic Games Store',
  '26': 'Razer Game Store',
  '27': 'Gamesplanet',
  '28': 'Gamesload',
  '29': '2Game',
  '30': 'IndieGala',
  '31': 'Blizzard Shop',
  '32': 'AllYouPlay',
  '33': 'DLGamer',
  '34': 'Noctre',
  '35': 'DreamGame',
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
