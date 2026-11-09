//
// titleMatcher.ts
// Gameshelf
//
// Strikt och robust matchning av speltitlar mot externa källor (Steam, Metacritic, CheapShark etc.)
//

const ROMAN_NUMERAL_MAP: Record<string, string> = {
  I: '1', II: '2', III: '3', IV: '4', V: '5',
  VI: '6', VII: '7', VIII: '8', IX: '9', X: '10',
  XI: '11', XII: '12', XIII: '13', XIV: '14', XV: '15',
  XVI: '16', XVII: '17', XVIII: '18', XIX: '19', XX: '20',
  XXI: '21', XXII: '22', XXIII: '23', XXIV: '24', XXV: '25',
  XXVI: '26', XXVII: '27', XXVIII: '28', XXIX: '29', XXX: '30',
};

const RECOGNIZED_EDITION_WORDS = new Set([
  'edition', 'definitive', 'remastered', 'remake', 'enhanced', 'deluxe',
  'special', 'gold', 'goty', 'game', 'year', 'complete', 'anniversary',
  'bundle', 'directors', 'cut', 'vr', 'standard', 'collector', 'collectors',
  'premium', 'ultimate', 'hd', 'the', 'of', 'and', 'original', 'intergrade'
]);

const BAD_WORDS = ['soundtrack', 'season pass', 'dlc', 'content', 'artbook', 'ost'];

export function tokenizeForMatching(title: string): string[] {
  // Normalisera accenter/diakritiska tecken (t.ex. Ragnarök -> Ragnarok)
  const normalized = title
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();

  return normalized
    .replace(/[:\-–—'"’™®()\[\]!?,\.]/g, ' ')
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .map((token) => {
      const upper = token.toUpperCase();
      return ROMAN_NUMERAL_MAP[upper] || token;
    });
}

export function isSequenceNumber(token: string): boolean {
  const num = parseInt(token, 10);
  if (isNaN(num)) return false;
  // Årtal (1970–2040) betraktas inte som sekvensnummer
  return num < 1970 || num > 2040;
}

export function isTitleMatch(gameTitle: string, candidateTitle: string): boolean {
  const t1 = tokenizeForMatching(gameTitle);
  const t2 = tokenizeForMatching(candidateTitle);

  if (t1.length === 0 || t2.length === 0) return false;
  if (t1.join(' ') === t2.join(' ')) return true;

  const lowerCandidate = candidateTitle.toLowerCase();
  const lowerGame = gameTitle.toLowerCase();

  // Förkasta om kandidaten är ett soundtrack/dlc men inte själva spelet
  if (BAD_WORDS.some((bw) => lowerCandidate.includes(bw) && !lowerGame.includes(bw))) {
    return false;
  }

  // Identifiera sekvensnummer (t.ex. 6 i "GTA 6" / "GTA VI", 5 i "GTA V")
  const numbers1 = t1.filter(isSequenceNumber);
  const numbers2 = t2.filter(isSequenceNumber);

  // Om sekvensnumren skiljer sig (t.ex. GTA VI vs GTA Vice City, eller GTA 6 vs GTA 5) -> förkasta!
  if (numbers1.length !== numbers2.length || !numbers1.every((n, i) => n === numbers2[i])) {
    return false;
  }

  // Om kandidaten börjar med hela speltiteln
  if (t2.length >= t1.length) {
    const prefixMatches = t1.every((tok, idx) => tok === t2[idx]);
    if (prefixMatches) {
      const remainder = t2.slice(t1.length);
      // Resten måste uteslutande bestå av godkända utgåveord (t.ex. "The Definitive Edition", "GOTY")
      if (remainder.every((tok) => RECOGNIZED_EDITION_WORDS.has(tok))) {
        return true;
      }
    }
  }

  // Om speltiteln är längre än kandidaten
  if (t1.length > t2.length) {
    const prefixMatches = t2.every((tok, idx) => tok === t1[idx]);
    if (prefixMatches) {
      const remainder = t1.slice(t2.length);
      if (remainder.every((tok) => RECOGNIZED_EDITION_WORDS.has(tok))) {
        return true;
      }
    }
  }

  return false;
}
