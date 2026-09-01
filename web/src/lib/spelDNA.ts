// Spel-DNA Rule Engine for Gameshelf Web
import { Game } from '@/types/game';
import { SpelDNAProfile } from '@/types/profile';

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

  const rpgCount = countForKeywords(['rpg', 'rollspel', 'role-playing']);
  const rpgShare = rpgCount / totalOwned;

  const horrorCount = countForKeywords(['skräck', 'horror', 'survival horror']);
  const horrorShare = horrorCount / totalOwned;

  const shooterCount = countForKeywords(['shooter', 'fps', 'skjutspel', 'krig', 'tactical']);
  const shooterShare = shooterCount / totalOwned;

  const indieCount = countForKeywords(['indie', 'puzzle', 'pussel']);
  const indieShare = indieCount / totalOwned;

  const strategyCount = countForKeywords(['strategi', 'strategy', 'taktik', 'tactical']);
  const strategyShare = strategyCount / totalOwned;

  const cozyCount = countForKeywords(['simulator', 'pussel', 'puzzle', 'äventyr', 'adventure']);
  const cozyShare = cozyCount / totalOwned;

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
  const prefersChallenge = playFor.includes('Utmaning');

  // 2. Regeluppslag mot arketyp-tabell (10 arketyper + fallback)

  // 1. Story-driven Explorer
  const isHorrorOrRPGTop =
    topGenreName.toLowerCase().includes('skräck') ||
    topGenreName.toLowerCase().includes('horror') ||
    topGenreName.toLowerCase().includes('rpg') ||
    topGenreName.toLowerCase().includes('rollspel');

  if (
    (isHorrorOrRPGTop && topGenreShare >= 0.45 && completionRate >= 0.45) ||
    (storyOrHorrorShare >= 0.5 && completionRate >= 0.5)
  ) {
    const stat1 =
      horrorCount >= rpgCount
        ? `${Math.min(99, Math.round(horrorShare * 100))}% Skräck`
        : `${Math.min(99, Math.round(rpgShare * 100))}% RPG`;
    const stat2 = `${completedCount}/${totalOwned} klarade`;
    return {
      archetypeID: 'story_driven_explorer',
      title: 'Story-driven Explorer',
      description:
        'Du väljer atmosfär och berättelse framför tempo — och du brukar faktiskt spela klart det du börjar.',
      icon: '🌒',
      accentHex: '#ff4b4b',
      supportingStats: [stat1, stat2],
    };
  }

  // 2. RPG Completionist
  if (rpgShare >= 0.4 && completionRate >= 0.65) {
    const stat1 = `${Math.min(99, Math.round(rpgShare * 100))}% RPG`;
    const stat2 = `${completedCount}/${totalOwned} klarade`;
    return {
      archetypeID: 'rpg_completionist',
      title: 'RPG Completionist',
      description:
        'Sidouppdrag, loot och 100%-listor — om det finns en till timme att lägga i en värld tar du den.',
      icon: '🗺️',
      accentHex: '#6e7ae0',
      supportingStats: [stat1, stat2],
    };
  }

  // 3. Indie Connoisseur
  if (indieShare >= 0.35 || topGenreName.toLowerCase().includes('indie')) {
    const stat1 = `${Math.min(99, Math.max(35, Math.round(indieShare * 100)))}% Indie & Pussel`;
    const stat2 = 'Konstnärlig smak';
    return {
      archetypeID: 'indie_connoisseur',
      title: 'Indie Connoisseur',
      description:
        'Du söker unika visioner och originellt hantverk — de starkaste spelupplevelserna hittar du bortom storspelen.',
      icon: '🎨',
      accentHex: '#a855f7',
      supportingStats: [stat1, stat2],
    };
  }

  // 4. Hardcore Challenger
  if (prefersChallenge && (completionRate >= 0.5 || topGenreShare >= 0.35)) {
    const stat1 = 'Hög utmaning';
    const stat2 = `${completedCount}/${totalOwned} klarade`;
    return {
      archetypeID: 'hardcore_challenger',
      title: 'Hardcore Challenger',
      description:
        'Du backar inte för brutala bossar eller tuffa moment — segern smakar bäst när den krävt svett och tålamod.',
      icon: '⚡',
      accentHex: '#dc2626',
      supportingStats: [stat1, stat2],
    };
  }

  // 5. Grand Strategist
  if (
    strategyShare >= 0.3 ||
    topGenreName.toLowerCase().includes('strategi') ||
    topGenreName.toLowerCase().includes('strategy')
  ) {
    const stat1 = `${Math.min(99, Math.max(30, Math.round(strategyShare * 100)))}% Strategi`;
    const stat2 = 'Taktiskt sinne';
    return {
      archetypeID: 'grand_strategist',
      title: 'Grand Strategist',
      description:
        'Långsiktig planering, taktisk överblick och total kontroll — du vinner med hjärnan snarare än snabba reflexer.',
      icon: '👑',
      accentHex: '#f59e0b',
      supportingStats: [stat1, stat2],
    };
  }

  // 6. Retro Archivist
  if (retroShare >= 0.3) {
    const stat1 = `${retroGamesCount} klassiker`;
    const stat2 = 'Retrosamlare';
    return {
      archetypeID: 'retro_archivist',
      title: 'Retro Archivist',
      description:
        'Spelhistoriens gyllene eror lever vidare i din samling — tidlösa mästerverk slår alltid tillfälliga trender.',
      icon: '🕹️',
      accentHex: '#f97316',
      supportingStats: [stat1, stat2],
    };
  }

  // 7. Tactical Operator
  const isShooterTop =
    topGenreName.toLowerCase().includes('shooter') ||
    topGenreName.toLowerCase().includes('fps') ||
    topGenreName.toLowerCase().includes('skjutspel') ||
    topGenreName.toLowerCase().includes('krig');

  if (
    (isShooterTop && topGenreShare >= 0.38 && completionRate < 0.38) ||
    (shooterShare >= 0.38 && completionRate < 0.38)
  ) {
    const stat1 = `${Math.min(99, Math.max(38, Math.round(shooterShare * 100)))}% Shooters`;
    const stat2 = `${completedCount}/${totalOwned} klarade`;
    return {
      archetypeID: 'tactical_operator',
      title: 'Tactical Operator',
      description:
        'Du lägger timmarna där det finns en match att vinna, inte en historia att avsluta.',
      icon: '🎯',
      accentHex: '#c7c23a',
      supportingStats: [stat1, stat2],
    };
  }

  // 8. Cozy Adventurer
  if (prefersCozy || (cozyShare >= 0.35 && completionRate >= 0.4)) {
    const stat1 = 'Cozy & Avkoppling';
    const stat2 = `${activeGenreCount} genrer aktiva`;
    return {
      archetypeID: 'cozy_adventurer',
      title: 'Cozy Adventurer',
      description:
        'Avkoppling, charm och atmosfär är ditt mantra — spel ska vara en varm tillflyktsort fri från stress och hets.',
      icon: '☕',
      accentHex: '#ec4899',
      supportingStats: [stat1, stat2],
    };
  }

  // 9. Squad Strategist
  if (multiplayerShare >= 0.32 && prefersCompetition) {
    const stat1 = `${Math.min(99, Math.round(multiplayerShare * 100))}% Multiplayer`;
    const stat2 = 'Lagspelare';
    return {
      archetypeID: 'squad_strategist',
      title: 'Squad Strategist',
      description:
        'Spelet är bäst när ni är fler — samarbete och tävling slår solo-berättelser varje gång.',
      icon: '🤝',
      accentHex: '#3cc8aa',
      supportingStats: [stat1, stat2],
    };
  }

  // 10. Casual Collector
  if (topGenreShare <= 0.38 && (wishlistGames.length >= 8 || totalOwned >= 10)) {
    const stat1 = `${wishlistGames.length} på önskelistan`;
    const stat2 = `${activeGenreCount} genrer aktiva`;
    return {
      archetypeID: 'casual_collector',
      title: 'Casual Collector',
      description:
        'Du samlar bredare än du hinner spela — biblioteket är lika mycket en önskelista som en att-göra-lista.',
      icon: '📦',
      accentHex: '#e6a03c',
      supportingStats: [stat1, stat2],
    };
  }

  // 11. Fallback: Genre-nomad
  const stat1 = `${activeGenreCount} genrer i hyllan`;
  const stat2 = `${totalOwned} ägda spel`;
  return {
    archetypeID: 'genre_nomad',
    title: 'Genre-nomad',
    description:
      'Du rör dig fritt mellan världar och genrer utan att fastna i ett fack — nyfikenheten styr nästa val.',
    icon: '🎲',
    accentHex: '#8b8b8f',
    supportingStats: [stat1, stat2],
  };
}
