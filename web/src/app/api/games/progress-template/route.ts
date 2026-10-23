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
    summary: 'V:s resa i Night City uppdelad i samtliga 26 officiella huvuduppdrag (Main Jobs) från prolog till efterspel.',
    items: [
      { id: 'cp-1', title: 'The Rescue', order: 1, chapterGroup: 'Prolog' },
      { id: 'cp-2', title: 'The Ripperdoc', order: 2, chapterGroup: 'Akt 1' },
      { id: 'cp-3', title: 'The Ride', order: 3, chapterGroup: 'Akt 1' },
      { id: 'cp-4', title: 'The Information', order: 4, chapterGroup: 'Akt 1' },
      { id: 'cp-5', title: 'The Pickup', order: 5, chapterGroup: 'Akt 1' },
      { id: 'cp-6', title: 'The Heist', order: 6, chapterGroup: 'Akt 1' },
      { id: 'cp-7', title: 'Love Like Fire', order: 7, chapterGroup: 'Akt 1' },
      { id: 'cp-8', title: 'Playing for Time', order: 8, chapterGroup: 'Akt 2' },
      { id: 'cp-9', title: 'Automatic Love', order: 9, chapterGroup: 'Akt 2 (Evelyn)' },
      { id: 'cp-10', title: 'The Space in Between', order: 10, chapterGroup: 'Akt 2 (Evelyn)' },
      { id: 'cp-11', title: 'Disasterpiece', order: 11, chapterGroup: 'Akt 2 (Evelyn)' },
      { id: 'cp-12', title: 'Double Life', order: 12, chapterGroup: 'Akt 2 (Evelyn)' },
      { id: 'cp-13', title: "M'ap Tann Pèlen", order: 13, chapterGroup: 'Akt 2 (Voodoo Boys)' },
      { id: 'cp-14', title: 'I Walk the Line', order: 14, chapterGroup: 'Akt 2 (Voodoo Boys)' },
      { id: 'cp-15', title: 'Never Fade Away', order: 15, chapterGroup: 'Akt 2 (Voodoo Boys)' },
      { id: 'cp-16', title: 'Transmission', order: 16, chapterGroup: 'Akt 2 (Voodoo Boys)' },
      { id: 'cp-17', title: 'Ghost Town', order: 17, chapterGroup: 'Akt 2 (Panam)' },
      { id: 'cp-18', title: 'Lightning Breaks', order: 18, chapterGroup: 'Akt 2 (Panam)' },
      { id: 'cp-19', title: 'Life During Wartime', order: 19, chapterGroup: 'Akt 2 (Panam)' },
      { id: 'cp-20', title: 'Down on the Street', order: 20, chapterGroup: 'Akt 2 (Takemura)' },
      { id: 'cp-21', title: 'Gimme Danger', order: 21, chapterGroup: 'Akt 2 (Takemura)' },
      { id: 'cp-22', title: 'Play It Safe', order: 22, chapterGroup: 'Akt 2 (Takemura)' },
      { id: 'cp-23', title: 'Search and Destroy', order: 23, chapterGroup: 'Akt 2 (Takemura)' },
      { id: 'cp-24', title: 'Tapeworm', order: 24, chapterGroup: 'Akt 2 (Mellanakt)' },
      { id: 'cp-25', title: 'Nocturne Op55N1 (Point of No Return)', order: 25, chapterGroup: 'Akt 3' },
      { id: 'cp-26', title: 'Totalimmortal / All Along the Watchtower', order: 26, chapterGroup: 'Final' },
    ],
  },
  'the witcher 3: wild hunt': {
    gameTitle: 'The Witcher 3: Wild Hunt',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Geralts sökande efter Ciri, uppdelat i samtliga 41 officiella storyuppdrag från Vita pommern till slutstriden.',
    items: [
      { id: 'w3-1', title: 'Kaer Morhen (Tutorial)', order: 1, chapterGroup: 'Prolog' },
      { id: 'w3-2', title: 'Lilac and Gooseberries', order: 2, chapterGroup: 'Prolog' },
      { id: 'w3-3', title: 'The Beast of White Orchard', order: 3, chapterGroup: 'Prolog' },
      { id: 'w3-4', title: 'Incident at White Orchard', order: 4, chapterGroup: 'Prolog' },
      { id: 'w3-5', title: 'Imperial Audience', order: 5, chapterGroup: 'Prolog' },
      { id: 'w3-6', title: 'The Nilfgaardian Connection', order: 6, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-7', title: 'Bloody Baron', order: 7, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-8', title: "Ciri's Story: The King of the Wolves", order: 8, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-9', title: 'Family Matters', order: 9, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-10', title: 'A Princess in Distress', order: 10, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-11', title: "Ciri's Story: The Race", order: 11, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-12', title: 'Hunting a Witch', order: 12, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-13', title: 'Wandering in the Dark', order: 13, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-14', title: 'Ladies of the Wood', order: 14, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-15', title: "Ciri's Story: Fleeing the Bog", order: 15, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-16', title: 'Pyres of Novigrad', order: 16, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-17', title: 'Novigrad Dreaming', order: 17, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-18', title: 'Broken Flowers', order: 18, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-19', title: 'Get Junior', order: 19, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-20', title: "Ciri's Story: Visiting Junior", order: 20, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-21', title: "Count Reuven's Treasure", order: 21, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-22', title: "The Play's the Thing", order: 22, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-23', title: 'Destination: Skellige', order: 23, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-24', title: 'The King is Dead - Long Live the King', order: 24, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-25', title: 'Echoes of the Past', order: 25, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-26', title: 'Missing Persons', order: 26, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-27', title: 'Nameless', order: 27, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-28', title: 'The Calm Before the Storm', order: 28, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-29', title: 'Ugly Baby', order: 29, chapterGroup: 'Akt 2' },
      { id: 'w3-30', title: 'Disturbance', order: 30, chapterGroup: 'Akt 2' },
      { id: 'w3-31', title: 'To Bait a Forktail...', order: 31, chapterGroup: 'Akt 2' },
      { id: 'w3-32', title: 'The Final Trial', order: 32, chapterGroup: 'Akt 2' },
      { id: 'w3-33', title: 'Va Fail, Elaine', order: 33, chapterGroup: 'Akt 2' },
      { id: 'w3-34', title: 'Brothers in Arms (Kaer Morhen)', order: 34, chapterGroup: 'Akt 2' },
      { id: 'w3-35', title: 'The Isle of Mists', order: 35, chapterGroup: 'Akt 2' },
      { id: 'w3-36', title: 'The Battle of Kaer Morhen', order: 36, chapterGroup: 'Akt 2' },
      { id: 'w3-37', title: 'Blood on the Battlefield', order: 37, chapterGroup: 'Akt 2' },
      { id: 'w3-38', title: 'Bald Mountain', order: 38, chapterGroup: 'Akt 3' },
      { id: 'w3-39', title: 'Final Preparations', order: 39, chapterGroup: 'Akt 3' },
      { id: 'w3-40', title: 'The Sunstone', order: 40, chapterGroup: 'Akt 3' },
      { id: 'w3-41', title: 'On Thin Ice & Tedd Deireadh, The Final Age', order: 41, chapterGroup: 'Akt 3' },
    ],
  },
  'the witcher 3': {
    gameTitle: 'The Witcher 3: Wild Hunt',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Geralts sökande efter Ciri, uppdelat i samtliga 41 officiella storyuppdrag från Vita pommern till slutstriden.',
    items: [
      { id: 'w3-1', title: 'Kaer Morhen (Tutorial)', order: 1, chapterGroup: 'Prolog' },
      { id: 'w3-2', title: 'Lilac and Gooseberries', order: 2, chapterGroup: 'Prolog' },
      { id: 'w3-3', title: 'The Beast of White Orchard', order: 3, chapterGroup: 'Prolog' },
      { id: 'w3-4', title: 'Incident at White Orchard', order: 4, chapterGroup: 'Prolog' },
      { id: 'w3-5', title: 'Imperial Audience', order: 5, chapterGroup: 'Prolog' },
      { id: 'w3-6', title: 'The Nilfgaardian Connection', order: 6, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-7', title: 'Bloody Baron', order: 7, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-8', title: "Ciri's Story: The King of the Wolves", order: 8, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-9', title: 'Family Matters', order: 9, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-10', title: 'A Princess in Distress', order: 10, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-11', title: "Ciri's Story: The Race", order: 11, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-12', title: 'Hunting a Witch', order: 12, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-13', title: 'Wandering in the Dark', order: 13, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-14', title: 'Ladies of the Wood', order: 14, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-15', title: "Ciri's Story: Fleeing the Bog", order: 15, chapterGroup: 'Akt 1 (Velen)' },
      { id: 'w3-16', title: 'Pyres of Novigrad', order: 16, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-17', title: 'Novigrad Dreaming', order: 17, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-18', title: 'Broken Flowers', order: 18, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-19', title: 'Get Junior', order: 19, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-20', title: "Ciri's Story: Visiting Junior", order: 20, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-21', title: "Count Reuven's Treasure", order: 21, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-22', title: "The Play's the Thing", order: 22, chapterGroup: 'Akt 1 (Novigrad)' },
      { id: 'w3-23', title: 'Destination: Skellige', order: 23, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-24', title: 'The King is Dead - Long Live the King', order: 24, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-25', title: 'Echoes of the Past', order: 25, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-26', title: 'Missing Persons', order: 26, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-27', title: 'Nameless', order: 27, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-28', title: 'The Calm Before the Storm', order: 28, chapterGroup: 'Akt 1 (Skellige)' },
      { id: 'w3-29', title: 'Ugly Baby', order: 29, chapterGroup: 'Akt 2' },
      { id: 'w3-30', title: 'Disturbance', order: 30, chapterGroup: 'Akt 2' },
      { id: 'w3-31', title: 'To Bait a Forktail...', order: 31, chapterGroup: 'Akt 2' },
      { id: 'w3-32', title: 'The Final Trial', order: 32, chapterGroup: 'Akt 2' },
      { id: 'w3-33', title: 'Va Fail, Elaine', order: 33, chapterGroup: 'Akt 2' },
      { id: 'w3-34', title: 'Brothers in Arms (Kaer Morhen)', order: 34, chapterGroup: 'Akt 2' },
      { id: 'w3-35', title: 'The Isle of Mists', order: 35, chapterGroup: 'Akt 2' },
      { id: 'w3-36', title: 'The Battle of Kaer Morhen', order: 36, chapterGroup: 'Akt 2' },
      { id: 'w3-37', title: 'Blood on the Battlefield', order: 37, chapterGroup: 'Akt 2' },
      { id: 'w3-38', title: 'Bald Mountain', order: 38, chapterGroup: 'Akt 3' },
      { id: 'w3-39', title: 'Final Preparations', order: 39, chapterGroup: 'Akt 3' },
      { id: 'w3-40', title: 'The Sunstone', order: 40, chapterGroup: 'Akt 3' },
      { id: 'w3-41', title: 'On Thin Ice & Tedd Deireadh, The Final Age', order: 41, chapterGroup: 'Akt 3' },
    ],
  },
  'elden ring': {
    gameTitle: 'Elden Ring',
    hasLinearProgression: true,
    progressionType: 'bosses',
    summary: 'Framsteg i Lands Between mäts bäst genom de 14 nödvändiga och huvudsakliga storstorsbossarna från Margit till Elden Beast.',
    items: [
      { id: 'er-1', title: 'Margit, the Fell Omen', order: 1, chapterGroup: 'Stormveil Castle' },
      { id: 'er-2', title: 'Godrick the Grafted', order: 2, chapterGroup: 'Stormveil Castle' },
      { id: 'er-3', title: 'Red Wolf of Radagon', order: 3, chapterGroup: 'Raya Lucaria Academy' },
      { id: 'er-4', title: 'Rennala, Queen of the Full Moon', order: 4, chapterGroup: 'Raya Lucaria Academy' },
      { id: 'er-5', title: 'Starscourge Radahn', order: 5, chapterGroup: 'Redmane Castle (Caelid)' },
      { id: 'er-6', title: 'Draconic Tree Sentinel', order: 6, chapterGroup: 'Capital Outskirts' },
      { id: 'er-7', title: 'Godfrey, First Elden Lord (Golden Shade)', order: 7, chapterGroup: 'Leyndell, Royal Capital' },
      { id: 'er-8', title: 'Morgott, the Omen King', order: 8, chapterGroup: 'Leyndell, Royal Capital' },
      { id: 'er-9', title: 'Fire Giant', order: 9, chapterGroup: 'Mountaintops of the Giants' },
      { id: 'er-10', title: 'Godskin Duo', order: 10, chapterGroup: 'Crumbling Farum Azula' },
      { id: 'er-11', title: 'Maliketh, the Black Blade', order: 11, chapterGroup: 'Crumbling Farum Azula' },
      { id: 'er-12', title: 'Sir Gideon Ofnir, the All-Knowing', order: 12, chapterGroup: 'Leyndell, Ashen Capital' },
      { id: 'er-13', title: 'Godfrey, First Elden Lord / Hoarah Loux', order: 13, chapterGroup: 'Leyndell, Ashen Capital' },
      { id: 'er-14', title: 'Radagon of the Golden Order & Elden Beast', order: 14, chapterGroup: 'The Elden Throne' },
      { id: 'er-15', title: 'Rykard, Lord of Blasphemy', order: 15, chapterGroup: 'Volcano Manor', isOptional: true },
      { id: 'er-16', title: 'Malenia, Blade of Miquella', order: 16, chapterGroup: 'Miquella\'s Haligtree', isOptional: true },
    ],
  },
  'super mario odyssey': {
    gameTitle: 'Super Mario Odyssey',
    hasLinearProgression: true,
    progressionType: 'worlds',
    summary: 'Marios resa med luftskeppet Odyssey genom samtliga 17 riken från Cap Kingdom till Darker Side.',
    items: [
      { id: 'smo-1', title: 'Cap Kingdom (Bonneton)', order: 1, chapterGroup: 'Huvudstory' },
      { id: 'smo-2', title: 'Cascade Kingdom (Fossil Falls)', order: 2, chapterGroup: 'Huvudstory' },
      { id: 'smo-3', title: 'Sand Kingdom (Tostarena)', order: 3, chapterGroup: 'Huvudstory' },
      { id: 'smo-4', title: 'Lake Kingdom (Lake Lamode)', order: 4, chapterGroup: 'Huvudstory' },
      { id: 'smo-5', title: 'Wooded Kingdom (Steam Gardens)', order: 5, chapterGroup: 'Huvudstory' },
      { id: 'smo-6', title: 'Cloud Kingdom (Nimbus Arena)', order: 6, chapterGroup: 'Huvudstory' },
      { id: 'smo-7', title: 'Lost Kingdom (Forgotten Isle)', order: 7, chapterGroup: 'Huvudstory' },
      { id: 'smo-8', title: 'Metro Kingdom (New Donk City)', order: 8, chapterGroup: 'Huvudstory' },
      { id: 'smo-9', title: 'Snow Kingdom (Shiveria)', order: 9, chapterGroup: 'Huvudstory' },
      { id: 'smo-10', title: 'Seaside Kingdom (Bubblaine)', order: 10, chapterGroup: 'Huvudstory' },
      { id: 'smo-11', title: 'Luncheon Kingdom (Mount Volbono)', order: 11, chapterGroup: 'Huvudstory' },
      { id: 'smo-12', title: 'Ruined Kingdom (Crumbleden)', order: 12, chapterGroup: 'Huvudstory' },
      { id: 'smo-13', title: "Bowser's Kingdom (Bowser's Castle)", order: 13, chapterGroup: 'Huvudstory' },
      { id: 'smo-14', title: 'Moon Kingdom (Honeylune Ridge)', order: 14, chapterGroup: 'Huvudstory' },
      { id: 'smo-15', title: "Mushroom Kingdom (Peach's Castle)", order: 15, chapterGroup: 'Efterspel (Post-game)', isOptional: true },
      { id: 'smo-16', title: 'Dark Side (Rabbit Ridge)', order: 16, chapterGroup: 'Bonusutmaning', isOptional: true },
      { id: 'smo-17', title: 'Darker Side (Culmina Crater)', order: 17, chapterGroup: 'Slututmaning', isOptional: true },
    ],
  },
  'resident evil 2': {
    gameTitle: 'Resident Evil 2 (Remake)',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Leon Kennedy och Claire Redfields överlevnadskamp genom R.P.D., kloakerna och Umbrella NEST-laboratoriet.',
    items: [
      { id: 're2-1', title: 'Gas Station & Arrival in Raccoon City', order: 1, chapterGroup: 'Prolog' },
      { id: 're2-2', title: 'R.P.D. Main Hall & East Wing', order: 2, chapterGroup: 'Polisstationen' },
      { id: 're2-3', title: 'R.P.D. West Wing & Dark Room', order: 3, chapterGroup: 'Polisstationen' },
      { id: 're2-4', title: 'Three Medallions & Secret Passage', order: 4, chapterGroup: 'Polisstationen' },
      { id: 're2-5', title: 'Underground Facility: First G Encounter (G-1)', order: 5, chapterGroup: 'Underjorden' },
      { id: 're2-6', title: 'Parking Garage & Police Station Basement', order: 6, chapterGroup: 'Polisstationen' },
      { id: 're2-7', title: "Mr. X Emerges & Chief's Office / Clock Tower", order: 7, chapterGroup: 'Polisstationen' },
      { id: 're2-8', title: 'The Sewers: Finding the Chess Plugs', order: 8, chapterGroup: 'Kloakerna' },
      { id: 're2-9', title: 'Sewer Treatment Plant: Second G Encounter (G-2)', order: 9, chapterGroup: 'Kloakerna' },
      { id: 're2-10', title: 'Umbrella NEST: Greenhouse & Plant 43 Dispersal', order: 10, chapterGroup: 'Laboratoriet (NEST)' },
      { id: 're2-11', title: 'Umbrella NEST: West Area & Third G Encounter (G-3)', order: 11, chapterGroup: 'Laboratoriet (NEST)' },
      { id: 're2-12', title: 'Self-Destruct Sequence, Super Tyrant / G-4 & Escape Train', order: 12, chapterGroup: 'Final' },
    ],
  },
  'resident evil 4': {
    gameTitle: 'Resident Evil 4 (Remake)',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Leons uppdrag att rädda Ashley Graham genom samtliga 16 officiella kapitel från byn till ön.',
    items: [
      { id: 're4-1', title: 'Chapter 1: The Village & Hunter\'s Lodge', order: 1, chapterGroup: 'Byn' },
      { id: 're4-2', title: 'Chapter 2: The Abandoned Factory & Valley', order: 2, chapterGroup: 'Byn' },
      { id: 're4-3', title: 'Chapter 3: The Lakeside & Del Lago', order: 3, chapterGroup: 'Byn' },
      { id: 're4-4', title: 'Chapter 4: Lake Exploration, Church & El Gigante', order: 4, chapterGroup: 'Byn' },
      { id: 're4-5', title: 'Chapter 5: Church Rescue & Villa Defense', order: 5, chapterGroup: 'Byn' },
      { id: 're4-6', title: 'Chapter 6: Checkpoint, Slaughterhouse & Bitores Méndez', order: 6, chapterGroup: 'Byn' },
      { id: 're4-7', title: 'Chapter 7: Castle Gates, Dungeons & Garrador', order: 7, chapterGroup: 'Slottet' },
      { id: 're4-8', title: 'Chapter 8: Castle Battlements & Water Hall', order: 8, chapterGroup: 'Slottet' },
      { id: 're4-9', title: 'Chapter 9: Courtyard Maze, Grand Hall & Armored Knights', order: 9, chapterGroup: 'Slottet' },
      { id: 're4-10', title: 'Chapter 10: Depths, Antechamber & Verdugo', order: 10, chapterGroup: 'Slottet' },
      { id: 're4-11', title: 'Chapter 11: The Mines, Minecart Ride & Krauser First Duel', order: 11, chapterGroup: 'Slottet' },
      { id: 're4-12', title: 'Chapter 12: Clock Tower & Ramón Salazar', order: 12, chapterGroup: 'Slottet' },
      { id: 're4-13', title: 'Chapter 13: Island Wharf, Lab & Regeneradors', order: 13, chapterGroup: 'Ön' },
      { id: 're4-14', title: 'Chapter 14: Cargo Depot, Holding Cell & Jack Krauser Duel', order: 14, chapterGroup: 'Ön' },
      { id: 're4-15', title: 'Chapter 15: Stronghold, Cliffside & Sanctuary', order: 15, chapterGroup: 'Ön' },
      { id: 're4-16', title: 'Chapter 16: Osmund Saddler, Jet Ski Escape & Ending', order: 16, chapterGroup: 'Ön' },
    ],
  },
  'baldur\'s gate 3': {
    gameTitle: 'Baldur\'s Gate 3',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Den storslagna kampanjen uppdelad i samtliga 20 centrala vändpunkter och storymilstolpar genom akterna.',
    items: [
      { id: 'bg3-1', title: 'Prologue: Escape the Nautiloid', order: 1, chapterGroup: 'Prolog' },
      { id: 'bg3-2', title: 'Chapter 1: Ravaged Beach & Crash Site', order: 2, chapterGroup: 'Akt 1' },
      { id: 'bg3-3', title: 'Chapter 2: The Hollow & Emerald Grove', order: 3, chapterGroup: 'Akt 1' },
      { id: 'bg3-4', title: 'Chapter 3: Defeat the Goblin Leaders (or Raid the Grove)', order: 4, chapterGroup: 'Akt 1' },
      { id: 'bg3-5', title: 'Chapter 4: Rescue the Druid Halsin', order: 5, chapterGroup: 'Akt 1' },
      { id: 'bg3-6', title: 'Chapter 5: Journey to the Underdark', order: 6, chapterGroup: 'Akt 1' },
      { id: 'bg3-7', title: 'Chapter 6: The Grymforge & Ancient Adamantine Forge', order: 7, chapterGroup: 'Akt 1' },
      { id: 'bg3-8', title: 'Chapter 7: Mountain Pass & Rosymorn Monastery', order: 8, chapterGroup: 'Akt 1' },
      { id: 'bg3-9', title: 'Chapter 8: Infiltrate the Githyanki Crèche', order: 9, chapterGroup: 'Akt 1' },
      { id: 'bg3-10', title: 'Chapter 9: Shadow-Cursed Lands & Last Light Inn', order: 10, chapterGroup: 'Akt 2' },
      { id: 'bg3-11', title: 'Chapter 10: Infiltrate Moonrise Towers', order: 11, chapterGroup: 'Akt 2' },
      { id: 'bg3-12', title: 'Chapter 11: The Gauntlet of Shar & Find the Nightsong', order: 12, chapterGroup: 'Akt 2' },
      { id: 'bg3-13', title: 'Chapter 12: Assault on Moonrise Towers', order: 13, chapterGroup: 'Akt 2' },
      { id: 'bg3-14', title: 'Chapter 13: Defeat Ketheric Thorm & Apostle of Myrkul', order: 14, chapterGroup: 'Akt 2' },
      { id: 'bg3-15', title: 'Chapter 14: Rivington & Wyrm\'s Crossing', order: 15, chapterGroup: 'Akt 3' },
      { id: 'bg3-16', title: 'Chapter 15: The Lower City of Baldur\'s Gate', order: 16, chapterGroup: 'Akt 3' },
      { id: 'bg3-17', title: 'Chapter 16: Deal with the Devil (House of Hope)', order: 17, chapterGroup: 'Akt 3 (Frivilligt)', isOptional: true },
      { id: 'bg3-18', title: 'Chapter 17: Confront Lord Enver Gortash', order: 18, chapterGroup: 'Akt 3' },
      { id: 'bg3-19', title: 'Chapter 18: Temple of Bhaal & Defeat Orin the Red', order: 19, chapterGroup: 'Akt 3' },
      { id: 'bg3-20', title: 'Chapter 19: The Netherbrain & Final Confrontation', order: 20, chapterGroup: 'Final' },
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

  const prompt = `Task: Provide the official main story chapter and quest progression list for the game "${gameTitle}" based on IGN walkthroughs and guides.
Desired granularity: ${granularity} (target ${targetCount} items).

Rules:
1. Chronological main story order. Exclude minor side quests.
2. Keep official ENGLISH titles for all items (e.g. "R.P.D. - Central Hall", "The Sewers", "NEST Laboratory"). Do not translate quest titles to Swedish!
3. Output valid JSON matching this schema:
{
  "gameTitle": "${gameTitle}",
  "hasLinearProgression": true,
  "progressionType": "chapters" | "acts" | "main_quests" | "bosses" | "worlds" | "none",
  "summary": "Kort svensk sammanfattning baserad på IGN:s guide",
  "items": [
    {
      "id": "1",
      "title": "Exact English Quest / Chapter Title",
      "order": 1,
      "chapterGroup": "Area or Act",
      "description": "Kort info",
      "isOptional": false
    }
  ]
}`;

  // 1. Verifiera först API-nyckeln och hämta de aktiva modellerna från Google
  let candidateModels = [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
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

        const getVer = (name: string): number => {
          const match = name.match(/gemini[^\d]*(\d+(?:\.\d+)?)/i);
          return match ? parseFloat(match[1]) : 0;
        };

        const flashModels = supported
          .filter((m: string) => m.includes('flash'))
          .sort((a: string, b: string) => getVer(b) - getVer(a));

        const otherModels = supported
          .filter((m: string) => !m.includes('flash'))
          .sort((a: string, b: string) => getVer(b) - getVer(a));

        const ordered = [...flashModels, ...otherModels];
        const unique = Array.from(new Set(ordered));
        if (unique.length > 0) {
          // Välj primär Flash-modell (t.ex. gemini-3.8-flash)
          candidateModels = unique.slice(0, 1);
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

      // Försök först med thinkingBudget: 0 (stänger av tankeläge på Gemini 3.x Flash så att den svarar omedelbart)
      let response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: AbortSignal.timeout(24000),
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.1,
            responseMimeType: 'application/json',
            maxOutputTokens: 2048,
            thinkingConfig: {
              thinkingBudget: 0,
            },
          },
        }),
      });

      // Om modellen inte känner till thinkingConfig (400), anropa utan
      if (!response.ok && response.status === 400) {
        response = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          signal: AbortSignal.timeout(24000),
          body: JSON.stringify({
            contents: [{ parts: [{ text: prompt }] }],
            generationConfig: {
              temperature: 0.1,
              responseMimeType: 'application/json',
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

