// Spel-DNA Rule Engine for Gameshelf Web
import { Game } from '@/types/game';
import { SpelDNAProfile, SpelDNATile } from '@/types/profile';

export function calculateSpelDNA(
  games: Game[],
  playFor: string[] = []
): SpelDNAProfile | null {
  const ownedGames = games.filter((g) => g.is_owned);
  const wishlistGames = games.filter((g) => !g.is_owned);

  // Minimikrav: minst 5 ägda spel i samlingen
  if (ownedGames.length < 5) {
    return null;
  }

  const totalOwned = ownedGames.length;
  const completedCount = ownedGames.filter(
    (g) => g.status === 'completed' || (g.status as string) === 'Klar'
  ).length;
  const completionRate = completedCount / totalOwned;

  // 1. Räkna genrefördelning
  const genreCounts: Record<string, number> = {};
  for (const game of ownedGames) {
    for (const genre of game.genres || []) {
      const trimmed = genre.trim();
      if (!trimmed) continue;
      genreCounts[trimmed] = (genreCounts[trimmed] || 0) + 1;
    }
  }

  const sortedGenres = Object.entries(genreCounts).sort((a, b) => b[1] - a[1]);
  const topGenreName = sortedGenres[0]?.[0] || 'Okänd';
  const topGenreCount = sortedGenres[0]?.[1] || 0;
  const topGenreShare = topGenreCount / totalOwned;
  const activeGenreCount = Object.keys(genreCounts).length;

  const countForKeywords = (keywords: string[]) => {
    let count = 0;
    for (const [name, cnt] of Object.entries(genreCounts)) {
      const lower = name.toLowerCase();
      if (keywords.some((kw) => lower.includes(kw))) {
        count += cnt;
      }
    }
    return count;
  };

  const rpgCount = countForKeywords(['rpg', 'rollspel', 'role-playing', 'jrpg']);
  const rpgShare = rpgCount / totalOwned;

  const horrorCount = countForKeywords(['skräck', 'horror', 'survival horror']);
  const horrorShare = horrorCount / totalOwned;

  const shooterCount = countForKeywords(['shooter', 'fps', 'skjutspel', 'krig', 'tactical']);
  const shooterShare = shooterCount / totalOwned;

  const indieCount = countForKeywords(['indie', 'puzzle', 'pussel']);
  const indieShare = indieCount / totalOwned;

  const strategyCount = countForKeywords(['strategi', 'strategy', 'taktik', 'tactical']);
  const strategyShare = strategyCount / totalOwned;

  const cozyCount = countForKeywords(['simulator', 'pussel', 'puzzle', 'äventyr', 'adventure', 'cozy']);
  const cozyShare = cozyCount / totalOwned;

  const soulsCount = ownedGames.filter((g) => {
    const text = `${g.title} ${(g.genres || []).join(' ')}`.toLowerCase();
    return (
      text.includes('souls') ||
      text.includes('soulslike') ||
      text.includes('elden ring') ||
      text.includes('bloodborne') ||
      text.includes('sekiro') ||
      text.includes('nioh') ||
      text.includes('lies of p') ||
      text.includes('hollow knight') ||
      text.includes('roguelike')
    );
  }).length;
  const soulsShare = soulsCount / totalOwned;

  const openWorldCount = ownedGames.filter((g) => {
    const text = `${g.title} ${(g.genres || []).join(' ')}`.toLowerCase();
    return (
      text.includes('open world') ||
      text.includes('öppen värld') ||
      text.includes('sandbox') ||
      text.includes('sandlåda') ||
      text.includes('witcher') ||
      text.includes('zelda') ||
      text.includes('skyrim') ||
      text.includes('red dead') ||
      text.includes('cyberpunk')
    );
  }).length;
  const openWorldShare = openWorldCount / totalOwned;

  const retroGamesCount = ownedGames.filter((g) => {
    const isOldYear = (g.release_year || 0) > 0 && (g.release_year || 0) <= 2012;
    const hasRetroPlat = (g.platforms || []).some((p) => {
      const lower = p.toLowerCase();
      return (
        lower.includes('retro') ||
        lower.includes('nes') ||
        lower.includes('snes') ||
        lower.includes('n64') ||
        lower.includes('ps1') ||
        lower.includes('ps2') ||
        lower.includes('game boy') ||
        lower.includes('sega')
      );
    });
    return isOldYear || hasRetroPlat;
  }).length;
  const retroShare = retroGamesCount / totalOwned;

  const multiplayerCount = ownedGames.filter((g) => {
    const text = `${g.title} ${(g.genres || []).join(' ')}`.toLowerCase();
    return (
      text.includes('multiplayer') ||
      text.includes('co-op') ||
      text.includes('samarbete') ||
      text.includes('warzone') ||
      text.includes('overwatch') ||
      text.includes('apex') ||
      text.includes('fifa') ||
      text.includes('fc 2') ||
      text.includes('counter-strike') ||
      text.includes('valorant') ||
      text.includes('helldivers') ||
      text.includes('destiny') ||
      text.includes('rocket league') ||
      text.includes('battlefield')
    );
  }).length;
  const multiplayerShare = multiplayerCount / totalOwned;

  const storyOrHorrorShare = (rpgCount + horrorCount) / totalOwned;
  const prefersCompetition = playFor.includes('Tävling') || playFor.includes('Action');
  const prefersCozy = playFor.includes('Avkoppling') || playFor.includes('Kreativitet');
  const prefersChallenge = playFor.includes('Utmaning') || playFor.includes('Adrenalin & Puls');
  const prefersLore = playFor.includes('Djup Lore & Världsbygge') || playFor.includes('Story');
  const prefersCoop = playFor.includes('Samarbete & Gemenskap (Co-op)') || playFor.includes('Samarbete');
  const prefersCompletionism = playFor.includes('100% Completionism (Trophies)');

  const isHorrorOrRPGTop =
    topGenreName.toLowerCase().includes('skräck') ||
    topGenreName.toLowerCase().includes('horror') ||
    topGenreName.toLowerCase().includes('rpg') ||
    topGenreName.toLowerCase().includes('rollspel');

  const isShooterTop =
    topGenreName.toLowerCase().includes('shooter') ||
    topGenreName.toLowerCase().includes('fps') ||
    topGenreName.toLowerCase().includes('skjutspel') ||
    topGenreName.toLowerCase().includes('krig');

  // 2. Regeluppslag mot Huvudarketyp
  let primaryProfile: SpelDNAProfile;

  // 1. Souls Survivor
  if (soulsCount >= 2 && (prefersChallenge || completionRate >= 0.4)) {
    primaryProfile = {
      archetypeID: 'souls_survivor',
      title: 'Souls Survivor',
      description:
        'Brutala bossar, millimeterprecision och hårt förvärvade triumfer — du backar aldrig för en verklig utmaning.',
      icon: '⚔️',
      accentHex: '#e11d48',
      supportingStats: [`${soulsCount} souls/utmaningar`, 'Oböjligt tålamod'],
    };
  }
  // 2. Story-driven Explorer
  else if (
    (isHorrorOrRPGTop && topGenreShare >= 0.45 && completionRate >= 0.45) ||
    (storyOrHorrorShare >= 0.5 && completionRate >= 0.5)
  ) {
    const stat1 =
      horrorCount >= rpgCount
        ? `${Math.min(99, Math.round(horrorShare * 100))}% Skräck`
        : `${Math.min(99, Math.round(rpgShare * 100))}% RPG`;
    const stat2 = `${completedCount}/${totalOwned} klarade`;
    primaryProfile = {
      archetypeID: 'story_driven_explorer',
      title: 'Story-driven Explorer',
      description:
        'Du väljer atmosfär och berättelse framför tempo — och du brukar faktiskt spela klart det du börjar.',
      icon: '🌒',
      accentHex: '#ff4b4b',
      supportingStats: [stat1, stat2],
    };
  }
  // 3. Completionist Prime
  else if (
    (completionRate >= 0.75 && totalOwned >= 7) ||
    (prefersCompletionism && completionRate >= 0.65)
  ) {
    primaryProfile = {
      archetypeID: 'completionist_prime',
      title: 'Completionist Prime',
      description:
        '100% är det enda acceptabla. Du lämnar ingen trofé, sidouppdrag eller hemlighet oavslutad.',
      icon: '🏅',
      accentHex: '#eab308',
      supportingStats: [`${Math.min(99, Math.round(completionRate * 100))}% genomfört`, 'Troféjägare'],
    };
  }
  // 4. Open-World Wanderer
  else if (
    openWorldShare >= 0.35 ||
    (openWorldCount >= 2 && (playFor.includes('Utforskning') || rpgShare >= 0.3))
  ) {
    primaryProfile = {
      archetypeID: 'open_world_wanderer',
      title: 'Öppen Värld-Nomad',
      description:
        'Vidsträckta vyer och total frihet — för dig är resan mot horisonten alltid viktigare än den raka vägen.',
      icon: '🧭',
      accentHex: '#0ea5e9',
      supportingStats: [`${openWorldCount} öppna världar`, 'Horisontsökare'],
    };
  }
  // 5. RPG Completionist
  else if (rpgShare >= 0.4 && completionRate >= 0.6) {
    const stat1 = `${Math.min(99, Math.round(rpgShare * 100))}% RPG`;
    const stat2 = `${completedCount}/${totalOwned} klarade`;
    primaryProfile = {
      archetypeID: 'rpg_completionist',
      title: 'RPG Completionist',
      description:
        'Sidouppdrag, loot och 100%-listor — om det finns en till timme att lägga i en värld tar du den.',
      icon: '🗺️',
      accentHex: '#6e7ae0',
      supportingStats: [stat1, stat2],
    };
  }
  // 6. Pixel Purist
  else if ((retroShare >= 0.3 && indieShare >= 0.2) || retroShare >= 0.4) {
    primaryProfile = {
      archetypeID: 'pixel_purist',
      title: 'Pixel Purist',
      description:
        'Tidlös estetik, pixelperfektion och ren spelglädje — kärleken till klassiker och retrokonst består.',
      icon: '👾',
      accentHex: '#06b6d4',
      supportingStats: [`${retroGamesCount} retro & pixel`, 'Tidlös estetik'],
    };
  }
  // 7. Atmosphere Hunter
  else if (horrorShare >= 0.3 || (prefersLore && horrorShare >= 0.2)) {
    primaryProfile = {
      archetypeID: 'atmosphere_hunter',
      title: 'Atmosfärsdykare',
      description:
        'Ljuddesign, tryckande stämning och mörka mysterier — du vill sugas in i världar som berör på djupet.',
      icon: '🕯️',
      accentHex: '#a21caf',
      supportingStats: [`${Math.min(99, Math.round(horrorShare * 100))}% Skräck & Mörker`, 'Djup atmosfär'],
    };
  }
  // 8. Indie Connoisseur
  else if (indieShare >= 0.35 || topGenreName.toLowerCase().includes('indie')) {
    const stat1 = `${Math.min(99, Math.max(35, Math.round(indieShare * 100)))}% Indie & Pussel`;
    const stat2 = 'Konstnärlig smak';
    primaryProfile = {
      archetypeID: 'indie_connoisseur',
      title: 'Indie Connoisseur',
      description:
        'Du söker unika visioner och originellt hantverk — de starkaste spelupplevelserna hittar du bortom storspelen.',
      icon: '🎨',
      accentHex: '#a855f7',
      supportingStats: [stat1, stat2],
    };
  }
  // 9. Hardcore Challenger
  else if (prefersChallenge && (completionRate >= 0.45 || topGenreShare >= 0.35)) {
    const stat1 = 'Hög utmaning';
    const stat2 = `${completedCount}/${totalOwned} klarade`;
    primaryProfile = {
      archetypeID: 'hardcore_challenger',
      title: 'Hardcore Challenger',
      description:
        'Du backar inte för brutala bossar eller tuffa moment — segern smakar bäst när den krävt svett och tålamod.',
      icon: '⚡',
      accentHex: '#dc2626',
      supportingStats: [stat1, stat2],
    };
  }
  // 10. Grand Strategist
  else if (
    strategyShare >= 0.3 ||
    topGenreName.toLowerCase().includes('strategi') ||
    topGenreName.toLowerCase().includes('strategy')
  ) {
    const stat1 = `${Math.min(99, Math.max(30, Math.round(strategyShare * 100)))}% Strategi`;
    const stat2 = 'Taktiskt sinne';
    primaryProfile = {
      archetypeID: 'grand_strategist',
      title: 'Grand Strategist',
      description:
        'Långsiktig planering, taktisk överblick och total kontroll — du vinner med hjärnan snarare än snabba reflexer.',
      icon: '👑',
      accentHex: '#f59e0b',
      supportingStats: [stat1, stat2],
    };
  }
  // 11. Retro Archivist
  else if (retroShare >= 0.3) {
    const stat1 = `${retroGamesCount} klassiker`;
    const stat2 = 'Retrosamlare';
    primaryProfile = {
      archetypeID: 'retro_archivist',
      title: 'Retro Archivist',
      description:
        'Spelhistoriens gyllene eror lever vidare i din samling — tidlösa mästerverk slår alltid tillfälliga trender.',
      icon: '🕹️',
      accentHex: '#f97316',
      supportingStats: [stat1, stat2],
    };
  }
  // 12. Tactical Operator
  else if (
    (isShooterTop && topGenreShare >= 0.35 && completionRate < 0.4) ||
    (shooterShare >= 0.35 && completionRate < 0.4)
  ) {
    const stat1 = `${Math.min(99, Math.max(35, Math.round(shooterShare * 100)))}% Shooters`;
    const stat2 = `${completedCount}/${totalOwned} klarade`;
    primaryProfile = {
      archetypeID: 'tactical_operator',
      title: 'Tactical Operator',
      description:
        'Du lägger timmarna där det finns en match att vinna, inte en historia att avsluta.',
      icon: '🎯',
      accentHex: '#c7c23a',
      supportingStats: [stat1, stat2],
    };
  }
  // 13. Zen Cultivator
  else if (prefersCozy && (cozyShare >= 0.3 || indieShare >= 0.25)) {
    primaryProfile = {
      archetypeID: 'zen_cultivator',
      title: 'Zen-odlare',
      description:
        'Spel som en varm tillflyktsort — rofyllt byggande, charm och avkopplande stunder utan stress.',
      icon: '🌱',
      accentHex: '#10b981',
      supportingStats: ['Zen & Harmoni', 'Lugnt tempo'],
    };
  }
  // 14. Cozy Adventurer
  else if (prefersCozy || (cozyShare >= 0.35 && completionRate >= 0.4)) {
    const stat1 = 'Cozy & Avkoppling';
    const stat2 = `${activeGenreCount} genrer aktiva`;
    primaryProfile = {
      archetypeID: 'cozy_adventurer',
      title: 'Cozy Adventurer',
      description:
        'Avkoppling, charm och atmosfär är ditt mantra — spel ska vara en varm tillflyktsort fri från stress och hets.',
      icon: '☕',
      accentHex: '#ec4899',
      supportingStats: [stat1, stat2],
    };
  }
  // 15. Squad Strategist
  else if (multiplayerShare >= 0.28 && (prefersCompetition || prefersCoop)) {
    const stat1 = `${Math.min(99, Math.round(multiplayerShare * 100))}% Multiplayer`;
    const stat2 = 'Lagspelare';
    primaryProfile = {
      archetypeID: 'squad_strategist',
      title: 'Squad Strategist',
      description:
        'Spelet är bäst när ni är fler — samarbete och tävling slår solo-berättelser varje gång.',
      icon: '🤝',
      accentHex: '#3cc8aa',
      supportingStats: [stat1, stat2],
    };
  }
  // 16. Backlog Titan
  else if (totalOwned >= 25 && completionRate < 0.3) {
    primaryProfile = {
      archetypeID: 'backlog_titan',
      title: 'Backlog Titan',
      description:
        'Ett storslaget bibliotek som växer ständigt — du samlar med passion och erövrar med tålamod.',
      icon: '📚',
      accentHex: '#d97706',
      supportingStats: [`${totalOwned} i hyllan`, 'Massiv backlog'],
    };
  }
  // 17. Casual Collector
  else if (topGenreShare <= 0.38 && (wishlistGames.length >= 8 || totalOwned >= 10)) {
    const stat1 = `${wishlistGames.length} på önskelistan`;
    const stat2 = `${activeGenreCount} genrer aktiva`;
    primaryProfile = {
      archetypeID: 'casual_collector',
      title: 'Casual Collector',
      description:
        'Du samlar bredare än du hinner spela — biblioteket är lika mycket en önskelista som en att-göra-lista.',
      icon: '📦',
      accentHex: '#e6a03c',
      supportingStats: [stat1, stat2],
    };
  }
  // 18. Fallback: Genre-nomad
  else {
    const stat1 = `${activeGenreCount} genrer i hyllan`;
    const stat2 = `${totalOwned} ägda spel`;
    primaryProfile = {
      archetypeID: 'genre_nomad',
      title: 'Genre-nomad',
      description:
        'Du rör dig fritt mellan världar och genrer utan att fastna i ett fack — nyfikenheten styr nästa val.',
      icon: '🎲',
      accentHex: '#8b8b8f',
      supportingStats: [stat1, stat2],
    };
  }

  // 3. Beräkna 4 dynamiska DNA-rutor
  const tiles: SpelDNATile[] = [];

  // RUTA 1: Sekundärt DNA (Hybrid-drag)
  let tile1: SpelDNATile;
  if (primaryProfile.archetypeID !== 'indie_connoisseur' && indieShare >= 0.22) {
    tile1 = {
      id: 'tile_hybrid',
      category: 'SEKUNDÄRT DRAG',
      title: 'Indie Gourmet',
      subtitle: 'Konstnärlig ådra',
      icon: '🎨',
      accentHex: '#a855f7',
      detail: `${Math.round(indieShare * 100)}% av hyllan utgörs av unika indiepärlor`,
    };
  } else if (primaryProfile.archetypeID !== 'rpg_completionist' && rpgShare >= 0.22) {
    tile1 = {
      id: 'tile_hybrid',
      category: 'SEKUNDÄRT DRAG',
      title: 'Rollspelsdykare',
      subtitle: 'Djupa världar',
      icon: '🗺️',
      accentHex: '#6e7ae0',
      detail: 'Stark dragning till karaktärsutveckling och rik lore',
    };
  } else if (
    primaryProfile.archetypeID !== 'retro_archivist' &&
    primaryProfile.archetypeID !== 'pixel_purist' &&
    retroShare >= 0.18
  ) {
    tile1 = {
      id: 'tile_hybrid',
      category: 'SEKUNDÄRT DRAG',
      title: 'Retro-nostalgiker',
      subtitle: 'Tidlösa klassiker',
      icon: '🕹️',
      accentHex: '#f97316',
      detail: `${retroGamesCount} äldre klassiker bevaras i ditt bibliotek`,
    };
  } else if (primaryProfile.archetypeID !== 'squad_strategist' && multiplayerShare >= 0.18) {
    tile1 = {
      id: 'tile_hybrid',
      category: 'SEKUNDÄRT DRAG',
      title: 'Co-op Kamrat',
      subtitle: 'Gemensam glädje',
      icon: '🤝',
      accentHex: '#3cc8aa',
      detail: 'Spelar gärna sida vid sida med vänner',
    };
  } else if (
    primaryProfile.archetypeID !== 'hardcore_challenger' &&
    primaryProfile.archetypeID !== 'souls_survivor' &&
    prefersChallenge
  ) {
    tile1 = {
      id: 'tile_hybrid',
      category: 'SEKUNDÄRT DRAG',
      title: 'Utmaningssökare',
      subtitle: 'Gillar motstånd',
      icon: '⚡',
      accentHex: '#dc2626',
      detail: 'Trivs när spelet kräver fokus och skärpa',
    };
  } else if (
    primaryProfile.archetypeID !== 'cozy_adventurer' &&
    primaryProfile.archetypeID !== 'zen_cultivator' &&
    prefersCozy
  ) {
    tile1 = {
      id: 'tile_hybrid',
      category: 'SEKUNDÄRT DRAG',
      title: 'Avkopplingsnjutare',
      subtitle: 'Stressfri zon',
      icon: '☕',
      accentHex: '#ec4899',
      detail: 'Värdesätter harmoniska och varma spelstunder',
    };
  } else {
    tile1 = {
      id: 'tile_hybrid',
      category: 'SEKUNDÄRT DRAG',
      title: 'Berättelsedykare',
      subtitle: 'Story & Världsbygge',
      icon: '📖',
      accentHex: '#38bdf8',
      detail: 'Drags till fängslande manus och atmosfär',
    };
  }
  tiles.push(tile1);

  // RUTA 2: Tempo & Pacing
  const estimatedList = ownedGames
    .map((g) => g.estimated_hours)
    .filter((h): h is number => typeof h === 'number' && h > 0);
  const avgHours =
    estimatedList.length > 0
      ? estimatedList.reduce((acc, v) => acc + v, 0) / estimatedList.length
      : 0;
  let tile2: SpelDNATile;
  if (avgHours >= 30 || (rpgShare >= 0.35 && avgHours >= 20)) {
    tile2 = {
      id: 'tile_pacing',
      category: 'TEMPO & PACING',
      title: 'Episk Maratonspelare',
      subtitle: '30h+ per äventyr',
      icon: '⏳',
      accentHex: '#f59e0b',
      detail: 'Investerar helhjärtat i djupa, expansiva världar',
    };
  } else if (avgHours > 0 && avgHours <= 14) {
    tile2 = {
      id: 'tile_pacing',
      category: 'TEMPO & PACING',
      title: 'Bite-sized Gourmet',
      subtitle: 'Fokuserade pärlor',
      icon: '⚡',
      accentHex: '#06b6d4',
      detail: 'Föredrar intensiva upplevelser som respekterar din tid',
    };
  } else {
    tile2 = {
      id: 'tile_pacing',
      category: 'TEMPO & PACING',
      title: 'Balanserad Äventyrare',
      subtitle: 'Flexibelt tempo',
      icon: '⏱️',
      accentHex: '#10b981',
      detail: 'Växlar ledigt mellan snabba sessionsspel och längre kampanjer',
    };
  }
  tiles.push(tile2);

  // RUTA 3: Fullbordare
  let tile3: SpelDNATile;
  if (completionRate >= 0.58) {
    tile3 = {
      id: 'tile_completion',
      category: 'FULLBORDARE',
      title: '100% Fullbordare',
      subtitle: `${Math.round(completionRate * 100)}% genomfört`,
      icon: '🏆',
      accentHex: '#eab308',
      detail: `${completedCount} av ${totalOwned} spel har spelats hela vägen in i mål`,
    };
  } else if (
    wishlistGames.length >= ownedGames.length ||
    (totalOwned >= 18 && completionRate < 0.25)
  ) {
    tile3 = {
      id: 'tile_completion',
      category: 'FULLBORDARE',
      title: 'Backlog-Erövrare',
      subtitle: `${totalOwned} spel i hyllan`,
      icon: '🏔️',
      accentHex: '#f97316',
      detail: 'Bygger ett skafferi av äventyr och tar sig an spelen med tiden',
    };
  } else if (completionRate < 0.35) {
    tile3 = {
      id: 'tile_completion',
      category: 'FULLBORDARE',
      title: 'Nyfiken Upptäckare',
      subtitle: 'Utforskar brett',
      icon: '🔍',
      accentHex: '#8b5cf6',
      detail: 'Testar gärna nya mekaniker utan krav på att se eftertexterna',
    };
  } else {
    tile3 = {
      id: 'tile_completion',
      category: 'FULLBORDARE',
      title: 'Målmedveten Spelare',
      subtitle: 'Jämn framfart',
      icon: '🎯',
      accentHex: '#3b82f6',
      detail: 'God balans mellan att utforska nytt och avsluta påbörjat',
    };
  }
  tiles.push(tile3);

  // RUTA 4: Smakspektrum
  let tile4: SpelDNATile;
  if (topGenreShare >= 0.48) {
    tile4 = {
      id: 'tile_spectrum',
      category: 'SMAKSPEKTRUM',
      title: 'Genrefokuserad Specialist',
      subtitle: 'Tydlig profil',
      icon: '🎯',
      accentHex: '#ef4444',
      detail: `${topGenreName} utgör ${Math.round(topGenreShare * 100)}% av hela din samling`,
    };
  } else if (activeGenreCount >= 5 && topGenreShare <= 0.35) {
    tile4 = {
      id: 'tile_spectrum',
      category: 'SMAKSPEKTRUM',
      title: 'Eklektisk Allätare',
      subtitle: `${activeGenreCount} aktiva genrer`,
      icon: '🌈',
      accentHex: '#ec4899',
      detail: 'Rör dig obehindrat mellan helt olika spelstilar och koncept',
    };
  } else if (retroShare >= 0.25) {
    tile4 = {
      id: 'tile_spectrum',
      category: 'SMAKSPEKTRUM',
      title: 'Klassiker-kännare',
      subtitle: `${retroGamesCount} retrotitlar`,
      icon: '🕹️',
      accentHex: '#f59e0b',
      detail: 'En fin känsla för spelhistoriens mest inflytelserika epoker',
    };
  } else {
    tile4 = {
      id: 'tile_spectrum',
      category: 'SMAKSPEKTRUM',
      title: 'Modern Allroundare',
      subtitle: 'Tidsenlig smak',
      icon: '✨',
      accentHex: '#6366f1',
      detail: 'Öppen för både nutida storspel och nyskapande format',
    };
  }
  tiles.push(tile4);

  primaryProfile.tiles = tiles;
  return primaryProfile;
}
