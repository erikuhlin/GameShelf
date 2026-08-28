/**
 * Smart Alias- och Akronym-ordbok för spel.
 * Mappar vanliga förkortningar, akronymer och slang till officiella speltitlar för IGDB.
 */

const EXACT_ALIASES: Record<string, string> = {
  // Grand Theft Auto
  'gta 6': 'Grand Theft Auto VI',
  'gta vi': 'Grand Theft Auto VI',
  'gta 5': 'Grand Theft Auto V',
  'gta v': 'Grand Theft Auto V',
  'gta 4': 'Grand Theft Auto IV',
  'gta iv': 'Grand Theft Auto IV',
  'gta sa': 'Grand Theft Auto: San Andreas',
  'gta san andreas': 'Grand Theft Auto: San Andreas',
  'gta vc': 'Grand Theft Auto: Vice City',
  'gta vice city': 'Grand Theft Auto: Vice City',
  'gta 3': 'Grand Theft Auto III',
  'gta iii': 'Grand Theft Auto III',
  'gta': 'Grand Theft Auto',

  // God of War
  'gow ragnarok': 'God of War Ragnarök',
  'gow ragnarök': 'God of War Ragnarök',
  'gow 2018': 'God of War',
  'gow 4': 'God of War',
  'gow 3': 'God of War III',
  'gow iii': 'God of War III',
  'gow 2': 'God of War II',
  'gow ii': 'God of War II',
  'gow 1': 'God of War',
  'gow': 'God of War',

  // The Legend of Zelda
  'botw': 'The Legend of Zelda: Breath of the Wild',
  'breath of the wild': 'The Legend of Zelda: Breath of the Wild',
  'totk': 'The Legend of Zelda: Tears of the Kingdom',
  'tears of the kingdom': 'The Legend of Zelda: Tears of the Kingdom',
  'oot': 'The Legend of Zelda: Ocarina of Time',
  'ocarina of time': 'The Legend of Zelda: Ocarina of Time',
  'majora': "The Legend of Zelda: Majora's Mask",
  'majoras mask': "The Legend of Zelda: Majora's Mask",
  'twilight princess': 'The Legend of Zelda: Twilight Princess',
  'wind waker': 'The Legend of Zelda: The Wind Waker',
  'alttp': 'The Legend of Zelda: A Link to the Past',
  'link to the past': 'The Legend of Zelda: A Link to the Past',
  'zelda': 'The Legend of Zelda',

  // Resident Evil
  're4 remake': 'Resident Evil 4',
  're 4 remake': 'Resident Evil 4',
  're4': 'Resident Evil 4',
  're 4': 'Resident Evil 4',
  're2 remake': 'Resident Evil 2',
  're 2 remake': 'Resident Evil 2',
  're2': 'Resident Evil 2',
  're 2': 'Resident Evil 2',
  're3 remake': 'Resident Evil 3',
  're 3 remake': 'Resident Evil 3',
  're3': 'Resident Evil 3',
  're 3': 'Resident Evil 3',
  're7': 'Resident Evil 7: Biohazard',
  're 7': 'Resident Evil 7: Biohazard',
  're8': 'Resident Evil Village',
  're 8': 'Resident Evil Village',
  'village': 'Resident Evil Village',
  'biohazard': 'Resident Evil',
  're': 'Resident Evil',

  // Final Fantasy
  'ff7 remake': 'Final Fantasy VII Remake',
  'ffvii remake': 'Final Fantasy VII Remake',
  'ff7 rebirth': 'Final Fantasy VII Rebirth',
  'ffvii rebirth': 'Final Fantasy VII Rebirth',
  'ff7': 'Final Fantasy VII',
  'ffvii': 'Final Fantasy VII',
  'ff16': 'Final Fantasy XVI',
  'ffxvi': 'Final Fantasy XVI',
  'ff15': 'Final Fantasy XV',
  'ffxv': 'Final Fantasy XV',
  'ff14': 'Final Fantasy XIV',
  'ffxiv': 'Final Fantasy XIV',
  'ff10': 'Final Fantasy X',
  'ffx': 'Final Fantasy X',
  'ff9': 'Final Fantasy IX',
  'ffix': 'Final Fantasy IX',
  'ff8': 'Final Fantasy VIII',
  'ffviii': 'Final Fantasy VIII',
  'ff6': 'Final Fantasy VI',
  'ffvi': 'Final Fantasy VI',
  'ff': 'Final Fantasy',

  // Cyberpunk & Witcher
  'cp2077': 'Cyberpunk 2077',
  'cp 2077': 'Cyberpunk 2077',
  'phantom liberty': 'Cyberpunk 2077: Phantom Liberty',
  'tw3': 'The Witcher 3: Wild Hunt',
  'witcher 3': 'The Witcher 3: Wild Hunt',
  'witcher 2': 'The Witcher 2: Assassins of Kings',
  'witcher 1': 'The Witcher',
  'witcher': 'The Witcher',

  // Red Dead Redemption
  'rdr2': 'Red Dead Redemption 2',
  'rdr 2': 'Red Dead Redemption 2',
  'rdr1': 'Red Dead Redemption',
  'rdr': 'Red Dead Redemption',

  // Call of Duty
  'cod mw3': 'Call of Duty: Modern Warfare III',
  'mw3': 'Call of Duty: Modern Warfare III',
  'cod mw2': 'Call of Duty: Modern Warfare II',
  'mw2': 'Call of Duty: Modern Warfare II',
  'cod mw': 'Call of Duty: Modern Warfare',
  'mw': 'Call of Duty: Modern Warfare',
  'cod bo6': 'Call of Duty: Black Ops 6',
  'bo6': 'Call of Duty: Black Ops 6',
  'black ops 6': 'Call of Duty: Black Ops 6',
  'cod warzone': 'Call of Duty: Warzone',
  'warzone': 'Call of Duty: Warzone',
  'cod': 'Call of Duty',

  // Souls & Elden Ring
  'sote': 'Elden Ring: Shadow of the Erdtree',
  'shadow of the erdtree': 'Elden Ring: Shadow of the Erdtree',
  'ds3': 'Dark Souls III',
  'ds 3': 'Dark Souls III',
  'ds2': 'Dark Souls II',
  'ds 2': 'Dark Souls II',
  'ds1': 'Dark Souls',
  'ds 1': 'Dark Souls',
  'bb': 'Bloodborne',

  // Monster Hunter
  'mh wilds': 'Monster Hunter Wilds',
  'mhw wilds': 'Monster Hunter Wilds',
  'mhw': 'Monster Hunter: World',
  'mh world': 'Monster Hunter: World',
  'mhr': 'Monster Hunter Rise',
  'mh rise': 'Monster Hunter Rise',
  'mh': 'Monster Hunter',

  // Metroid
  'mp4': 'Metroid Prime 4: Beyond',
  'metroid prime 4': 'Metroid Prime 4: Beyond',
  'dread': 'Metroid Dread',
  'metroid dread': 'Metroid Dread',

  // Assassin's Creed
  'ac shadows': "Assassin's Creed Shadows",
  'ac mirage': "Assassin's Creed Mirage",
  'ac valhalla': "Assassin's Creed Valhalla",
  'ac odyssey': "Assassin's Creed Odyssey",
  'ac origins': "Assassin's Creed Origins",
  'ac black flag': "Assassin's Creed IV: Black Flag",
  'ac4': "Assassin's Creed IV: Black Flag",
  'ac': "Assassin's Creed",

  // Fighting games
  'sf6': 'Street Fighter 6',
  'sf 6': 'Street Fighter 6',
  'sf5': 'Street Fighter V',
  'sfv': 'Street Fighter V',
  'mk1': 'Mortal Kombat 1',
  'mk 1': 'Mortal Kombat 1',
  'mk11': 'Mortal Kombat 11',
  't8': 'Tekken 8',
  'tk8': 'Tekken 8',
  't7': 'Tekken 7',
  'tk7': 'Tekken 7',
  'ssbu': 'Super Smash Bros. Ultimate',
  'smash ultimate': 'Super Smash Bros. Ultimate',
  'smash': 'Super Smash Bros.',
};

/**
 * Löser upp en sökfras genom att kontrollera akronymer och vanliga prefix.
 */
export function resolveGameAlias(query: string): string {
  const trimmed = query.trim();
  if (!trimmed) return query;

  const normalized = trimmed.toLowerCase();

  // 1. Exakt matchning
  if (EXACT_ALIASES[normalized]) {
    return EXACT_ALIASES[normalized];
  }

  // 2. Prefix-matchning för förkortningar som börjar med gta, gow, ff etc.
  for (const [alias, replacement] of Object.entries(EXACT_ALIASES)) {
    if (normalized.startsWith(alias + ' ')) {
      const remainder = trimmed.slice(alias.length).trim();
      return `${replacement} ${remainder}`;
    }
  }

  return trimmed;
}
