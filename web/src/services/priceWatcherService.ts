import { Game } from '@/types/game';

export interface GameDeal {
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

export interface StoreQuickLink {
  id: string;
  name: string;
  url: string;
  category: 'PlayStation' | 'Nintendo' | 'Xbox' | 'PC';
  badgeColor: string;
}

const CACHE_KEY = 'gameshelf_deals_cache_v1';
const CACHE_TTL_MS = 4 * 60 * 60 * 1000; // 4 timmar

let inMemoryCache: Record<string, GameDeal> | null = null;

function getCache(): Record<string, GameDeal> {
  if (inMemoryCache) return inMemoryCache;
  if (typeof window === 'undefined') return {};

  try {
    const raw = localStorage.getItem(CACHE_KEY);
    if (raw) {
      const parsed = JSON.parse(raw);
      const now = Date.now();
      const valid: Record<string, GameDeal> = {};
      for (const [key, val] of Object.entries(parsed)) {
        const deal = val as GameDeal;
        if (deal && deal.fetchedAt && now - new Date(deal.fetchedAt).getTime() < CACHE_TTL_MS) {
          valid[key] = deal;
        }
      }
      inMemoryCache = valid;
      return valid;
    }
  } catch (e) {
    console.warn('Failed to parse deals cache', e);
  }
  inMemoryCache = {};
  return {};
}

function saveCache(cache: Record<string, GameDeal>) {
  inMemoryCache = cache;
  if (typeof window === 'undefined') return;
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify(cache));
  } catch (e) {
    // Ignore storage quota errors
  }
}

export function normalizeTitle(title: string): string {
  return title.trim().toLowerCase();
}

/**
 * Hämtar deal för en enskild speltitel
 */
export async function fetchGameDeal(title: string): Promise<GameDeal | null> {
  const normKey = normalizeTitle(title);
  const cache = getCache();

  if (cache[normKey]) {
    const cached = cache[normKey];
    if (Date.now() - new Date(cached.fetchedAt).getTime() < CACHE_TTL_MS) {
      return cached;
    }
  }

  try {
    const res = await fetch(`/api/deals?title=${encodeURIComponent(title)}`);
    if (!res.ok) return null;
    const data = await res.json();
    if (data && data.deal) {
      const deal = data.deal as GameDeal;
      cache[normKey] = deal;
      saveCache({ ...cache, [normKey]: deal });
      return deal;
    }
  } catch (err) {
    console.warn(`Could not fetch deal for ${title}:`, err);
  }

  return null;
}

/**
 * Hämtar deals för en uppsättning spel (parallellt med begränsning)
 */
export async function fetchDealsForGames(games: Game[]): Promise<Record<string, GameDeal>> {
  const cache = getCache();
  const needed: Game[] = [];

  for (const g of games) {
    const key = normalizeTitle(g.title);
    const existing = cache[key];
    if (!existing || Date.now() - new Date(existing.fetchedAt).getTime() >= CACHE_TTL_MS) {
      needed.push(g);
    }
  }

  if (needed.length === 0) {
    return cache;
  }

  // Batch om 3 åt gången
  const batchSize = 3;
  for (let i = 0; i < needed.length; i += batchSize) {
    const chunk = needed.slice(i, i + batchSize);
    await Promise.all(
      chunk.map(async (g) => {
        try {
          const res = await fetch(`/api/deals?title=${encodeURIComponent(g.title)}`);
          if (res.ok) {
            const data = await res.json();
            if (data?.deal) {
              cache[normalizeTitle(g.title)] = data.deal;
            }
          }
        } catch (e) {
          // Ignorera individuella fel
        }
      })
    );
  }

  saveCache({ ...cache });
  return { ...cache };
}

/**
 * Genererar smarta 1-klicks butikslänkar för spelets plattformar
 */
export function getStoreLinks(game: Partial<Game>, deal?: GameDeal | null): StoreQuickLink[] {
  const links: StoreQuickLink[] = [];
  const title = game.title?.trim() || '';
  if (!title) return links;

  const encodedTitle = encodeURIComponent(title);
  const platforms = (game.platforms || []).map((p) => p.toLowerCase());

  // 1. PlayStation
  const hasPS = platforms.some(
    (p) => p.includes('playstation') || p.includes('ps4') || p.includes('ps5') || p.includes('ps3')
  );
  if (hasPS) {
    links.push({
      id: 'playstation',
      name: 'PlayStation Store',
      category: 'PlayStation',
      url: `https://store.playstation.com/sv-se/search/${encodedTitle}`,
      badgeColor: 'bg-blue-600/20 text-blue-400 border-blue-500/30 hover:bg-blue-600/30',
    });
  }

  // 2. Nintendo Switch
  const hasNintendo = platforms.some((p) => p.includes('switch') || p.includes('nintendo'));
  if (hasNintendo) {
    links.push({
      id: 'nintendo',
      name: 'Nintendo eShop',
      category: 'Nintendo',
      url: `https://store.nintendo.se/sv/search?q=${encodedTitle}`,
      badgeColor: 'bg-red-600/20 text-red-400 border-red-500/30 hover:bg-red-600/30',
    });
  }

  // 3. Xbox
  const hasXbox = platforms.some(
    (p) => p.includes('xbox') || p.includes('series x') || p.includes('series s') || p.includes('one')
  );
  if (hasXbox) {
    links.push({
      id: 'xbox',
      name: 'Xbox Store',
      category: 'Xbox',
      url: `https://www.xbox.com/sv-SE/games/store/search?q=${encodedTitle}`,
      badgeColor: 'bg-emerald-600/20 text-emerald-400 border-emerald-500/30 hover:bg-emerald-600/30',
    });
  }

  // 4. PC / Steam
  const hasPC =
    platforms.some(
      (p) => p.includes('pc') || p.includes('windows') || p.includes('steam') || p.includes('mac')
    ) || platforms.length === 0;

  if (hasPC) {
    let steamUrl = `https://store.steampowered.com/search/?term=${encodedTitle}`;
    if (deal?.steamAppID) {
      steamUrl = `https://store.steampowered.com/app/${deal.steamAppID}`;
    }
    links.push({
      id: 'steam',
      name: 'Steam Store',
      category: 'PC',
      url: steamUrl,
      badgeColor: 'bg-cyan-600/20 text-cyan-400 border-cyan-500/30 hover:bg-cyan-600/30',
    });
  }

  return links;
}
