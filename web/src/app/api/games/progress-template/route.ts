import { NextRequest, NextResponse } from 'next/server';

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

export interface GameProgressTemplate {
  gameTitle: string;
  igdbId?: number;
  hasLinearProgression: boolean;
  progressionType: ProgressionType;
  granularity?: Granularity;
  items: ProgressTemplateItem[];
  source: 'curated' | 'ai' | 'custom';
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
  'rocket league': {
    gameTitle: 'Rocket League',
    hasLinearProgression: false,
    progressionType: 'none',
    summary: 'Ett flerspelar- och tävlingsspel utan linjär berättelse eller kapitel.',
    items: [],
  },
};

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const gameTitle: string = (body.gameTitle || '').trim();
    const geminiKey: string = (body.geminiApiKey || process.env.GEMINI_API_KEY || '').trim();
    const granularity: Granularity = body.granularity || 'standard';
    const forceAI: boolean = Boolean(body.forceAI);

    if (!gameTitle) {
      return NextResponse.json({ error: 'gameTitle krävs' }, { status: 400 });
    }

    const lower = gameTitle.toLowerCase();

    // 1. Kolla kurerade mallar (om inte forceAI är aktiverat)
    if (!forceAI) {
      for (const [key, template] of Object.entries(CURATED_TEMPLATES)) {
        if (lower.includes(key) || key.includes(lower)) {
          return NextResponse.json({
            ...template,
            granularity: 'standard',
            source: 'curated',
          } as GameProgressTemplate);
        }
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
  const targetCount =
    granularity === 'compact'
      ? 'ca 8 till 12'
      : granularity === 'detailed'
      ? 'ca 20 till 30'
      : 'ca 14 till 22';

  const prompt = `Du är en expert på TV-spel och spelguider. Analysera spelet "${gameTitle}" och skapa en logisk, ren och kronologisk lista över spelets huvudsakliga progression (Main Story / Critical Path) för en spelspårningsapp.
Önskad detaljnivå: ${granularity} (sikta på ${targetCount} delmål).

Följ dessa strikta regler:
1. RENODLADE MULTIPLAYER- ELLER SPORT-SPEL:
   - Om spelet är ett renodlat multiplayer-, sport-, racing- eller partyspel helt utan en linjär storykampanj (t.ex. FIFA, Rocket League, Tetris), sätt:
     "hasLinearProgression": false, "progressionType": "none", "summary": "Detta spel saknar en linjär enspelarkampanj eller fast kapitelordning.", "items": []
   - Om spelet DÄREMOT ÄR ett storyspel, äventyrsspel, actionspel eller RPG (oavsett om det är en klassiker eller nysläppt, inklusive 007 First Light eller nyare titlar): analysera och lista huvuduppdragen eller kapitlen kronologiskt!

2. OFFICIELLA ENGELSKA TITLAR:
   - Använd ALLTID de officiella, exakta ENGELSKA namnen från spelets interna Quest Log / Journal / Chapter Selection (t.ex. "Escape the Nautiloid", "Rescue the Druid Halsin", eller för Kingdom Come: "Unexpected Visitors", "Run!", "Homecoming", "Awakening", "Baptism of Fire").
   - Översätt ALDRIG officiella quest- eller kapitelnamn till svenska! Spelaren vill kunna titta i sin quest log i spelet och känna igen exakt samma namn.

3. INGA HOPPSLAGNA UPPDRAG (ENDAST EN QUEST PER PUNKT):
   - Slå ALDRIG ihop flera uppdrag i samma punkt (skriv t.ex. INTE "Druid Grove & Goblin Camp", utan lista de enskilda uppdragen separat: t.ex. "Save the Refugees", "Rescue the Druid Halsin", "Defeat the Goblin Leaders").

4. FÖR RPG-SPEL (t.ex. Kingdom Come: Deliverance, Baldur's Gate 3, Cyberpunk 2077, The Witcher 3):
   - Progressionen ska bestå av de faktiska HUVUDUPPDRAGEN (Main Quests). Sätt "progressionType": "main_quests".
   - Sätt "chapterGroup" till den övergripande akten eller regionen (t.ex. "Prologue", "Act 1", "Act 2", "Act 3" eller "Skalitz", "Rattay", "Sasau").

5. FÖR KAPITEL- OCH SURVIVAL HORROR-SPEL (t.ex. Silent Hill, Resident Evil, The Last of Us, 007 First Light):
   - Lista de faktiska kapitlen, uppdragen eller distinkta områdena i kronologisk ordning. Sätt "chapterGroup" till regionen/byggnaden/uppdraget.

6. UNDVIK SPOILERS:
   - Skriv rena titlar. Avslöja inte plot-twists i sammanfattningen eller namnen.

Svara med ett giltigt JSON-objekt med exakt detta format (bara ren JSON, inga markdown-block):
{
  "gameTitle": "${gameTitle}",
  "hasLinearProgression": true,
  "progressionType": "chapters" | "acts" | "main_quests" | "bosses" | "worlds" | "none",
  "summary": "Kort beskrivning (max 2 meningar) av hur spelet och dess uppdrag är uppbyggt",
  "items": [
    {
      "id": "1",
      "title": "Exact English Quest Title",
      "order": 1,
      "chapterGroup": "Act 1 / Area Name",
      "description": "Kort valfri förklaring",
      "isOptional": false
    }
  ]
}`;

  // 1. Välj en snabb och modern modell direkt
  let candidateModels = ['gemini-2.0-flash', 'gemini-1.5-flash-latest', 'gemini-1.5-flash'];

  try {
    const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`);
    if (listRes.ok) {
      const listData = await listRes.json();
      if (Array.isArray(listData.models)) {
        const available = listData.models
          .filter((m: any) => m.supportedGenerationMethods?.includes('generateContent'))
          .map((m: any) => m.name.replace(/^models\//, ''));

        const topFlash = available.find((name: string) => name.includes('2.0-flash')) ||
                         available.find((name: string) => name.includes('1.5-flash')) ||
                         available[0];

        if (topFlash) {
          candidateModels = [topFlash, 'gemini-1.5-flash-latest'];
        }
      }
    }
  } catch (err) {
    console.warn('Could not query model list, using defaults:', err);
  }

  // 2. Kör max 2 snabba försök
  let lastError: Error | null = null;

  for (const modelName of Array.from(new Set(candidateModels)).slice(0, 2)) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${apiKey}`;
      
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.1,
          },
        }),
      });

      if (!response.ok) {
        const errBody = await response.text();
        lastError = new Error(`Modell ${modelName} (${response.status}): ${errBody}`);
        continue;
      }

      const data = await response.json();
      const textContent = data.candidates?.[0]?.content?.parts?.[0]?.text;
      if (!textContent) {
        continue;
      }

      return parseGeminiOutput(textContent, gameTitle, granularity);
    } catch (err: any) {
      lastError = err;
    }
  }

  throw lastError || new Error('Ingen tillgänglig Gemini-modell hittades för din API-nyckel.');
}

function parseGeminiOutput(
  rawText: string,
  gameTitle: string,
  granularity: Granularity
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
  };
}
