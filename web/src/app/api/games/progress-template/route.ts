import { NextRequest, NextResponse } from 'next/server';

export const maxDuration = 60;
export const dynamic = 'force-dynamic';

export type ProgressionType = 'chapters' | 'acts' | 'main_quests' | 'bosses' | 'worlds' | 'none';
export type Granularity = 'compact' | 'standard' | 'detailed';

export interface ProgressTemplateItem {
  id: string;
  title: string;
  order: number;
  chapterGroup?: string;
  description?: string;
  isOptional?: boolean;
}

// Hjälpfunktion för att prioritera nyaste modellen (t.ex. 4.x -> 3.x -> 2.5 -> 2.0 -> 1.5)
function getModelPriorityScore(name: string): number {
  let score = 0;
  if (name.includes('gemini-4') || name.includes('argon')) {
    score += 4000;
  }
  const versionMatch = name.match(/gemini[^\d]*(\d+(?:\.\d+)?)/i);
  if (versionMatch) {
    const ver = parseFloat(versionMatch[1]);
    score += Math.round(ver * 1000);
  }

  // Föredra snabba Flash-modeller för responsivitet
  if (name.includes('flash')) score += 50;
  else if (name.includes('pro')) score += 30;

  // Undvik embeddings, audio eller specialmodeller
  if (name.includes('embed') || name.includes('aqa') || name.includes('learnlm') || name.includes('imagen')) {
    score -= 10000;
  }

  return score;
}

export interface GameProgressTemplate {
  gameTitle: string;
  igdbId?: number;
  hasLinearProgression: boolean;
  progressionType: ProgressionType;
  granularity?: Granularity;
  items: ProgressTemplateItem[];
  source: 'curated' | 'ai' | 'custom' | 'scraped_guide';
  sourceUrl?: string;
  modelUsed?: string;
  summary?: string;
}

// Förberedda kurerade mallar för ett antal kända spel
const CURATED_TEMPLATES: Record<string, Omit<GameProgressTemplate, 'source'>> = {
  'silent hill 2': {
    gameTitle: 'Silent Hill 2 (Remake)',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'James Sunders sökande efter Mary genom den dimhöljda och mardrömslika staden Silent Hill.',
    items: [
      { id: 'sh2-1', title: 'Östra South Vale & Stadsporten', order: 1, chapterGroup: 'South Vale' },
      { id: 'sh2-2', title: 'Wood Side Apartments', order: 2, chapterGroup: 'Lägenheterna' },
      { id: 'sh2-3', title: 'Blue Creek Apartments & Pyramid Head', order: 3, chapterGroup: 'Lägenheterna' },
      { id: 'sh2-4', title: 'Västra South Vale & Rosewater Park', order: 4, chapterGroup: 'South Vale' },
      { id: 'sh2-5', title: 'Brookhaven Hospital (Dimman)', order: 5, chapterGroup: 'Sjukhuset' },
      { id: 'sh2-6', title: 'Brookhaven Hospital (Otherworld)', order: 6, chapterGroup: 'Sjukhuset' },
      { id: 'sh2-7', title: 'Silent Hill gator (Nattvandring)', order: 7, chapterGroup: 'Natt' },
      { id: 'sh2-8', title: 'Silent Hill Historical Society', order: 8, chapterGroup: 'Historiska sällskapet' },
      { id: 'sh2-9', title: 'Toluca Prison', order: 9, chapterGroup: 'Fängelset' },
      { id: 'sh2-10', title: 'The Labyrinth', order: 10, chapterGroup: 'Labyrinten' },
      { id: 'sh2-11', title: 'Toluca Lake (Båtturen)', order: 11, chapterGroup: 'Sjön' },
      { id: 'sh2-12', title: 'Lakeview Hotel (Dimman)', order: 12, chapterGroup: 'Hotellet' },
      { id: 'sh2-13', title: 'Lakeview Hotel (Otherworld)', order: 13, chapterGroup: 'Hotellet' },
      { id: 'sh2-14', title: 'Slutstriden & Efterspelet', order: 14, chapterGroup: 'Final' },
    ],
  },
  'the last of us part i': {
    gameTitle: 'The Last of Us Part I',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Joel och Ellies resa genom USA, uppdelad i 12 kapitel och 4 årstider.',
    items: [
      { id: 'tlou-0', title: 'Prolog (Austin, Texas)', order: 1, chapterGroup: 'Sommar' },
      { id: 'tlou-1', title: 'Kapitel 1: Karantänzonen (Boston)', order: 2, chapterGroup: 'Sommar' },
      { id: 'tlou-2', title: 'Kapitel 2: Utkanten', order: 3, chapterGroup: 'Sommar' },
      { id: 'tlou-3', title: 'Kapitel 3: Bills stad', order: 4, chapterGroup: 'Sommar' },
      { id: 'tlou-4', title: 'Kapitel 4: Pittsburgh', order: 5, chapterGroup: 'Sommar' },
      { id: 'tlou-5', title: 'Kapitel 5: Förorten', order: 6, chapterGroup: 'Sommar' },
      { id: 'tlou-6', title: 'Kapitel 6: Tommys damm (Jackson)', order: 7, chapterGroup: 'Höst' },
      { id: 'tlou-7', title: 'Kapitel 7: Universitetet (Colorado)', order: 8, chapterGroup: 'Höst' },
      { id: 'tlou-8', title: 'Kapitel 8: Stugbyn vid sjön', order: 9, chapterGroup: 'Vinter' },
      { id: 'tlou-9', title: 'Kapitel 9: Bussterminalen (Salt Lake City)', order: 10, chapterGroup: 'Vår' },
      { id: 'tlou-10', title: 'Kapitel 10: Eldflugornas laboratorium', order: 11, chapterGroup: 'Vår' },
      { id: 'tlou-11', title: 'Epilog (Jackson)', order: 12, chapterGroup: 'Vår' },
    ],
  },
  'the last of us': {
    gameTitle: 'The Last of Us',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Joel och Ellies resa genom USA, uppdelad i 12 kapitel och 4 årstider.',
    items: [
      { id: 'tlou-0', title: 'Prolog (Austin, Texas)', order: 1, chapterGroup: 'Sommar' },
      { id: 'tlou-1', title: 'Kapitel 1: Karantänzonen (Boston)', order: 2, chapterGroup: 'Sommar' },
      { id: 'tlou-2', title: 'Kapitel 2: Utkanten', order: 3, chapterGroup: 'Sommar' },
      { id: 'tlou-3', title: 'Kapitel 3: Bills stad', order: 4, chapterGroup: 'Sommar' },
      { id: 'tlou-4', title: 'Kapitel 4: Pittsburgh', order: 5, chapterGroup: 'Sommar' },
      { id: 'tlou-5', title: 'Kapitel 5: Förorten', order: 6, chapterGroup: 'Sommar' },
      { id: 'tlou-6', title: 'Kapitel 6: Tommys damm (Jackson)', order: 7, chapterGroup: 'Höst' },
      { id: 'tlou-7', title: 'Kapitel 7: Universitetet (Colorado)', order: 8, chapterGroup: 'Höst' },
      { id: 'tlou-8', title: 'Kapitel 8: Stugbyn vid sjön', order: 9, chapterGroup: 'Vinter' },
      { id: 'tlou-9', title: 'Kapitel 9: Bussterminalen (Salt Lake City)', order: 10, chapterGroup: 'Vår' },
      { id: 'tlou-10', title: 'Kapitel 10: Eldflugornas laboratorium', order: 11, chapterGroup: 'Vår' },
      { id: 'tlou-11', title: 'Epilog (Jackson)', order: 12, chapterGroup: 'Vår' },
    ],
  },
  'cyberpunk 2077': {
    gameTitle: 'Cyberpunk 2077',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'V:s resa i Night City uppdelad i de centrala huvuduppdragen genom akterna.',
    items: [
      { id: 'cp-0', title: 'Prolog: Livsstil & Räddningsuppdraget', order: 1, chapterGroup: 'Prolog' },
      { id: 'cp-1', title: 'Akt 1: Kupen på Konpeki Plaza (The Heist)', order: 2, chapterGroup: 'Akt 1' },
      { id: 'cp-2', title: 'Akt 1: Uppvaknandet & Tom\'s Diner (Playing for Time)', order: 3, chapterGroup: 'Akt 1' },
      { id: 'cp-3', title: 'Akt 2: Automatic Love & The Space in Between (Judy)', order: 4, chapterGroup: 'Akt 2' },
      { id: 'cp-4', title: 'Akt 2: Ghost Town & Lightning Breaks (Panam)', order: 5, chapterGroup: 'Akt 2' },
      { id: 'cp-5', title: 'Akt 2: Down on the Street & Gimme Danger (Takemura)', order: 6, chapterGroup: 'Akt 2' },
      { id: 'cp-6', title: 'Akt 2: Transmission & Never Fade Away (Voodoo Boys)', order: 7, chapterGroup: 'Akt 2' },
      { id: 'cp-7', title: 'Akt 2: Play It Safe & Search and Destroy (Paraden)', order: 8, chapterGroup: 'Akt 2' },
      { id: 'cp-8', title: 'Akt 3: Nocturne Op55N1 (Point of No Return)', order: 9, chapterGroup: 'Akt 3' },
      { id: 'cp-9', title: 'Epilog: Slutuppdrag & Efterspel', order: 10, chapterGroup: 'Epilog' },
    ],
  },
  'the witcher 3: wild hunt': {
    gameTitle: 'The Witcher 3: Wild Hunt',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Geralts sökande efter Ciri, uppdelat efter de huvudsakliga storyuppdragen i varje region.',
    items: [
      { id: 'w3-0', title: 'Prolog: Vita pommern (Lilac and Gooseberries)', order: 1, chapterGroup: 'Prolog' },
      { id: 'w3-1', title: 'Akt 1 (Velen): Den blodige baronen & Häxorna i träsket', order: 2, chapterGroup: 'Akt 1' },
      { id: 'w3-2', title: 'Akt 1 (Novigrad): Jakten på Dandelion & Triss plan', order: 3, chapterGroup: 'Akt 1' },
      { id: 'w3-3', title: 'Akt 1 (Skellige): Uroboros mask & Kungavalet', order: 4, chapterGroup: 'Akt 1' },
      { id: 'w3-4', title: 'Akt 2: Förbannelsen över Uma (Ugly Baby)', order: 5, chapterGroup: 'Akt 2' },
      { id: 'w3-5', title: 'Akt 2: Dimöarna & Återföreningen (Isle of Mists)', order: 6, chapterGroup: 'Akt 2' },
      { id: 'w3-6', title: 'Akt 2: Slaget om Kaer Morhen', order: 7, chapterGroup: 'Akt 2' },
      { id: 'w3-7', title: 'Akt 3: Slutförberedelser & Solstenen (Sunstone)', order: 8, chapterGroup: 'Akt 3' },
      { id: 'w3-8', title: 'Akt 3: Slutstriden mot Eredin (Tedd Deireadh)', order: 9, chapterGroup: 'Akt 3' },
    ],
  },
  'elden ring': {
    gameTitle: 'Elden Ring',
    hasLinearProgression: true,
    progressionType: 'bosses',
    summary: 'Framsteg i Lands Between mäts bäst genom de nödvändiga och huvudsakliga bossarna.',
    items: [
      { id: 'er-1', title: 'Margit, the Fell Omen (Stormveil)', order: 1, chapterGroup: 'Limgrave' },
      { id: 'er-2', title: 'Godrick the Grafted (Stormveil)', order: 2, chapterGroup: 'Limgrave' },
      { id: 'er-3', title: 'Rennala, Queen of the Full Moon (Raya Lucaria)', order: 3, chapterGroup: 'Liurnia' },
      { id: 'er-4', title: 'Starscourge Radahn (Redmane Castle)', order: 4, chapterGroup: 'Caelid' },
      { id: 'er-5', title: 'Rykard, Lord of Blasphemy (Volcano Manor)', order: 5, chapterGroup: 'Mt. Gelmir', isOptional: true },
      { id: 'er-6', title: 'Morgott, the Omen King (Leyndell)', order: 6, chapterGroup: 'Huvudstaden' },
      { id: 'er-7', title: 'Fire Giant (Mountaintops of the Giants)', order: 7, chapterGroup: 'Bergen' },
      { id: 'er-8', title: 'Godskin Duo (Crumbling Farum Azula)', order: 8, chapterGroup: 'Farum Azula' },
      { id: 'er-9', title: 'Maliketh, the Black Blade (Farum Azula)', order: 9, chapterGroup: 'Farum Azula' },
      { id: 'er-10', title: 'Sir Gideon Ofnir & Godfrey / Hoarah Loux', order: 10, chapterGroup: 'Askhuvudstaden' },
      { id: 'er-11', title: 'Radagon of the Golden Order & Elden Beast', order: 11, chapterGroup: 'Final' },
    ],
  },
  'super mario odyssey': {
    gameTitle: 'Super Mario Odyssey',
    hasLinearProgression: true,
    progressionType: 'worlds',
    summary: 'Marios resa genom rikena med luftskeppet Odyssey för att rädda Peach.',
    items: [
      { id: 'smo-1', title: 'Cap Kingdom (Bonneton)', order: 1, chapterGroup: 'Tidiga riken' },
      { id: 'smo-2', title: 'Cascade Kingdom (Fossil Falls)', order: 2, chapterGroup: 'Tidiga riken' },
      { id: 'smo-3', title: 'Sand Kingdom (Tostarena)', order: 3, chapterGroup: 'Tidiga riken' },
      { id: 'smo-4', title: 'Lake Kingdom & Wooded Kingdom', order: 4, chapterGroup: 'Skog & Sjö' },
      { id: 'smo-5', title: 'Cloud Kingdom & Lost Kingdom', order: 5, chapterGroup: 'Mellanriken' },
      { id: 'smo-6', title: 'Metro Kingdom (New Donk City)', order: 6, chapterGroup: 'Storstaden' },
      { id: 'smo-7', title: 'Snow Kingdom & Seaside Kingdom', order: 7, chapterGroup: 'Snö & Kust' },
      { id: 'smo-8', title: 'Luncheon Kingdom (Mount Volbono)', order: 8, chapterGroup: 'Vulkan' },
      { id: 'smo-9', title: 'Ruined Kingdom & Bowser\'s Kingdom', order: 9, chapterGroup: 'Slott' },
      { id: 'smo-10', title: 'Moon Kingdom & Slutstriden', order: 10, chapterGroup: 'Månen' },
      { id: 'smo-11', title: 'Mushroom Kingdom (Post-game)', order: 11, chapterGroup: 'Efterspel', isOptional: true },
    ],
  },
  'resident evil 2': {
    gameTitle: 'Resident Evil 2 (Remake)',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Leon Kennedy och Claire Redfields överlevnadskamp genom R.P.D., kloakerna och Umbrella NEST-laboratoriet i Raccoon City.',
    items: [
      { id: 're2-1', title: 'Prolog: Bensinstationen & Ankomsten till Raccoon City', order: 1, chapterGroup: 'Prolog' },
      { id: 're2-2', title: 'R.P.D. Västra flygeln & De tre medaljongerna', order: 2, chapterGroup: 'Polisstationen' },
      { id: 're2-3', title: 'Underjorden & Mötet med G-Birkin (G-1)', order: 3, chapterGroup: 'Polisstationen' },
      { id: 're2-4', title: 'R.P.D. Parkeringsgaraget & Häktet (Elektroniska delarna)', order: 4, chapterGroup: 'Polisstationen' },
      { id: 're2-5', title: 'Bakhållet: Tyrant / Mr. X dyker upp', order: 5, chapterGroup: 'Polisstationen' },
      { id: 're2-6', title: 'Klocktornet & Utredningen bakom stationen / Barnhemmet', order: 6, chapterGroup: 'Polisstationen' },
      { id: 're2-7', title: 'Kloakerna: Schackpjäserna & U-banan', order: 7, chapterGroup: 'Kloakerna' },
      { id: 're2-8', title: 'Vattenreningsverket & Mötet med G-2 Birkin', order: 8, chapterGroup: 'Kloakerna' },
      { id: 're2-9', title: 'Kabelbanan till Umbrella NEST Laboratory', order: 9, chapterGroup: 'Laboratoriet' },
      { id: 're2-10', title: 'NEST: Receptionen & Gröna zonen (Plant 43 / V-Jolt)', order: 10, chapterGroup: 'Laboratoriet' },
      { id: 're2-11', title: 'NEST: Västra zonen, G-viruset & Slaget mot G-3 Birkin', order: 11, chapterGroup: 'Laboratoriet' },
      { id: 're2-12', title: 'Självförstörelsen, Slutstriden (Super Tyrant / G-4) & Evakueringståget', order: 12, chapterGroup: 'Final' },
    ],
  },
  'resident evil 4': {
    gameTitle: 'Resident Evil 4 (Remake)',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Leons uppdrag att rädda Ashley, uppdelat i byn, slottet och ön.',
    items: [
      { id: 're4-1', title: 'Kapitel 1–2: Byn, jägarstugan och kyrkan', order: 1, chapterGroup: 'Byn' },
      { id: 're4-2', title: 'Kapitel 3–4: Sjön, Del Lago och El Gigante', order: 2, chapterGroup: 'Byn' },
      { id: 're4-3', title: 'Kapitel 5–6: Stugan, slakthuset och Mendez', order: 3, chapterGroup: 'Byn' },
      { id: 're4-4', title: 'Kapitel 7–8: Slottets murar och vattenhallen', order: 4, chapterGroup: 'Slottet' },
      { id: 're4-5', title: 'Kapitel 9–10: Labyrinten, balsalen och Verdugo', order: 5, chapterGroup: 'Slottet' },
      { id: 're4-6', title: 'Kapitel 11–12: Gruvvagnarna och Ramon Salazar', order: 6, chapterGroup: 'Slottet' },
      { id: 're4-7', title: 'Kapitel 13–14: Ön, Regeneradors och Jack Krauser', order: 7, chapterGroup: 'Ön' },
      { id: 're4-8', title: 'Kapitel 15–16: Fristaden, Saddler och flykten', order: 8, chapterGroup: 'Ön' },
    ],
  },
  'baldur\'s gate 3': {
    gameTitle: 'Baldur\'s Gate 3',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Den storslagna kampanjen uppdelad i de huvudsakliga vändpunkterna genom akterna.',
    items: [
      { id: 'bg3-0', title: 'Prolog: Flykten från Nautiloid', order: 1, chapterGroup: 'Prolog' },
      { id: 'bg3-1', title: 'Akt 1: Druid Grove & Goblin Camp (Halsin & Minthara)', order: 2, chapterGroup: 'Akt 1' },
      { id: 'bg3-2', title: 'Akt 1: Underdark & Grymforge (Adamantine Forge)', order: 3, chapterGroup: 'Akt 1' },
      { id: 'bg3-3', title: 'Akt 1: Mountain Pass & Githyanki Creche (Vlaakith)', order: 4, chapterGroup: 'Akt 1' },
      { id: 'bg3-4', title: 'Akt 2: Shadow-Cursed Lands & Last Light Inn', order: 5, chapterGroup: 'Akt 2' },
      { id: 'bg3-5', title: 'Akt 2: Gauntlet of Shar & Nightsong', order: 6, chapterGroup: 'Akt 2' },
      { id: 'bg3-6', title: 'Akt 2: Belägringen av Moonrise Towers & Ketheric Thorm', order: 7, chapterGroup: 'Akt 2' },
      { id: 'bg3-7', title: 'Akt 3: Rivington & Cirkusen', order: 8, chapterGroup: 'Akt 3' },
      { id: 'bg3-8', title: 'Akt 3: Nedre staden – Konfrontationen med Enver Gortash', order: 9, chapterGroup: 'Akt 3' },
      { id: 'bg3-9', title: 'Akt 3: Mordtemplet – Konfrontationen med Orin the Red', order: 10, chapterGroup: 'Akt 3' },
      { id: 'bg3-10', title: 'Akt 3: Slutstriden mot Netherbrain & Kronan', order: 11, chapterGroup: 'Akt 3' },
    ],
  },
  'kingdom come: deliverance': {
    gameTitle: 'Kingdom Come: Deliverance',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Smeden Henrys resa genom det medeltida Böhmen – från Skalitz överfall till belägringen av Talmberg.',
    items: [
      { id: 'kcd1-1', title: 'Unexpected Visitors', order: 1, chapterGroup: 'Skalitz' },
      { id: 'kcd1-2', title: 'Run!', order: 2, chapterGroup: 'Skalitz' },
      { id: 'kcd1-3', title: 'Homecoming', order: 3, chapterGroup: 'Skalitz' },
      { id: 'kcd1-4', title: 'Awakening', order: 4, chapterGroup: 'Rattay' },
      { id: 'kcd1-5', title: 'Train Hard, Fight Easy', order: 5, chapterGroup: 'Rattay' },
      { id: 'kcd1-6', title: 'Keeping the Peace', order: 6, chapterGroup: 'Rattay' },
      { id: 'kcd1-7', title: 'The Prey', order: 7, chapterGroup: 'Rattay' },
      { id: 'kcd1-8', title: 'The Hunt Begins', order: 8, chapterGroup: 'Neuhof' },
      { id: 'kcd1-9', title: 'Ginger in a Pickle', order: 9, chapterGroup: 'Neuhof' },
      { id: 'kcd1-10', title: 'Mysterious Ways', order: 10, chapterGroup: 'Uzhitz' },
      { id: 'kcd1-11', title: 'On the Scent', order: 11, chapterGroup: 'Ledetchko' },
      { id: 'kcd1-12', title: 'My Friend Timmy', order: 12, chapterGroup: 'Merhojed' },
      { id: 'kcd1-13', title: 'Nest of Vipers', order: 13, chapterGroup: 'Pribyslavitz' },
      { id: 'kcd1-14', title: 'Baptism of Fire', order: 14, chapterGroup: 'Pribyslavitz' },
      { id: 'kcd1-15', title: 'Questions and Answers', order: 15, chapterGroup: 'Merhojed' },
      { id: 'kcd1-16', title: 'All that Glisters', order: 16, chapterGroup: 'Sasau' },
      { id: 'kcd1-17', title: 'If You Can\'t Beat \'em', order: 17, chapterGroup: 'Sasau' },
      { id: 'kcd1-18', title: 'Poverty, Chastity and Pestilence', order: 18, chapterGroup: 'Klostret' },
      { id: 'kcd1-19', title: 'A Needle in a Haystack', order: 19, chapterGroup: 'Klostret' },
      { id: 'kcd1-20', title: 'The Die is Cast', order: 20, chapterGroup: 'Vranik' },
      { id: 'kcd1-21', title: 'Payback', order: 21, chapterGroup: 'Vranik' },
      { id: 'kcd1-22', title: 'Out of the Frying Pan into the Fire', order: 22, chapterGroup: 'Talmberg' },
      { id: 'kcd1-23', title: 'Night Raid', order: 23, chapterGroup: 'Talmberg' },
      { id: 'kcd1-24', title: 'Siege & Cold Steel, Hot Blood', order: 24, chapterGroup: 'Talmberg' },
      { id: 'kcd1-25', title: 'Family Values', order: 25, chapterGroup: 'Talmberg' },
      { id: 'kcd1-26', title: 'An Honorable Word', order: 26, chapterGroup: 'Talmberg' },
      { id: 'kcd1-27', title: 'Epilogue', order: 27, chapterGroup: 'Final' },
    ],
  },
  'kingdom come deliverance': {
    gameTitle: 'Kingdom Come: Deliverance',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Smeden Henrys resa genom det medeltida Böhmen – från Skalitz överfall till belägringen av Talmberg.',
    items: [
      { id: 'kcd1-1', title: 'Unexpected Visitors', order: 1, chapterGroup: 'Skalitz' },
      { id: 'kcd1-2', title: 'Run!', order: 2, chapterGroup: 'Skalitz' },
      { id: 'kcd1-3', title: 'Homecoming', order: 3, chapterGroup: 'Skalitz' },
      { id: 'kcd1-4', title: 'Awakening', order: 4, chapterGroup: 'Rattay' },
      { id: 'kcd1-5', title: 'Train Hard, Fight Easy', order: 5, chapterGroup: 'Rattay' },
      { id: 'kcd1-6', title: 'Keeping the Peace', order: 6, chapterGroup: 'Rattay' },
      { id: 'kcd1-7', title: 'The Prey', order: 7, chapterGroup: 'Rattay' },
      { id: 'kcd1-8', title: 'The Hunt Begins', order: 8, chapterGroup: 'Neuhof' },
      { id: 'kcd1-9', title: 'Ginger in a Pickle', order: 9, chapterGroup: 'Neuhof' },
      { id: 'kcd1-10', title: 'Mysterious Ways', order: 10, chapterGroup: 'Uzhitz' },
      { id: 'kcd1-11', title: 'On the Scent', order: 11, chapterGroup: 'Ledetchko' },
      { id: 'kcd1-12', title: 'My Friend Timmy', order: 12, chapterGroup: 'Merhojed' },
      { id: 'kcd1-13', title: 'Nest of Vipers', order: 13, chapterGroup: 'Pribyslavitz' },
      { id: 'kcd1-14', title: 'Baptism of Fire', order: 14, chapterGroup: 'Pribyslavitz' },
      { id: 'kcd1-15', title: 'Questions and Answers', order: 15, chapterGroup: 'Merhojed' },
      { id: 'kcd1-16', title: 'All that Glisters', order: 16, chapterGroup: 'Sasau' },
      { id: 'kcd1-17', title: 'If You Can\'t Beat \'em', order: 17, chapterGroup: 'Sasau' },
      { id: 'kcd1-18', title: 'Poverty, Chastity and Pestilence', order: 18, chapterGroup: 'Klostret' },
      { id: 'kcd1-19', title: 'A Needle in a Haystack', order: 19, chapterGroup: 'Klostret' },
      { id: 'kcd1-20', title: 'The Die is Cast', order: 20, chapterGroup: 'Vranik' },
      { id: 'kcd1-21', title: 'Payback', order: 21, chapterGroup: 'Vranik' },
      { id: 'kcd1-22', title: 'Out of the Frying Pan into the Fire', order: 22, chapterGroup: 'Talmberg' },
      { id: 'kcd1-23', title: 'Night Raid', order: 23, chapterGroup: 'Talmberg' },
      { id: 'kcd1-24', title: 'Siege & Cold Steel, Hot Blood', order: 24, chapterGroup: 'Talmberg' },
      { id: 'kcd1-25', title: 'Family Values', order: 25, chapterGroup: 'Talmberg' },
      { id: 'kcd1-26', title: 'An Honorable Word', order: 26, chapterGroup: 'Talmberg' },
      { id: 'kcd1-27', title: 'Epilogue', order: 27, chapterGroup: 'Final' },
    ],
  },
  'kingdom come: deliverance ii': {
    gameTitle: 'Kingdom Come: Deliverance II',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Henrys fortsatta resa genom Böhmen, uppdelad i Trosky- och Kuttenberg-regionerna.',
    items: [
      { id: 'kcd2-1', title: 'Last Rites (Trosky)', order: 1, chapterGroup: 'Trosky' },
      { id: 'kcd2-2', title: 'Easy Riders', order: 2, chapterGroup: 'Trosky' },
      { id: 'kcd2-3', title: 'Fortuna', order: 3, chapterGroup: 'Trosky' },
      { id: 'kcd2-4', title: 'Laboratores', order: 4, chapterGroup: 'Trosky' },
      { id: 'kcd2-5', title: 'Wedding Crashers', order: 5, chapterGroup: 'Trosky' },
      { id: 'kcd2-6', title: 'For Whom The Bell Tolls', order: 6, chapterGroup: 'Trosky' },
      { id: 'kcd2-7', title: 'Back In The Saddle', order: 7, chapterGroup: 'Trosky' },
      { id: 'kcd2-8', title: 'Necessary Evil', order: 8, chapterGroup: 'Trosky' },
      { id: 'kcd2-9', title: 'The Sword and the Quill', order: 9, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-10', title: 'Speak of the Devil', order: 10, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-11', title: 'The Devil\'s Pack (Dry Devil)', order: 11, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-12', title: 'Into the Underworld', order: 12, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-13', title: 'Via Argentum', order: 13, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-14', title: 'Taking French Leave', order: 14, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-15', title: 'The King\'s Gambit', order: 15, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-16', title: 'The Feast & The Italian Job (Silver Heist)', order: 16, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-17', title: 'Judgement Day (Final Siege)', order: 17, chapterGroup: 'Final' },
    ],
  },
  'kingdom come deliverance 2': {
    gameTitle: 'Kingdom Come: Deliverance II',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Henrys fortsatta resa genom Böhmen, uppdelad i Trosky- och Kuttenberg-regionerna.',
    items: [
      { id: 'kcd2-1', title: 'Last Rites (Trosky)', order: 1, chapterGroup: 'Trosky' },
      { id: 'kcd2-2', title: 'Easy Riders', order: 2, chapterGroup: 'Trosky' },
      { id: 'kcd2-3', title: 'Fortuna', order: 3, chapterGroup: 'Trosky' },
      { id: 'kcd2-4', title: 'Laboratores', order: 4, chapterGroup: 'Trosky' },
      { id: 'kcd2-5', title: 'Wedding Crashers', order: 5, chapterGroup: 'Trosky' },
      { id: 'kcd2-6', title: 'For Whom The Bell Tolls', order: 6, chapterGroup: 'Trosky' },
      { id: 'kcd2-7', title: 'Back In The Saddle', order: 7, chapterGroup: 'Trosky' },
      { id: 'kcd2-8', title: 'Necessary Evil', order: 8, chapterGroup: 'Trosky' },
      { id: 'kcd2-9', title: 'The Sword and the Quill', order: 9, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-10', title: 'Speak of the Devil', order: 10, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-11', title: 'The Devil\'s Pack (Dry Devil)', order: 11, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-12', title: 'Into the Underworld', order: 12, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-13', title: 'Via Argentum', order: 13, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-14', title: 'Taking French Leave', order: 14, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-15', title: 'The King\'s Gambit', order: 15, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-16', title: 'The Feast & The Italian Job (Silver Heist)', order: 16, chapterGroup: 'Kuttenberg' },
      { id: 'kcd2-17', title: 'Judgement Day (Final Siege)', order: 17, chapterGroup: 'Final' },
    ],
  },
  '007 first light': {
    gameTitle: '007 First Light',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'James Bonds ursprung som agent genom 10 kapitel och 18 uppdrag.',
    items: [
      { id: '007-0', title: 'Prologue: Against All Odds (Iceland)', order: 1, chapterGroup: 'Prolog' },
      { id: '007-1', title: 'In His Majesty\'s Secret Service (MI6)', order: 2, chapterGroup: 'MI6 HQ' },
      { id: '007-2', title: 'Chapter 1: The Needle\'s Eye (Malta)', order: 3, chapterGroup: 'Träning' },
      { id: '007-3', title: 'Chapter 2: The Heart of the Matter (MI6)', order: 4, chapterGroup: 'Briefing' },
      { id: '007-4', title: 'Chapter 3: A New Home', order: 5, chapterGroup: 'Aktiv tjänst' },
      { id: '007-5', title: 'Chapter 4: A Night Out (London)', order: 6, chapterGroup: 'London' },
      { id: '007-6', title: 'Chapter 5: A Matter of Considerable Delicacy', order: 7, chapterGroup: 'Diplomati' },
      { id: '007-7', title: 'Chapter 6: All the Time in the World (Slovakia)', order: 8, chapterGroup: 'Slovakien' },
      { id: '007-8', title: 'Chapter 7: Out of the Ashes / The Past Never Dies', order: 9, chapterGroup: 'Mauretanien' },
      { id: '007-9', title: 'Chapter 8: Uninvited (London)', order: 10, chapterGroup: 'London' },
      { id: '007-10', title: 'Chapter 9: Knightfall', order: 11, chapterGroup: 'Kulmen' },
      { id: '007-11', title: 'Chapter 10: Going Old School & For England', order: 12, chapterGroup: 'Final' },
    ],
  },
  'rocket league': {
    gameTitle: 'Rocket League',
    hasLinearProgression: false,
    progressionType: 'none',
    summary: 'Ett flerspelar- och tävlingsspel utan linjär berättelse eller kapitel.',
    items: [],
  },
};
 
function normalizeTitle(t: string): string {
  return t
    .toLowerCase()
    .replace(/[:\-–—\']/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function findCuratedTemplate(gameTitle: string): GameProgressTemplate | null {
  const normQuery = normalizeTitle(gameTitle);
  if (!normQuery) return null;

  // 1. Försök exakt matchning på normaliserad titel
  for (const [key, template] of Object.entries(CURATED_TEMPLATES)) {
    if (normalizeTitle(key) === normQuery) {
      return {
        ...template,
        granularity: 'standard',
        source: 'curated',
      } as GameProgressTemplate;
    }
  }

  // Regex för att detektera uppföljare (2, ii, 3, iii, part 2 etc.)
  const sequelSuffixRegex = /\b(ii|iii|iv|v|2|3|4|5|part\s*2|part\s*ii|part\s*3)\b/i;
  const querySequelMatch = normQuery.match(sequelSuffixRegex);
  const querySequel = querySequelMatch ? querySequelMatch[0].toLowerCase() : null;

  // 2. Om ingen exakt match, kolla delsträng/ord-match men VAR STRIKT med uppföljare:
  for (const [key, template] of Object.entries(CURATED_TEMPLATES)) {
    const normKey = normalizeTitle(key);
    const keySequelMatch = normKey.match(sequelSuffixRegex);
    const keySequel = keySequelMatch ? keySequelMatch[0].toLowerCase() : null;

    // Om templaten är en uppföljare (t.ex. KCD II), men användaren INTE sökte efter uppföljaren:
    // matcha ALDRIG!
    if (keySequel && !querySequel) {
      continue;
    }

    // Om användaren uttryckligen sökte efter uppföljare (t.ex. KCD 2), men templaten är del 1:
    // matcha ALDRIG!
    if (querySequel && !keySequel) {
      continue;
    }

    if (normQuery.includes(normKey) || normKey.includes(normQuery)) {
      return {
        ...template,
        granularity: 'standard',
        source: 'curated',
      } as GameProgressTemplate;
    }
  }

  return null;
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const gameTitle: string = (body.gameTitle || '').trim();
    const guideUrl: string = (body.guideUrl || '').trim();
    const geminiKey: string = (body.geminiApiKey || process.env.GEMINI_API_KEY || '').trim();
    const granularity: Granularity = body.granularity || 'standard';
    const forceAI: boolean = Boolean(body.forceAI) || Boolean(guideUrl);

    if (!gameTitle && !guideUrl) {
      return NextResponse.json({ error: 'gameTitle eller guideUrl krävs' }, { status: 400 });
    }

    // 0. Om en specifik guide-URL angetts (Alternativ 2: Scraping + AI)
    if (guideUrl) {
      if (!geminiKey) {
        return NextResponse.json(
          { error: 'En Gemini API-nyckel krävs för att analysera innehållet från guiden.' },
          { status: 400 }
        );
      }
      try {
        const scrapedTemplate = await fetchAndExtractFromUrl(
          gameTitle || 'Spelet',
          guideUrl,
          geminiKey,
          granularity
        );
        return NextResponse.json(scrapedTemplate);
      } catch (err: any) {
        console.error('Guide URL extraction failed:', err);
        return NextResponse.json(
          { error: `Kunde inte hämta eller tolka guiden: ${err.message || 'Okänt fel'}` },
          { status: 500 }
        );
      }
    }

    // 1. Kolla kurerade mallar (om inte forceAI är aktiverat)
    if (!forceAI) {
      const curated = findCuratedTemplate(gameTitle);
      if (curated) {
        return NextResponse.json(curated);
      }
    }

    // 2. Om ingen kurerad mall matchar eller om användaren vill köra med AI
    if (geminiKey) {
      try {
        const aiTemplate = await fetchWithGemini(gameTitle, geminiKey, granularity);
        if (aiTemplate) {
          return NextResponse.json(aiTemplate);
        }
      } catch (err: any) {
        console.error('Gemini extraction failed:', err);
        return NextResponse.json(
          { error: `AI-generering misslyckades: ${err.message || 'Okänt fel'}` },
          { status: 500 }
        );
      }
    }

    // 3. Om ingen match och ingen AI-nyckel
    return NextResponse.json(
      {
        notFound: true,
        message: `Ingen förberedd mall hittades för "${gameTitle}". Ange en Gemini API-nyckel för att generera kapitel med AI i realtid, eller välj ett av de förberedda spelen.`,
      },
      { status: 404 }
    );
  } catch (error: any) {
    console.error('Progress template error:', error);
    return NextResponse.json({ error: error.message || 'Serverfel' }, { status: 500 });
  }
}

async function fetchWithGemini(
  gameTitle: string,
  apiKey: string,
  granularity: Granularity
): Promise<GameProgressTemplate> {
  const cleanKey = apiKey.trim();
  const targetCount =
    granularity === 'compact'
      ? 'ca 8 till 12'
      : granularity === 'detailed'
      ? 'ca 20 till 30'
      : 'ca 14 till 22';

  const prompt = `You are an expert video game progression analyst.
Extract the official chapter and main quest progression list for the video game "${gameTitle}" based on IGN's official walkthrough / guide.
Target granularity: ${granularity} (approximately ${targetCount} story milestones).

STRICT RULES:
1. IGN WALKTHROUGH ACCURACY:
   - Extract the exact chapter or quest titles as structured in IGN's official walkthrough / guide for "${gameTitle}".
   - Keep the original OFFICIAL ENGLISH titles for all items (e.g. "R.P.D. - Central Hall", "The Sewers", "NEST Laboratory"). Do not translate quest titles to Swedish!
2. CHRONOLOGICAL STORY ORDER:
   - List the items in the order they are completed in the main story.
3. EXCLUDE SIDE ACTIVITIES:
   - Only include main story chapters, acts, or major story bosses.
4. VALID JSON:
   - Return valid JSON matching this schema:
{
  "gameTitle": "${gameTitle}",
  "hasLinearProgression": true,
  "progressionType": "chapters" | "acts" | "main_quests" | "bosses" | "worlds" | "none",
  "summary": "Kort svensk sammanfattning av spelets handling och upplägg baserat på IGN:s guide",
  "items": [
    {
      "id": "1",
      "title": "Exact English Quest / Chapter Title",
      "order": 1,
      "chapterGroup": "Area or Act",
      "description": "Kort beskrivning",
      "isOptional": false
    }
  ]
}`;

  // 1. Verifiera först API-nyckeln och hämta de aktiva modellerna från Google
  let candidateModels = [
    'gemini-3.8-flash',
    'gemini-3.0-flash',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];
  let keyError: string | null = null;

  try {
    const listRes = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(cleanKey)}`,
      { signal: AbortSignal.timeout(5000) }
    );
    if (!listRes.ok) {
      const errText = await listRes.text();
      let parsedMsg = errText;
      try {
        const json = JSON.parse(errText);
        parsedMsg = json.error?.message || errText;
      } catch {}
      keyError = `Gemini API-fel (${listRes.status}): ${parsedMsg}`;
    } else {
      const listData = await listRes.json();
      if (Array.isArray(listData.models)) {
        const supported: string[] = listData.models
          .filter((m: any) => m.supportedGenerationMethods?.includes('generateContent'))
          .map((m: any) => (m.name as string).replace(/^models\//, ''))
          // Filtrera strikt bort TTS, audio, bild och embeddings
          .filter(
            (name: string) =>
              !name.includes('tts') &&
              !name.includes('audio') &&
              !name.includes('embed') &&
              !name.includes('imagen') &&
              !name.includes('aqa') &&
              !name.includes('learnlm')
          );

        // Hjälpfunktion för att extrahera versionsnummer (t.ex. gemini-3.8-flash -> 3.8)
        const getVer = (name: string): number => {
          const match = name.match(/gemini[^\d]*(\d+(?:\.\d+)?)/i);
          return match ? parseFloat(match[1]) : 0;
        };

        // Sortera:
        // 1. Flash-modeller först, sorterade med nyast version först (t.ex. 3.8 -> 3.5 -> 3.0 -> 2.5)
        // 2. Pro-modeller därefter, också nyast först
        const flashModels = supported
          .filter((m: string) => m.includes('flash'))
          .sort((a: string, b: string) => getVer(b) - getVer(a));

        const otherModels = supported
          .filter((m: string) => !m.includes('flash'))
          .sort((a: string, b: string) => getVer(b) - getVer(a));

        const ordered = [...flashModels, ...otherModels];
        const unique = Array.from(new Set(ordered));
        if (unique.length > 0) {
          candidateModels = unique.slice(0, 2);
        }
      }
    }
  } catch (listErr: any) {
    console.warn('Could not query model list, falling back to defaults:', listErr);
  }

  // Om API-nyckeln är ogiltig hos Google
  if (keyError) {
    throw new Error(keyError);
  }

  const attemptErrors: string[] = [];

  for (const modelName of candidateModels) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${encodeURIComponent(cleanKey)}`;

      let response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: AbortSignal.timeout(20000),
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.1,
            responseMimeType: 'application/json',
            maxOutputTokens: 2048,
          },
        }),
      });

      // Om modellen inte stöder responseMimeType, prova utan
      if (!response.ok && response.status === 400) {
        response = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          signal: AbortSignal.timeout(15000),
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              temperature: 0.1,
              maxOutputTokens: 2048,
            },
          }),
        });
      }

      if (!response.ok) {
        const errBody = await response.text();
        let errMsg = errBody;
        try {
          const errJson = JSON.parse(errBody);
          errMsg = errJson.error?.message || errBody;
        } catch {}
        attemptErrors.push(`${modelName} (${response.status}): ${errMsg}`);
        continue;
      }

      const data = await response.json();
      const textContent = data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!textContent) {
        attemptErrors.push(`${modelName}: tomt svar`);
        continue;
      }

      return parseGeminiOutput(textContent, gameTitle, granularity, modelName);
    } catch (err: any) {
      attemptErrors.push(`${modelName}: ${err.message || 'Okänt fel'}`);
    }
  }

  throw new Error(`Kunde inte generera med modellerna (${attemptErrors.join(' | ')})`);
}

function parseGeminiOutput(
  rawText: string,
  gameTitle: string,
  granularity: Granularity,
  modelUsed?: string
): GameProgressTemplate {
  let cleaned = rawText.trim();

  // 1. Försök hitta markdown-kodblock ```json ... ```
  const codeBlockMatch = cleaned.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  if (codeBlockMatch) {
    cleaned = codeBlockMatch[1].trim();
  } else {
    // 2. Om inget kodblock finns, hitta första { till sista }
    const firstBrace = cleaned.indexOf('{');
    const lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
      cleaned = cleaned.substring(firstBrace, lastBrace + 1).trim();
    }
  }

  let parsed: any;
  try {
    parsed = JSON.parse(cleaned);
  } catch (err) {
    console.error('Failed to parse Gemini JSON output:', cleaned);
    throw new Error('Kunde inte tolka svaret från AI som giltig JSON.');
  }

  const items = Array.isArray(parsed.items) ? parsed.items : [];
  const hasLinear =
    parsed.hasLinearProgression !== undefined
      ? Boolean(parsed.hasLinearProgression)
      : items.length > 0;

  return {
    gameTitle: parsed.gameTitle || gameTitle,
    hasLinearProgression: hasLinear,
    progressionType: parsed.progressionType || (items.length > 0 ? 'chapters' : 'none'),
    granularity,
    summary: parsed.summary || '',
    items: items.map((item: any, idx: number) => ({
      id: String(item.id || idx + 1),
      title: String(item.title || `Delmål ${idx + 1}`),
      order: Number(item.order || idx + 1),
      chapterGroup: item.chapterGroup,
      description: item.description,
      isOptional: Boolean(item.isOptional),
    })),
    source: 'ai',
    modelUsed,
  };
}

async function fetchAndExtractFromUrl(
  gameTitle: string,
  guideUrl: string,
  apiKey: string,
  granularity: Granularity
): Promise<GameProgressTemplate> {
  let parsedUrl: URL;
  try {
    parsedUrl = new URL(guideUrl);
  } catch {
    throw new Error('Ogiltig webbadress. Ange en fullständig länk inklusive https://');
  }

  let guideSample = '';
  let fetchedDirectly = false;

  // 1. Försök med direkt webbhämtning
  try {
    const res = await fetch(parsedUrl.toString(), {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
      },
      signal: AbortSignal.timeout(6000),
      redirect: 'follow',
    });

    if (res.ok) {
      const html = await res.text();
      const cleanedText = html
        .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, ' ')
        .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, ' ')
        .replace(/<noscript\b[^<]*(?:(?!<\/noscript>)<[^<]*)*<\/noscript>/gi, ' ')
        .replace(/<svg\b[^<]*(?:(?!<\/svg>)<[^<]*)*<\/svg>/gi, ' ')
        .replace(/<!--[\s\S]*?-->/g, ' ')
        .replace(/<h[1-6][^>]*>(.*?)<\/h[1-6]>/gi, '\n### $1\n')
        .replace(/<li[^>]*>(.*?)<\/li>/gi, '\n- $1\n')
        .replace(/<a [^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/gi, '$2 ')
        .replace(/<[^>]+>/g, ' ')
        .replace(/&nbsp;/g, ' ')
        .replace(/&amp;/g, '&')
        .replace(/&quot;/g, '"')
        .replace(/&#39;/g, "'")
        .replace(/\s{2,}/g, ' ')
        .replace(/\n\s*\n/g, '\n')
        .trim();

      if (cleanedText.length > 200) {
        guideSample = cleanedText.substring(0, 40000);
        fetchedDirectly = true;
      }
    }
  } catch (fetchErr) {
    console.warn('Direct guide fetch failed, falling back to search grounding:', fetchErr);
  }

  const targetCount =
    granularity === 'compact'
      ? 'ca 8 till 12'
      : granularity === 'detailed'
      ? 'ca 20 till 30'
      : 'ca 14 till 22';

  // Skapa anpassad prompt beroende på om vi fick råtexten direkt eller behöver söka upp URL:en
  let prompt: string;
  let useSearchTool = false;

  if (fetchedDirectly) {
    prompt = `You are an expert game progression extractor.
The user wants to track story progress for "${gameTitle}".
Extract the official, chronological list of main missions / chapters / areas directly from the provided guide text below.

Target game: "${gameTitle}"
Desired granularity: ${granularity} (target ${targetCount} items).
Source URL: ${guideUrl}

STRICT EXTRACTION RULES:
1. ONLY USE THE TEXT PROVIDED BELOW:
   - Extract the exact chapter or quest titles as listed in this guide.
   - Do NOT invent or hallucinate quests.
   - Keep the original OFFICIAL ENGLISH titles from the guide. Do not translate them to Swedish!
2. CHRONOLOGICAL ORDER:
   - List the items in the order they are completed in the main story.
3. EXCLUDE SIDE QUESTS & COLLECTIBLES:
   - Only include main story chapters/quests (unless marked isOptional: true).
4. FORMAT:
   - Output ONLY a valid JSON object matching this schema (no markdown formatting):
{
  "gameTitle": "${gameTitle}",
  "hasLinearProgression": true,
  "progressionType": "chapters" | "acts" | "main_quests" | "bosses" | "worlds" | "none",
  "summary": "Kort svensk sammanfattning av spelets kapitelindelning baserat på guiden",
  "items": [
    {
      "id": "1",
      "title": "Exact Title From Guide",
      "order": 1,
      "chapterGroup": "Act or Area (if applicable)",
      "description": "Kort beskrivning",
      "isOptional": false
    }
  ]
}

--- GUIDE TEXT CONTENT ---
${guideSample}
--- END GUIDE TEXT CONTENT ---`;
  } else {
    useSearchTool = true;
    prompt = `Search Google for the guide at "${guideUrl}" or "${gameTitle} walkthrough" on that website.
Extract the official, chronological list of main story missions / chapters / areas for "${gameTitle}".

Target game: "${gameTitle}"
Guide source: ${guideUrl}
Desired granularity: ${granularity} (target ${targetCount} items).

STRICT EXTRACTION RULES:
1. USE OFFICIAL IN-GAME ENGLISH TITLES:
   - Do NOT translate quest titles to Swedish!
2. CHRONOLOGICAL ORDER:
   - List the items in story completion order.
3. EXCLUDE SIDE QUESTS & COLLECTIBLES:
   - Only include main story chapters/quests.
4. FORMAT:
   - Output ONLY a valid JSON object matching this schema (no markdown formatting):
{
  "gameTitle": "${gameTitle}",
  "hasLinearProgression": true,
  "progressionType": "chapters" | "acts" | "main_quests" | "bosses" | "worlds" | "none",
  "summary": "Kort svensk sammanfattning baserat på guiden",
  "items": [
    {
      "id": "1",
      "title": "Exact English Quest Title",
      "order": 1,
      "chapterGroup": "Act or Area",
      "description": "Kort info",
      "isOptional": false
    }
  ]
}`;
  }

  // Verifierade stabila modeller
  let candidateModels = [
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  try {
    const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`);
    if (listRes.ok) {
      const listData = await listRes.json();
      if (Array.isArray(listData.models)) {
        const available = listData.models
          .filter((m: any) => m.supportedGenerationMethods?.includes('generateContent'))
          .map((m: any) => m.name.replace(/^models\//, ''))
          .filter(
            (name: string) =>
              !name.includes('embedding') &&
              !name.includes('aqa') &&
              !name.includes('learnlm') &&
              !name.includes('imagen')
          );

        if (available.length > 0) {
          candidateModels = available.sort(
            (a: string, b: string) => getModelPriorityScore(b) - getModelPriorityScore(a)
          );
        }
      }
    }
  } catch (err) {
    console.warn('Could not query model list, using defaults:', err);
  }

  let lastError: Error | null = null;
  for (const modelName of candidateModels) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`;
      const bodyPayload: any = {
        contents: [{ parts: [{ text: prompt }] }],
      };

      if (useSearchTool) {
        bodyPayload.tools = [{ google_search: {} }];
      } else {
        bodyPayload.generationConfig = { temperature: 0.1 };
      }

      let response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: AbortSignal.timeout(24000),
        body: JSON.stringify(bodyPayload),
      });

      if (response.status === 404) continue;

      // Om sökintegration inte stöds på modellen, prova utan
      if (!response.ok && useSearchTool) {
        response = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          signal: AbortSignal.timeout(20000),
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: { temperature: 0.1 },
          }),
        });
      }

      if (!response.ok) {
        const errBody = await response.text();
        lastError = new Error(`Modell ${modelName} (${response.status}): ${errBody}`);
        continue;
      }

      const data = await response.json();
      const textContent = data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!textContent) continue;

      const result = parseGeminiOutput(textContent, gameTitle, granularity, modelName);
      result.source = 'scraped_guide';
      result.sourceUrl = guideUrl;
      return result;
    } catch (err: any) {
      lastError = err;
    }
  }

  throw lastError || new Error('Kunde inte generera kapitel från källguiden.');
}

