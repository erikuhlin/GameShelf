import { NextRequest, NextResponse } from 'next/server';

export type ProgressionType = 'chapters' | 'acts' | 'main_quests' | 'bosses' | 'worlds' | 'none';

export interface ProgressTemplateItem {
  id: string;
  title: string;
  order: number;
  description?: string;
  isOptional?: boolean;
}

export interface GameProgressTemplate {
  gameTitle: string;
  igdbId?: number;
  hasLinearProgression: boolean;
  progressionType: ProgressionType;
  items: ProgressTemplateItem[];
  source: 'curated' | 'ai' | 'custom';
  summary?: string;
}

// Förberedda kurerade mallar för ett antal kända spel
const CURATED_TEMPLATES: Record<string, Omit<GameProgressTemplate, 'source'>> = {
  'the last of us part i': {
    gameTitle: 'The Last of Us Part I',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Joel och Ellies resa genom USA, uppdelad i 12 kapitel och 4 årstider.',
    items: [
      { id: 'tlou-0', title: 'Prolog (Austin, Texas)', order: 1 },
      { id: 'tlou-1', title: 'Kapitel 1: Karantänzonen (Boston)', order: 2 },
      { id: 'tlou-2', title: 'Kapitel 2: Utkanten', order: 3 },
      { id: 'tlou-3', title: 'Kapitel 3: Bills stad', order: 4 },
      { id: 'tlou-4', title: 'Kapitel 4: Pittsburgh', order: 5 },
      { id: 'tlou-5', title: 'Kapitel 5: Förorten', order: 6 },
      { id: 'tlou-6', title: 'Kapitel 6: Tommys damm (Jackson)', order: 7 },
      { id: 'tlou-7', title: 'Kapitel 7: Universitetet (Eastern Colorado)', order: 8 },
      { id: 'tlou-8', title: 'Kapitel 8: Stugbyn vid sjön (Vinter)', order: 9 },
      { id: 'tlou-9', title: 'Kapitel 9: Bussterminalen (Salt Lake City)', order: 10 },
      { id: 'tlou-10', title: 'Kapitel 10: Eldflugornas laboratorium', order: 11 },
      { id: 'tlou-11', title: 'Epilog (Jackson)', order: 12 },
    ],
  },
  'the last of us': {
    gameTitle: 'The Last of Us',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Joel och Ellies resa genom USA, uppdelad i 12 kapitel och 4 årstider.',
    items: [
      { id: 'tlou-0', title: 'Prolog (Austin, Texas)', order: 1 },
      { id: 'tlou-1', title: 'Kapitel 1: Karantänzonen (Boston)', order: 2 },
      { id: 'tlou-2', title: 'Kapitel 2: Utkanten', order: 3 },
      { id: 'tlou-3', title: 'Kapitel 3: Bills stad', order: 4 },
      { id: 'tlou-4', title: 'Kapitel 4: Pittsburgh', order: 5 },
      { id: 'tlou-5', title: 'Kapitel 5: Förorten', order: 6 },
      { id: 'tlou-6', title: 'Kapitel 6: Tommys damm (Jackson)', order: 7 },
      { id: 'tlou-7', title: 'Kapitel 7: Universitetet (Eastern Colorado)', order: 8 },
      { id: 'tlou-8', title: 'Kapitel 8: Stugbyn vid sjön (Vinter)', order: 9 },
      { id: 'tlou-9', title: 'Kapitel 9: Bussterminalen (Salt Lake City)', order: 10 },
      { id: 'tlou-10', title: 'Kapitel 10: Eldflugornas laboratorium', order: 11 },
      { id: 'tlou-11', title: 'Epilog (Jackson)', order: 12 },
    ],
  },
  'cyberpunk 2077': {
    gameTitle: 'Cyberpunk 2077',
    hasLinearProgression: true,
    progressionType: 'acts',
    summary: 'V:s berättelse i Night City uppdelad i prolog, tre huvudakter och epilog.',
    items: [
      { id: 'cp-0', title: 'Prolog: Livsstil & Räddningsuppdraget', order: 1 },
      { id: 'cp-1', title: 'Akt 1: Kupen på Konpeki Plaza', order: 2 },
      { id: 'cp-2', title: 'Akt 2: Huvudspår 1 – Panam & Nomads (Ghost Town)', order: 3 },
      { id: 'cp-3', title: 'Akt 2: Huvudspår 2 – Judy & Evelyn (Automatic Love)', order: 4 },
      { id: 'cp-4', title: 'Akt 2: Huvudspår 3 – Takemura & Arasaka (Down on the Street)', order: 5 },
      { id: 'cp-5', title: 'Akt 2: Samlingspunkt vid parade (Play It Safe & Search and Destroy)', order: 6 },
      { id: 'cp-6', title: 'Akt 3: Nocturne Op55N1 (Point of No Return)', order: 7 },
      { id: 'cp-7', title: 'Epilog: Slutuppdrag & Efterspel', order: 8 },
    ],
  },
  'the witcher 3: wild hunt': {
    gameTitle: 'The Witcher 3: Wild Hunt',
    hasLinearProgression: true,
    progressionType: 'acts',
    summary: 'Geralts sökande efter Ciri, uppdelat i prolog och tre storslagna akter.',
    items: [
      { id: 'w3-0', title: 'Prolog: Vita pommern (White Orchard)', order: 1 },
      { id: 'w3-1', title: 'Akt 1: Jakten i Velen (Blodige Baronen & Häxorna)', order: 2 },
      { id: 'w3-2', title: 'Akt 1: Jakten i Novigrad (Dandelion & Triss)', order: 3 },
      { id: 'w3-3', title: 'Akt 1: Jakten på Skellige (Yennefer & Masken)', order: 4 },
      { id: 'w3-4', title: 'Akt 2: Uma & Kaer Morhen (Ugly Baby)', order: 5 },
      { id: 'w3-5', title: 'Akt 2: Dimöarna & Slaget om Kaer Morhen', order: 6 },
      { id: 'w3-6', title: 'Akt 3: Slutförberedelser i Novigrad', order: 7 },
      { id: 'w3-7', title: 'Akt 3: Slutstriden (Tedd Deireadh)', order: 8 },
    ],
  },
  'elden ring': {
    gameTitle: 'Elden Ring',
    hasLinearProgression: true,
    progressionType: 'bosses',
    summary: 'Framsteg i Lands Between mäts bäst genom de nödvändiga och huvudsakliga bossarna.',
    items: [
      { id: 'er-1', title: 'Margit, the Fell Omen (Stormveil)', order: 1 },
      { id: 'er-2', title: 'Godrick the Grafted (Stormveil)', order: 2 },
      { id: 'er-3', title: 'Rennala, Queen of the Full Moon (Raya Lucaria)', order: 3 },
      { id: 'er-4', title: 'Starscourge Radahn (Redmane Castle)', order: 4 },
      { id: 'er-5', title: 'Rykard, Lord of Blasphemy (Volcano Manor)', order: 5, isOptional: true },
      { id: 'er-6', title: 'Morgott, the Omen King (Leyndell)', order: 6 },
      { id: 'er-7', title: 'Fire Giant (Mountaintops of the Giants)', order: 7 },
      { id: 'er-8', title: 'Godskin Duo (Crumbling Farum Azula)', order: 8 },
      { id: 'er-9', title: 'Maliketh, the Black Blade (Farum Azula)', order: 9 },
      { id: 'er-10', title: 'Sir Gideon Ofnir & Godfrey / Hoarah Loux', order: 10 },
      { id: 'er-11', title: 'Radagon of the Golden Order & Elden Beast', order: 11 },
    ],
  },
  'super mario odyssey': {
    gameTitle: 'Super Mario Odyssey',
    hasLinearProgression: true,
    progressionType: 'worlds',
    summary: 'Marios resa genom rikena med luftskeppet Odyssey för att rädda Peach.',
    items: [
      { id: 'smo-1', title: 'Cap Kingdom (Bonneton)', order: 1 },
      { id: 'smo-2', title: 'Cascade Kingdom (Fossil Falls)', order: 2 },
      { id: 'smo-3', title: 'Sand Kingdom (Tostarena)', order: 3 },
      { id: 'smo-4', title: 'Lake Kingdom & Wooded Kingdom', order: 4 },
      { id: 'smo-5', title: 'Cloud Kingdom & Lost Kingdom', order: 5 },
      { id: 'smo-6', title: 'Metro Kingdom (New Donk City)', order: 6 },
      { id: 'smo-7', title: 'Snow Kingdom & Seaside Kingdom', order: 7 },
      { id: 'smo-8', title: 'Luncheon Kingdom (Mount Volbono)', order: 8 },
      { id: 'smo-9', title: 'Ruined Kingdom & Bowser\'s Kingdom', order: 9 },
      { id: 'smo-10', title: 'Moon Kingdom & Slutstriden mot Bowser', order: 10 },
      { id: 'smo-11', title: 'Mushroom Kingdom (Post-game)', order: 11, isOptional: true },
    ],
  },
  'resident evil 4': {
    gameTitle: 'Resident Evil 4',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Leons uppdrag att rädda presidentens dotter, uppdelat i byn, slottet och ön.',
    items: [
      { id: 're4-1', title: 'Kapitel 1–2: Byn och kyrkan', order: 1 },
      { id: 're4-2', title: 'Kapitel 3–4: Sjön och Mendez bossfajt', order: 2 },
      { id: 're4-3', title: 'Kapitel 5–6: Flykten från byn till slottet', order: 3 },
      { id: 're4-4', title: 'Kapitel 7–8: Slottets portar och vattenhallen', order: 4 },
      { id: 're4-5', title: 'Kapitel 9–10: Labyrinten, balsalen och Novistadors', order: 5 },
      { id: 're4-6', title: 'Kapitel 11–12: Gruvorna och Salazar bossfajt', order: 6 },
      { id: 're4-7', title: 'Kapitel 13–14: Ön, Regeneradors och Krauser', order: 7 },
      { id: 're4-8', title: 'Kapitel 15–16: Helikopterstödet och Saddler', order: 8 },
    ],
  },
  'baldur\'s gate 3': {
    gameTitle: 'Baldur\'s Gate 3',
    hasLinearProgression: true,
    progressionType: 'acts',
    summary: 'Den storslagna kampanjen uppdelad i tre massiva akter.',
    items: [
      { id: 'bg3-0', title: 'Prolog: Nautiloid-flykten', order: 1 },
      { id: 'bg3-1', title: 'Akt 1: Vildmarken, Druid Grove & Goblin Camp', order: 2 },
      { id: 'bg3-2', title: 'Akt 1: Underdark, Grymforge & Mountain Pass', order: 3 },
      { id: 'bg3-3', title: 'Akt 2: Shadow-Cursed Lands & Last Light Inn', order: 4 },
      { id: 'bg3-4', title: 'Akt 2: Gauntlet of Shar & Moonrise Towers', order: 5 },
      { id: 'bg3-5', title: 'Akt 3: Rivington & Nedre staden (Baldur\'s Gate)', order: 6 },
      { id: 'bg3-6', title: 'Akt 3: De Tre utvalda (Gortash & Orin)', order: 7 },
      { id: 'bg3-7', title: 'Akt 3: Slutstriden mot Netherbrain', order: 8 },
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

    if (!gameTitle) {
      return NextResponse.json({ error: 'gameTitle krävs' }, { status: 400 });
    }

    const lower = gameTitle.toLowerCase();

    // 1. Kolla kurerade mallar
    for (const [key, template] of Object.entries(CURATED_TEMPLATES)) {
      if (lower.includes(key) || key.includes(lower)) {
        return NextResponse.json({
          ...template,
          source: 'curated',
        } as GameProgressTemplate);
      }
    }

    // 2. Om ingen kurerad mall matchar och Gemini-nyckel finns -> Anropa Gemini
    if (geminiKey) {
      try {
        const aiTemplate = await fetchWithGemini(gameTitle, geminiKey);
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

async function fetchWithGemini(gameTitle: string, apiKey: string): Promise<GameProgressTemplate> {
  const prompt = `Du är en expert på TV-spel. Analysera spelet "${gameTitle}" och skapa en logisk, ren och spoiler-sanerad lista över spelets huvudsakliga progression för en spelspårningsapp.

Följ dessa regler noggrant:
1. Om spelet saknar en linjär enspelarkampanj/story (t.ex. rena multiplayer-, sport- eller partyspel som FIFA, Rocket League, Tetris), sätt "hasLinearProgression": false, "progressionType": "none" och en tom array för "items".
2. Om spelet HAR en linjär story eller kampanj, identifiera progressionstypen:
   - "chapters" (om spelet är indelat i kapitel, t.ex. The Last of Us, Resident Evil)
   - "acts" (om spelet är indelat i akter/stora huvuduppdrag, t.ex. Cyberpunk 2077, Witcher 3)
   - "bosses" (om progressionen bäst mäts genom huvudbossar, t.ex. Souls-spel, Cuphead)
   - "worlds" (om spelet är indelat i världar/zoner, t.ex. Mario, Crash)
3. Ta ENDAST med HUVUDHANDLINGEN (Main story/critical path). Ta INTE med 100 sidouppdrag eller samlarföremål. Håll listan mellan 5 och 20 punkter.
4. UNDVIK DIREKTA SPOILERS i titlarna (skriv t.ex. "Kapitel 7: Universitetet" istället för "Kapitel 7: Karaktär X dör").
5. Skriv på svenska där det är naturligt, men behåll etablerade engelska namn på världar eller kapitel om det är standarden.

Svara med ett giltigt JSON-objekt med exakt detta format:
{
  "gameTitle": "${gameTitle}",
  "hasLinearProgression": true,
  "progressionType": "chapters" | "acts" | "main_quests" | "bosses" | "worlds" | "none",
  "summary": "Kort beskrivning (max 2 meningar) av hur spelet är uppbyggt",
  "items": [
    {
      "id": "1",
      "title": "Kapitel 1: Namn",
      "order": 1,
      "description": "Kort valfri förklaring",
      "isOptional": false
    }
  ]
}`;

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: {
          response_mime_type: 'application/json',
          temperature: 0.2,
        },
      }),
    }
  );

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Gemini API-anrop misslyckades (${response.status}): ${errorText}`);
  }

  const data = await response.json();
  const textContent = data.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!textContent) {
    throw new Error('Inget text-svar från Gemini');
  }

  const parsed = JSON.parse(textContent);

  return {
    gameTitle: parsed.gameTitle || gameTitle,
    hasLinearProgression: Boolean(parsed.hasLinearProgression),
    progressionType: parsed.progressionType || 'chapters',
    summary: parsed.summary || '',
    items: Array.isArray(parsed.items)
      ? parsed.items.map((item: any, idx: number) => ({
          id: String(item.id || idx + 1),
          title: String(item.title || `Delmål ${idx + 1}`),
          order: Number(item.order || idx + 1),
          description: item.description,
          isOptional: Boolean(item.isOptional),
        }))
      : [],
    source: 'ai',
  };
}
