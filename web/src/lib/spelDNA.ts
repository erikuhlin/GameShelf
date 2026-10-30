// Spel-DNA Rule Engine for Gameshelf Web
import { Game } from '@/types/game';
import { SpelDNAProfile, SpelDNATile, SpelDNASubArchetype, SpelDNAArchetypeID } from '@/types/profile';

interface ArchetypeCandidate {
  archetypeID: SpelDNAArchetypeID;
  title: string;
  description: string;
  icon: string;
  accentHex: string;
  supportingStats: string[];
  score: number;
}

export function calculateSpelDNA(
  games: Game[],
  playFor: string[] = [],
  favoriteGenres: string[] = [],
  favoriteGameIDs: string[] = [],
  playstyle: string[] = []
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

  const favSet = new Set(favoriteGameIDs.map((id) => id.toLowerCase()));

  // 1. Viktat genomslag per spel
  // Masterpieces (9-10) och favoritmarkerade spel väger 2.5x
  // Högt rankade (8) väger 1.8x
  // Avklarade spel väger 1.4x
  // Övriga väger 1.0x
  let totalEffectiveWeight = 0;
  const gameWeights = new Map<string, number>();

  for (const game of ownedGames) {
    let w = 1.0;
    const isFav = favSet.has(game.id.toLowerCase()) || (game.igdb_id && favSet.has(String(game.igdb_id)));
    if (game.rating && game.rating >= 9) {
      w += 1.5;
    } else if (game.rating && game.rating === 8) {
      w += 0.8;
    }
    if (isFav) {
      w += 1.2;
    }
    if (game.status === 'completed') {
      w += 0.4;
    }
    gameWeights.set(game.id, w);
    totalEffectiveWeight += w;
  }

  if (totalEffectiveWeight <= 0) totalEffectiveWeight = totalOwned;

  // 2. Räkna viktad genrefördelning
  const genreWeights: Record<string, number> = {};
  for (const game of ownedGames) {
    const w = gameWeights.get(game.id) || 1.0;
    for (const genre of game.genres || []) {
      const trimmed = genre.trim();
      if (!trimmed) continue;
      genreWeights[trimmed] = (genreWeights[trimmed] || 0) + w;
    }
  }

  const sortedGenres = Object.entries(genreWeights).sort((a, b) => b[1] - a[1]);
  const topGenreName = sortedGenres[0]?.[0] || 'Okänd';
  const topGenreWeight = sortedGenres[0]?.[1] || 0;
  const topGenreShare = topGenreWeight / totalEffectiveWeight;
  const activeGenreCount = Object.keys(genreWeights).length;

  const weightForKeywords = (keywords: string[]) => {
    let sum = 0;
    for (const [name, w] of Object.entries(genreWeights)) {
      const lower = name.toLowerCase();
      if (keywords.some((kw) => lower.includes(kw))) {
        sum += w;
      }
    }
    return sum;
  };

  const rpgWeight = weightForKeywords(['rpg', 'rollspel', 'role-playing', 'jrpg']);
  const rpgShare = rpgWeight / totalEffectiveWeight;

  const horrorWeight = weightForKeywords(['skräck', 'horror', 'survival horror']);
  const horrorShare = horrorWeight / totalEffectiveWeight;

  const shooterWeight = weightForKeywords(['shooter', 'fps', 'skjutspel', 'krig', 'tactical']);
  const shooterShare = shooterWeight / totalEffectiveWeight;

  const indieWeight = weightForKeywords(['indie', 'puzzle', 'pussel']);
  const indieShare = indieWeight / totalEffectiveWeight;

  const strategyWeight = weightForKeywords(['strategi', 'strategy', 'taktik', 'tactical']);
  const strategyShare = strategyWeight / totalEffectiveWeight;

  const cozyWeight = weightForKeywords(['simulator', 'pussel', 'puzzle', 'äventyr', 'adventure', 'cozy', 'life sim']);
  const cozyShare = cozyWeight / totalEffectiveWeight;

  let soulsWeight = 0;
  let soulsCount = 0;
  ownedGames.forEach((g) => {
    const text = `${g.title} ${(g.genres || []).join(' ')}`.toLowerCase();
    const isSouls =
      text.includes('souls') ||
      text.includes('soulslike') ||
      text.includes('elden ring') ||
      text.includes('bloodborne') ||
      text.includes('sekiro') ||
      text.includes('nioh') ||
      text.includes('lies of p') ||
      text.includes('hollow knight') ||
      text.includes('roguelike');
    if (isSouls) {
      soulsCount++;
      soulsWeight += gameWeights.get(g.id) || 1.0;
    }
  });
  const soulsShare = soulsWeight / totalEffectiveWeight;

  let openWorldWeight = 0;
  let openWorldCount = 0;
  ownedGames.forEach((g) => {
    const text = `${g.title} ${(g.genres || []).join(' ')}`.toLowerCase();
    const isOW =
      text.includes('open world') ||
      text.includes('öppen värld') ||
      text.includes('sandbox') ||
      text.includes('sandlåda') ||
      text.includes('witcher') ||
      text.includes('zelda') ||
      text.includes('skyrim') ||
      text.includes('red dead') ||
      text.includes('cyberpunk');
    if (isOW) {
      openWorldCount++;
      openWorldWeight += gameWeights.get(g.id) || 1.0;
    }
  });
  const openWorldShare = openWorldWeight / totalEffectiveWeight;

  let retroWeight = 0;
  let retroGamesCount = 0;
  ownedGames.forEach((g) => {
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
    if (isOldYear || hasRetroPlat) {
      retroGamesCount++;
      retroWeight += gameWeights.get(g.id) || 1.0;
    }
  });
  const retroShare = retroWeight / totalEffectiveWeight;

  let multiplayerWeight = 0;
  let multiplayerCount = 0;
  ownedGames.forEach((g) => {
    const text = `${g.title} ${(g.genres || []).join(' ')}`.toLowerCase();
    const isMP =
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
      text.includes('battlefield');
    if (isMP) {
      multiplayerCount++;
      multiplayerWeight += gameWeights.get(g.id) || 1.0;
    }
  });
  const multiplayerShare = multiplayerWeight / totalEffectiveWeight;

  // Profilpreferenser
  const prefersCompetition = playFor.includes('Tävling') || playFor.includes('Action') || playstyle.includes('PvP / Multiplayer');
  const prefersCozy =
    playFor.includes('Avkoppling') ||
    playFor.includes('Avkoppling & Lugn') ||
    playFor.includes('Kreativitet') ||
    playFor.includes('Kreativitet & Byggande') ||
    playstyle.includes('Casual & Cozy');
  const prefersChallenge =
    playFor.includes('Utmaning') ||
    playFor.includes('Utmaning & Bemästring') ||
    playFor.includes('Adrenalin & Puls') ||
    playFor.includes('Mästra svåra bossar') ||
    playstyle.includes('Hardcore / Utmanare');
  const prefersLore =
    playFor.includes('Djup Lore & Världsbygge') ||
    playFor.includes('Story') ||
    playFor.includes('Story & Karaktärer') ||
    playFor.includes('Immersion & Stämning') ||
    playstyle.includes('Story-fokuserad');
  const prefersCoop =
    playFor.includes('Samarbete & Gemenskap (Co-op)') ||
    playFor.includes('Samarbete') ||
    playFor.includes('Samarbete & Gemenskap') ||
    playstyle.includes('Co-op / Samarbete');
  const prefersCompletionism =
    playFor.includes('100% Completionism (Trophies)') ||
    playFor.includes('100% Completionism') ||
    playFor.includes('Trophy Hunter') ||
    playFor.includes('Completionist (100%)') ||
    playstyle.includes('Completionist (100%)') ||
    playstyle.includes('Trophy / Achievement Hunter');
  const prefersExploration =
    playFor.includes('Utforskning') ||
    playstyle.includes('Utforskare & Samlare');

  // Genre-preferenser från profil
  const favGenresLower = favoriteGenres.map((g) => g.toLowerCase());
  const hasFavGenre = (kw: string) => favGenresLower.some((g) => g.includes(kw));

  // 3. Poängsättning för alla arketyper
  const candidates: ArchetypeCandidate[] = [
    // 1. Souls Survivor
    {
      archetypeID: 'souls_survivor',
      title: 'Souls Survivor',
      description:
        'Brutala bossar, millimeterprecision och hårt förvärvade triumfer — du backar aldrig för en verklig utmaning.',
      icon: '⚔️',
      accentHex: '#e11d48',
      supportingStats: [`${soulsCount} souls/utmaningar`, 'Oböjligt tålamod'],
      score:
        (soulsShare * 110) +
        (soulsCount >= 2 ? 25 : 0) +
        (prefersChallenge ? 20 : 0) +
        (hasFavGenre('soulslike') ? 25 : 0),
    },

    // 2. Story-driven Explorer
    {
      archetypeID: 'story_driven_explorer',
      title: 'Story-driven Explorer',
      description:
        'Du väljer atmosfär och berättelse framför tempo — och du brukar faktiskt spela klart det du börjar.',
      icon: '🌒',
      accentHex: '#ff4b4b',
      supportingStats: [
        horrorWeight >= rpgWeight
          ? `${Math.min(99, Math.round(horrorShare * 100))}% Skräck`
          : `${Math.min(99, Math.round(rpgShare * 100))}% RPG`,
        `${completedCount}/${totalOwned} klarade`,
      ],
      score:
        ((rpgShare + horrorShare) * 65) +
        (prefersLore ? 25 : 0) +
        (completionRate >= 0.35 ? 15 : 0) +
        (hasFavGenre('berättelsedrivet') ? 20 : 0),
    },

    // 3. RPG Completionist
    {
      archetypeID: 'rpg_completionist',
      title: 'RPG Completionist',
      description:
        'Sidouppdrag, loot och 100%-listor — om det finns en till timme att lägga i en värld tar du den.',
      icon: '🗺️',
      accentHex: '#6e7ae0',
      supportingStats: [`${Math.min(99, Math.round(rpgShare * 100))}% RPG`, `${completedCount}/${totalOwned} klarade`],
      score:
        (rpgShare * 85) +
        (completionRate * 25) +
        (hasFavGenre('rpg') || hasFavGenre('jrpg') ? 20 : 0),
    },

    // 4. Open-World Wanderer
    {
      archetypeID: 'open_world_wanderer',
      title: 'Öppen Värld-Nomad',
      description:
        'Vidsträckta vyer och total frihet — för dig är resan mot horisonten alltid viktigare än den raka vägen.',
      icon: '🧭',
      accentHex: '#0ea5e9',
      supportingStats: [`${openWorldCount} öppna världar`, 'Horisontsökare'],
      score:
        (openWorldShare * 95) +
        (openWorldCount >= 2 ? 15 : 0) +
        (prefersExploration ? 25 : 0) +
        (hasFavGenre('öppen värld') ? 20 : 0),
    },

    // 5. Indie Connoisseur
    {
      archetypeID: 'indie_connoisseur',
      title: 'Indie Connoisseur',
      description:
        'Du söker unika visioner och originellt hantverk — de starkaste spelupplevelserna hittar du bortom storspelen.',
      icon: '🎨',
      accentHex: '#a855f7',
      supportingStats: [`${Math.min(99, Math.max(30, Math.round(indieShare * 100)))}% Indie & Pussel`, 'Konstnärlig smak'],
      score:
        (indieShare * 100) +
        (topGenreName.toLowerCase().includes('indie') ? 20 : 0) +
        (hasFavGenre('indie') ? 25 : 0),
    },

    // 6. Hardcore Challenger
    {
      archetypeID: 'hardcore_challenger',
      title: 'Hardcore Challenger',
      description:
        'Du backar inte för brutala bossar eller tuffa moment — segern smakar bäst när den krävt svett och tålamod.',
      icon: '⚡',
      accentHex: '#dc2626',
      supportingStats: ['Hög utmaning', `${completedCount}/${totalOwned} klarade`],
      score:
        (prefersChallenge ? 35 : 0) +
        (completionRate * 30) +
        (soulsShare * 30),
    },

    // 7. Atmosphere Hunter
    {
      archetypeID: 'atmosphere_hunter',
      title: 'Atmosfärsdykare',
      description:
        'Ljuddesign, tryckande stämning och mörka mysterier — du vill sugas in i världar som berör på djupet.',
      icon: '🕯️',
      accentHex: '#a21caf',
      supportingStats: [`${Math.min(99, Math.round(horrorShare * 100))}% Skräck & Mörker`, 'Djup atmosfär'],
      score:
        (horrorShare * 110) +
        (prefersLore ? 20 : 0) +
        (hasFavGenre('skräck') ? 25 : 0),
    },

    // 8. Pixel Purist
    {
      archetypeID: 'pixel_purist',
      title: 'Pixel Purist',
      description:
        'Tidlös estetik, pixelperfektion och ren spelglädje — kärleken till klassiker och retrokonst består.',
      icon: '👾',
      accentHex: '#06b6d4',
      supportingStats: [`${retroGamesCount} retro & pixel`, 'Tidlös estetik'],
      score:
        (retroShare * 65) +
        (indieShare * 35) +
        (retroGamesCount >= 3 ? 15 : 0),
    },

    // 9. Grand Strategist
    {
      archetypeID: 'grand_strategist',
      title: 'Grand Strategist',
      description:
        'Långsiktig planering, taktisk överblick och total kontroll — du vinner med hjärnan snarare än snabba reflexer.',
      icon: '👑',
      accentHex: '#f59e0b',
      supportingStats: [`${Math.min(99, Math.max(30, Math.round(strategyShare * 100)))}% Strategi`, 'Taktiskt sinne'],
      score:
        (strategyShare * 110) +
        (hasFavGenre('strategi') ? 25 : 0),
    },

    // 10. Retro Archivist
    {
      archetypeID: 'retro_archivist',
      title: 'Retro Archivist',
      description:
        'Spelhistoriens gyllene eror lever vidare i din samling — tidlösa mästerverk slår alltid tillfälliga trender.',
      icon: '🕹️',
      accentHex: '#f97316',
      supportingStats: [`${retroGamesCount} klassiker`, 'Retrosamlare'],
      score:
        (retroShare * 105) +
        (hasFavGenre('retro') ? 25 : 0),
    },

    // 11. Zen Cultivator
    {
      archetypeID: 'zen_cultivator',
      title: 'Zen-odlare',
      description:
        'Spel som en varm tillflyktsort — rofyllt byggande, charm och avkopplande stunder utan stress.',
      icon: '🌱',
      accentHex: '#10b981',
      supportingStats: ['Zen & Harmoni', 'Lugnt tempo'],
      score:
        (cozyShare * 80) +
        (prefersCozy ? 30 : 0) +
        (hasFavGenre('cozy') ? 20 : 0),
    },

    // 12. Cozy Adventurer
    {
      archetypeID: 'cozy_adventurer',
      title: 'Cozy Adventurer',
      description:
        'Avkoppling, charm och atmosfär är ditt mantra — spel ska vara en varm tillflyktsort fri från stress och hets.',
      icon: '☕',
      accentHex: '#ec4899',
      supportingStats: ['Cozy & Avkoppling', `${activeGenreCount} genrer aktiva`],
      score:
        (cozyShare * 75) +
        (prefersCozy ? 25 : 0) +
        (completionRate >= 0.35 ? 15 : 0),
    },

    // 13. Tactical Operator
    {
      archetypeID: 'tactical_operator',
      title: 'Tactical Operator',
      description:
        'Du lägger timmarna där det finns en match att vinna, inte en historia att avsluta.',
      icon: '🎯',
      accentHex: '#c7c23a',
      supportingStats: [`${Math.min(99, Math.max(30, Math.round(shooterShare * 100)))}% Shooters`, 'Taktiskt fokus'],
      score:
        (shooterShare * 100) +
        (prefersCompetition ? 20 : 0) +
        (hasFavGenre('fps') ? 25 : 0),
    },

    // 14. Squad Strategist
    {
      archetypeID: 'squad_strategist',
      title: 'Squad Strategist',
      description:
        'Spelet är bäst när ni är fler — samarbete och tävling slår solo-berättelser varje gång.',
      icon: '🤝',
      accentHex: '#3cc8aa',
      supportingStats: [`${Math.min(99, Math.round(multiplayerShare * 100))}% Multiplayer`, 'Lagspelare'],
      score:
        (multiplayerShare * 100) +
        (prefersCoop ? 30 : 0) +
        (prefersCompetition ? 15 : 0),
    },

    // 15. Completionist Prime
    {
      archetypeID: 'completionist_prime',
      title: 'Completionist Prime',
      description:
        '100% är det enda acceptabla. Du lämnar ingen trofé, sidouppdrag eller hemlighet oavslutad.',
      icon: '🏅',
      accentHex: '#eab308',
      supportingStats: [`${Math.min(99, Math.round(completionRate * 100))}% genomfört`, 'Troféjägare'],
      score:
        (completionRate >= 0.65 ? 50 : 0) +
        (prefersCompletionism ? 40 : 0),
    },

    // 16. Backlog Titan
    {
      archetypeID: 'backlog_titan',
      title: 'Backlog Titan',
      description:
        'Ett storslaget bibliotek som växer ständigt — du samlar med passion och erövrar med tålamod.',
      icon: '📚',
      accentHex: '#d97706',
      supportingStats: [`${totalOwned} i biblioteket`, 'Massiv backlog'],
      score:
        totalOwned >= 25 && completionRate < 0.20 && topGenreShare < 0.30
          ? 40
          : 5,
    },

    // 17. Casual Collector
    {
      archetypeID: 'casual_collector',
      title: 'Casual Collector',
      description:
        'Du samlar bredare än du hinner spela — biblioteket är lika mycket en önskelista som en att-göra-lista.',
      icon: '📦',
      accentHex: '#e6a03c',
      supportingStats: [`${wishlistGames.length} på önskelistan`, `${activeGenreCount} genrer aktiva`],
      score:
        wishlistGames.length >= 12 && completionRate < 0.25 && topGenreShare < 0.25
          ? 35
          : 5,
    },

    // 18. Fallback: Genre-nomad
    {
      archetypeID: 'genre_nomad',
      title: 'Genre-nomad',
      description:
        'Du rör dig fritt mellan världar och genrer utan att fastna i ett fack — nyfikenheten styr nästa val.',
      icon: '🎲',
      accentHex: '#8b8b8f',
      supportingStats: [`${activeGenreCount} genrer i samlingen`, `${totalOwned} ägda spel`],
      score: activeGenreCount >= 5 && topGenreShare <= 0.25 ? 45 : 15,
    },
  ];

  // Sortera efter högst poäng
  candidates.sort((a, b) => b.score - a.score);

  const best = candidates[0];
  const primaryScore = Math.max(1, best.score);

  const primaryProfile: SpelDNAProfile = {
    archetypeID: best.archetypeID,
    title: best.title,
    description: best.description,
    icon: best.icon,
    accentHex: best.accentHex,
    supportingStats: best.supportingStats,
  };

  // Sekundära arketyper (topp 2 runner-ups som har minst 35 i score och är relevanta)
  const secondaryArchetypes: SpelDNASubArchetype[] = candidates
    .slice(1)
    .filter((c) => c.score >= 35 && c.archetypeID !== best.archetypeID)
    .slice(0, 2)
    .map((c) => ({
      archetypeID: c.archetypeID,
      title: c.title,
      icon: c.icon,
      accentHex: c.accentHex,
      matchPercentage: Math.min(95, Math.round((c.score / primaryScore) * 100)),
    }));

  primaryProfile.secondaryArchetypes = secondaryArchetypes;

  // 4. Beräkna de 4 dynamiska DNA-rutorna
  const tiles: SpelDNATile[] = [];

  // RUTA 1: Sekundärt DNA (Hybrid-drag)
  let tile1: SpelDNATile;
  if (secondaryArchetypes.length > 0) {
    const sec = secondaryArchetypes[0];
    tile1 = {
      id: 'tile_hybrid',
      category: 'SEKUNDÄRT DRAG',
      title: sec.title,
      subtitle: `${sec.matchPercentage}% matchning`,
      icon: sec.icon,
      accentHex: sec.accentHex,
      detail: `Starkt komplementärt drag i din spelstil (${sec.matchPercentage}% match)`,
    };
  } else if (primaryProfile.archetypeID !== 'indie_connoisseur' && indieShare >= 0.20) {
    tile1 = {
      id: 'tile_hybrid',
      category: 'SEKUNDÄRT DRAG',
      title: 'Indie Gourmet',
      subtitle: 'Konstnärlig ådra',
      icon: '🎨',
      accentHex: '#a855f7',
      detail: `${Math.round(indieShare * 100)}% av hyllan utgörs av unika indiepärlor`,
    };
  } else if (primaryProfile.archetypeID !== 'rpg_completionist' && rpgShare >= 0.20) {
    tile1 = {
      id: 'tile_hybrid',
      category: 'SEKUNDÄRT DRAG',
      title: 'Rollspelsdykare',
      subtitle: 'Djupa världar',
      icon: '🗺️',
      accentHex: '#6e7ae0',
      detail: 'Stark dragning till karaktärsutveckling och rik lore',
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
  if (completionRate >= 0.55) {
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
  if (topGenreShare >= 0.45) {
    tile4 = {
      id: 'tile_spectrum',
      category: 'SMAKSPEKTRUM',
      title: 'Genrefokuserad Specialist',
      subtitle: 'Tydlig profil',
      icon: '🎯',
      accentHex: '#ef4444',
      detail: `${topGenreName} utgör en stark kärna i din personliga samling`,
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
  } else if (retroShare >= 0.20) {
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
