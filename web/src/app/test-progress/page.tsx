'use client';

import React, { useState, useEffect, useMemo } from 'react';
import Link from 'next/link';
import {
  CheckCircle2,
  Circle,
  Eye,
  EyeOff,
  Sparkles,
  Plus,
  Trash2,
  Clock,
  Shield,
  ListChecks,
  Key,
  ChevronRight,
  ChevronUp,
  ChevronDown,
  RotateCcw,
  BookOpen,
  Gamepad2,
  Layers,
  Skull,
  Globe,
  AlertCircle,
  Check,
  ExternalLink,
  Pencil,
  FileText,
  CheckCheck,
  Settings2,
} from 'lucide-react';

export type Granularity = 'compact' | 'standard' | 'detailed';

interface TemplateItem {
  id: string;
  title: string;
  order: number;
  chapterGroup?: string;
  description?: string;
  isOptional?: boolean;
}

interface LoadedTemplate {
  gameTitle: string;
  hasLinearProgression: boolean;
  progressionType: 'chapters' | 'acts' | 'main_quests' | 'bosses' | 'worlds' | 'none';
  granularity?: Granularity;
  summary?: string;
  items: TemplateItem[];
  modelUsed?: string;
  source: 'curated' | 'ai' | 'custom' | 'scraped_guide';
  sourceUrl?: string;
}

interface ActiveTodo {
  id: string;
  title: string;
  isDone: boolean;
  order: number;
  chapterGroup?: string;
  isOptional?: boolean;
}

interface LibraryGame {
  id: string;
  name: string;
  displayName: string;
  genre: string;
  platform: string;
  hltb: number;
  hasPreloadedTemplate: boolean;
  icon: any;
  samplePasteText?: string;
}

const LIBRARY_GAMES: LibraryGame[] = [
  // --- SPEL MED FÄRDIG, DUBBELKOLLAD 1:1-MALL I DATABASEN ---
  {
    id: 'kcd-2',
    name: 'Kingdom Come: Deliverance II',
    displayName: 'Kingdom Come II',
    genre: 'Medeltida RPG (32 quests)',
    platform: 'PS5 / PC',
    hltb: 50,
    hasPreloadedTemplate: true,
    icon: Layers,
  },
  {
    id: 'stalker-2',
    name: 'S.T.A.L.K.E.R. 2: Heart of Chornobyl',
    displayName: 'S.T.A.L.K.E.R. 2',
    genre: 'Survival FPS (35 quests)',
    platform: 'PC / Xbox',
    hltb: 35,
    hasPreloadedTemplate: true,
    icon: Skull,
  },
  {
    id: 'disco-elysium',
    name: 'Disco Elysium',
    displayName: 'Disco Elysium',
    genre: 'Detektiv-RPG (17 steg)',
    platform: 'PC / PS5',
    hltb: 24,
    hasPreloadedTemplate: true,
    icon: BookOpen,
  },
  {
    id: 'cyberpunk-2077',
    name: 'Cyberpunk 2077',
    displayName: 'Cyberpunk 2077',
    genre: 'Action RPG (28 quests)',
    platform: 'PS5 / PC',
    hltb: 25,
    hasPreloadedTemplate: true,
    icon: Layers,
  },
  {
    id: 'silent-hill-2',
    name: 'Silent Hill 2',
    displayName: 'Silent Hill 2 (Remake)',
    genre: 'Survival Horror (13 zoner)',
    platform: 'PS5 / PC',
    hltb: 16,
    hasPreloadedTemplate: true,
    icon: BookOpen,
  },
  {
    id: 'alan-wake-2',
    name: 'Alan Wake II',
    displayName: 'Alan Wake II',
    genre: 'Survival Horror (18 kapitel)',
    platform: 'PS5 / PC',
    hltb: 18,
    hasPreloadedTemplate: true,
    icon: BookOpen,
  },
  {
    id: 'gow-ragnarok',
    name: 'God of War Ragnarök',
    displayName: 'God of War Ragnarök',
    genre: 'Action Adventure (18 quests)',
    platform: 'PS5 / PC',
    hltb: 26,
    hasPreloadedTemplate: true,
    icon: Layers,
  },
  {
    id: 'witcher-3',
    name: 'The Witcher 3: Wild Hunt',
    displayName: 'The Witcher 3',
    genre: 'Open World RPG (50 quests)',
    platform: 'PS5 / PC',
    hltb: 52,
    hasPreloadedTemplate: true,
    icon: Layers,
  },
  {
    id: 'bg3',
    name: "Baldur's Gate III",
    displayName: "Baldur's Gate III",
    genre: 'CRPG (19 milstolpar)',
    platform: 'PS5 / PC',
    hltb: 65,
    hasPreloadedTemplate: true,
    icon: Layers,
  },
  {
    id: 'elden-ring',
    name: 'Elden Ring',
    displayName: 'Elden Ring',
    genre: 'Action RPG (18 bossar)',
    platform: 'PS5 / PC',
    hltb: 58,
    hasPreloadedTemplate: true,
    icon: Skull,
  },
  {
    id: 'zelda-totk',
    name: 'The Legend of Zelda: Tears of the Kingdom',
    displayName: 'Zelda: Tears of the Kingdom',
    genre: 'Action Adventure (18 quests)',
    platform: 'Switch',
    hltb: 59,
    hasPreloadedTemplate: true,
    icon: Globe,
  },
  {
    id: 'mgs-delta',
    name: 'Metal Gear Solid Delta: Snake Eater',
    displayName: 'MGS Delta: Snake Eater',
    genre: 'Stealth Action (18 sektioner)',
    platform: 'PS5 / PC',
    hltb: 16,
    hasPreloadedTemplate: true,
    icon: Gamepad2,
  },
  {
    id: 'uncharted-4',
    name: "Uncharted 4: A Thief's End",
    displayName: 'Uncharted 4',
    genre: 'Action Adventure (24 kapitel)',
    platform: 'PS5 / PC',
    hltb: 15,
    hasPreloadedTemplate: true,
    icon: BookOpen,
  },
  {
    id: 'tlou-1',
    name: 'The Last of Us Part I',
    displayName: 'The Last of Us Part I',
    genre: 'Action Adventure (12 kapitel)',
    platform: 'PS5 / PC',
    hltb: 15,
    hasPreloadedTemplate: true,
    icon: BookOpen,
  },
  {
    id: 'tlou-2',
    name: 'The Last of Us Part II',
    displayName: 'The Last of Us Part II',
    genre: 'Action Adventure (46 kapitel)',
    platform: 'PS5',
    hltb: 24,
    hasPreloadedTemplate: true,
    icon: BookOpen,
  },
  {
    id: 'rdr-2',
    name: 'Red Dead Redemption 2',
    displayName: 'Red Dead Redemption 2',
    genre: 'Open World (46 uppdrag)',
    platform: 'PS4 / PC',
    hltb: 50,
    hasPreloadedTemplate: true,
    icon: Globe,
  },
  {
    id: 'kcd-1',
    name: 'Kingdom Come: Deliverance',
    displayName: 'Kingdom Come I',
    genre: 'Medeltida RPG (29 quests)',
    platform: 'PS4 / PC',
    hltb: 42,
    hasPreloadedTemplate: true,
    icon: Layers,
  },
  {
    id: 'resident-evil-4',
    name: 'Resident Evil 4',
    displayName: 'Resident Evil 4 (Remake)',
    genre: 'Survival Horror (16 kapitel)',
    platform: 'PS5 / PC',
    hltb: 16,
    hasPreloadedTemplate: true,
    icon: BookOpen,
  },

  // --- SPEL SOM SAKNAR MALL I DATABASEN (TESTA AI ELLER MANUELL IMPORT) ---
  {
    id: 'days-gone',
    name: 'Days Gone',
    displayName: 'Days Gone',
    genre: 'Open World Action',
    platform: 'PS5 / PC',
    hltb: 36,
    hasPreloadedTemplate: false,
    icon: Skull,
  },
  {
    id: 'lost-judgment',
    name: 'Lost Judgment',
    displayName: 'Lost Judgment',
    genre: 'Action RPG',
    platform: 'PS5 / PC',
    hltb: 25,
    hasPreloadedTemplate: false,
    icon: Layers,
  },
  {
    id: 'dark-souls',
    name: 'Dark Souls',
    displayName: 'Dark Souls Remastered',
    genre: 'Action RPG',
    platform: 'PS5 / Switch / PC',
    hltb: 32,
    hasPreloadedTemplate: false,
    icon: Skull,
    samplePasteText: `Northern Undead Asylum
Firelink Shrine
Undead Burg
Undead Parish
Lower Undead Burg
The Depths
Blighttown
Quelaag's Domain
Sen's Fortress
Anor Londo
Darkroot Garden & Basin
New Londo Ruins
The Duke's Archives & Crystal Cave
Demon Ruins
Lost Izalith
The Catacombs
Tomb of the Giants
Kiln of the First Flame`,
  },
  {
    id: 'dead-space',
    name: 'Dead Space',
    displayName: 'Dead Space (Remake)',
    genre: 'Sci-Fi Horror',
    platform: 'PS5 / PC',
    hltb: 12,
    hasPreloadedTemplate: false,
    icon: BookOpen,
    samplePasteText: `Chapter 1: New Arrivals
Chapter 2: Intensive Care
Chapter 3: Course Correction
Chapter 4: Obliteration Imminent
Chapter 5: Lethal Devotion
Chapter 6: Environmental Hazard
Chapter 7: Into the Void
Chapter 8: Search and Rescue
Chapter 9: Dead on Arrival
Chapter 10: End of Days
Chapter 11: Alternate Solutions
Chapter 12: Dead Space`,
  },
  {
    id: 'bioshock-infinite',
    name: 'BioShock Infinite',
    displayName: 'BioShock Infinite',
    genre: 'Story FPS',
    platform: 'PC / PS4',
    hltb: 12,
    hasPreloadedTemplate: false,
    icon: Gamepad2,
  },
];

export default function TestProgressPage() {
  const [selectedGame, setSelectedGame] = useState<LibraryGame>(LIBRARY_GAMES[0]);

  // Sparade mallar och todos per spel-ID under test-sessionen
  const [sessionTemplates, setSessionTemplates] = useState<Record<string, LoadedTemplate>>({});
  const [sessionTodos, setSessionTodos] = useState<Record<string, ActiveTodo[]>>({});

  const [geminiApiKey, setGeminiApiKey] = useState<string>('');
  const [showApiKeyModal, setShowApiKeyModal] = useState<boolean>(false);

  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [loadingStatus, setLoadingStatus] = useState<string>('');
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Aktivt spel-tillstånd
  const [template, setTemplate] = useState<LoadedTemplate | null>(null);
  const [todos, setTodos] = useState<ActiveTodo[]>([]);
  const [masterTemplateTodos, setMasterTemplateTodos] = useState<ActiveTodo[]>([]);

  // Lägen i Tomt tillstånd (när ett spel saknar walkthrough)
  const [showManualPaste, setShowManualPaste] = useState<boolean>(false);
  const [rawTextInput, setRawTextInput] = useState<string>('');

  // Visnings- och redigeringsinställningar för listan
  const [isEditMode, setIsEditMode] = useState<boolean>(false);
  const [spoilerProtection, setSpoilerProtection] = useState<boolean>(true);
  const [revealedIds, setRevealedIds] = useState<Set<string>>(new Set());
  const [viewMode, setViewMode] = useState<'grouped' | 'chronological'>('grouped');
  const [collapsedGroups, setCollapsedGroups] = useState<Set<string>>(new Set());
  const [selectedGroupFilter, setSelectedGroupFilter] = useState<string>('all');

  // Inline-redigering & lägg till nytt delmål
  const [editingTodoId, setEditingTodoId] = useState<string | null>(null);
  const [editingTodoText, setEditingTodoText] = useState<string>('');
  const [editingTodoGroup, setEditingTodoGroup] = useState<string>('');
  const [newTodoTitle, setNewTodoTitle] = useState<string>('');
  const [newTodoChapterGroup, setNewTodoChapterGroup] = useState<string>('');

  // Ladda sparad Gemini API-nyckel från localStorage
  useEffect(() => {
    const savedKey = localStorage.getItem('gameshelf_gemini_key');
    if (savedKey) setGeminiApiKey(savedKey);
  }, []);

  const saveApiKey = (key: string) => {
    setGeminiApiKey(key);
    localStorage.setItem('gameshelf_gemini_key', key);
  };

  // Synka ändringar i todos till sessionTodos för det valda spelet
  useEffect(() => {
    if (selectedGame && template && todos.length > 0) {
      setSessionTodos((prev) => ({ ...prev, [selectedGame.id]: todos }));
    }
  }, [todos, selectedGame, template]);

  const applyTemplateToState = (game: LibraryGame, data: LoadedTemplate, existingTodos?: ActiveTodo[]) => {
    setTemplate(data);
    setSelectedGroupFilter('all');
    setCollapsedGroups(new Set());
    setRevealedIds(new Set());

    const initialTodos: ActiveTodo[] = (data.items || []).map((item: TemplateItem, index: number) => ({
      id: item.id || `todo-${index}`,
      title: item.title,
      chapterGroup: item.chapterGroup,
      isDone: false,
      order: item.order || index + 1,
      isOptional: item.isOptional,
    }));

    setMasterTemplateTodos(initialTodos);
    setTodos(existingTodos && existingTodos.length > 0 ? existingTodos : initialTodos);
    setSessionTemplates((prev) => ({ ...prev, [game.id]: data }));
  };

  // Byt aktivt spel i biblioteket
  const selectLibraryGame = async (game: LibraryGame) => {
    setSelectedGame(game);
    setErrorMsg(null);
    setShowManualPaste(false);
    setRawTextInput('');
    setIsEditMode(false);
    setEditingTodoId(null);

    // 1. Har vi redan laddat eller skapat en mall för detta spel under sessionen?
    if (sessionTemplates[game.id]) {
      applyTemplateToState(game, sessionTemplates[game.id], sessionTodos[game.id]);
      return;
    }

    // 2. Är det ett spel med förinlagd mall i databasen? Hämta direkt!
    if (game.hasPreloadedTemplate) {
      setIsLoading(true);
      setLoadingStatus(`Hämtar sparad kapitelmall för ${game.displayName}...`);
      try {
        const res = await fetch('/api/games/progress-template', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            gameTitle: game.name,
            granularity: 'standard',
            forceAI: false,
          }),
        });
        if (res.ok) {
          const data = await res.json();
          if (data && data.items && data.items.length > 0) {
            applyTemplateToState(game, data);
            return;
          }
        }
        setTemplate(null);
        setTodos([]);
      } catch {
        setTemplate(null);
        setTodos([]);
      } finally {
        setIsLoading(false);
        setLoadingStatus('');
      }
    } else {
      // 3. Spelet saknar mall i databasen -> visa Tomt läge (Empty State) på detaljsidan
      setTemplate(null);
      setTodos([]);
      setMasterTemplateTodos([]);
    }
  };

  // Ladda första spelet vid sidstart
  useEffect(() => {
    selectLibraryGame(LIBRARY_GAMES[0]);
  }, []);

  // Generera 1:1 kapitellista med AI för det valda spelet (med automatisk reservmodell vid High Demand / Timeout)
  const handleGenerateWithAI = async () => {
    const cleanKey = geminiApiKey.trim();
    if (!cleanKey) {
      setShowApiKeyModal(true);
      setErrorMsg('Ange en Gemini API-nyckel först, eller klistra in kapitellistan manuellt nedan.');
      setShowManualPaste(true);
      return;
    }

    setIsLoading(true);
    setErrorMsg(null);
    const title = selectedGame.name;
    setLoadingStatus(`Hämtar 1:1 kapitellista (IGN Walkthrough-struktur) för ${selectedGame.displayName}...`);

    const ignSlug = title
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/['’]/g, '')
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '');
    const ignSourceUrl = `https://www.ign.com/wikis/${ignSlug}/Walkthrough`;

    const prompt = `Task: Create the COMPLETE, chronological 1:1 main story walkthrough progression list for the video game "${title}", structured like IGN's official Walkthrough guide.

STRICT RULES:
1. COMPLETE 1:1 LIST (NO LUMPING, NO SKIPPING):
   - Include EVERY official main story chapter, main quest, or walkthrough area in chronological order from start to finish.
   - NEVER combine two chapters, quests, or areas into one item (e.g., NEVER write "Chapter 1 & 2"). Each must be its own separate object in "items".
2. EXCLUDE MINOR SIDE CONTENT:
   - Only include main story chapters/quests/areas (plus major optional boss areas if relevant, marked with "isOptional": true).
3. OFFICIAL ENGLISH TITLES:
   - Keep the official English in-game/IGN titles for all chapters, quests, and areas. Do not translate titles to Swedish!
4. ACT / PHASE GROUPING ("chapterGroup"):
   - Group every item into its overarching Act, Phase, or Region using "chapterGroup" (e.g., "Prolog", "Akt 1", "Akt 2", "Akt 3", "Final").
5. Output ONLY valid JSON matching this exact schema:
{
  "gameTitle": "${title}",
  "hasLinearProgression": true,
  "progressionType": "chapters" | "acts" | "main_quests" | "bosses" | "worlds",
  "summary": "Kort svensk sammanfattning av spelets upplägg",
  "items": [
    {
      "id": "1",
      "title": "Exact English Chapter / Quest / Area Title",
      "order": 1,
      "chapterGroup": "Akt 1",
      "description": "Kort svensk info",
      "isOptional": false
    }
  ]
}`;

    try {
      let candidateModels = ['gemini-3.8-flash', 'gemini-3.7-flash', 'gemini-2.5-flash'];
      try {
        const listRes = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(cleanKey)}`
        );
        if (listRes.ok) {
          const listData = await listRes.json();
          if (Array.isArray(listData.models)) {
            const supported = listData.models
              .filter((m: any) => m.supportedGenerationMethods?.includes('generateContent'))
              .map((m: any) => (m.name as string).replace(/^models\//, ''))
              .filter(
                (n: string) =>
                  !n.includes('tts') &&
                  !n.includes('audio') &&
                  !n.includes('embed') &&
                  !n.includes('imagen') &&
                  !n.includes('aqa') &&
                  !n.includes('learnlm')
              );
            const getVer = (n: string): number => {
              const match = n.match(/gemini[^\d]*(\d+(?:\.\d+)?)/i);
              return match ? parseFloat(match[1]) : 0;
            };
            const flash = supported
              .filter((m: string) => m.includes('flash'))
              .sort((a: string, b: string) => getVer(b) - getVer(a));
            const others = supported
              .filter((m: string) => !m.includes('flash'))
              .sort((a: string, b: string) => getVer(b) - getVer(a));
            const unique = Array.from(new Set([...flash, ...others]));
            if (unique.length > 0) candidateModels = unique.slice(0, 4);
          }
        }
      } catch {}

      let lastError: Error | null = null;

      for (let i = 0; i < candidateModels.length; i++) {
        const modelName = candidateModels[i];
        try {
          if (i > 0) {
            setLoadingStatus(
              `Försöker med reservmodell (${modelName}) för ${selectedGame.displayName}...`
            );
          }

          const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${encodeURIComponent(cleanKey)}`;

          let response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{ parts: [{ text: prompt }] }],
              generationConfig: {
                temperature: 0.1,
                responseMimeType: 'application/json',
                maxOutputTokens: 8192,
                thinkingConfig: { thinkingBudget: 0 },
              },
            }),
          });

          if (!response.ok && response.status === 400) {
            response = await fetch(url, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                contents: [{ parts: [{ text: prompt }] }],
                generationConfig: {
                  temperature: 0.1,
                  responseMimeType: 'application/json',
                  maxOutputTokens: 8192,
                },
              }),
            });
          }

          if (!response.ok) {
            const errJson = await response.json().catch(() => null);
            throw new Error(errJson?.error?.message || `HTTP ${response.status}`);
          }

          const data = await response.json();
          const parts = data.candidates?.[0]?.content?.parts || [];
          const textContent =
            parts
              .filter((p: any) => !p.thought)
              .map((p: any) => p.text || '')
              .join('\n')
              .trim() || parts.map((p: any) => p.text || '').join('\n').trim();

          if (!textContent) throw new Error('Tomt svar från AI');

          let cleaned = textContent.trim();
          const codeBlock = cleaned.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
          if (codeBlock) {
            cleaned = codeBlock[1].trim();
          } else {
            const firstBrace = cleaned.indexOf('{');
            const lastBrace = cleaned.lastIndexOf('}');
            if (firstBrace !== -1 && lastBrace !== -1 && lastBrace > firstBrace) {
              cleaned = cleaned.substring(firstBrace, lastBrace + 1).trim();
            }
          }

          const parsed = JSON.parse(cleaned);
          const rawItems = Array.isArray(parsed.items)
            ? parsed.items
            : Array.isArray(parsed.chapters)
            ? parsed.chapters
            : Array.isArray(parsed.walkthrough)
            ? parsed.walkthrough
            : [];

          if (rawItems.length === 0) throw new Error('Inga kapitel returnerades');

          const newTemplate: LoadedTemplate = {
            gameTitle: selectedGame.displayName,
            hasLinearProgression: true,
            progressionType:
              parsed.progressionType && parsed.progressionType !== 'none' ? parsed.progressionType : 'chapters',
            granularity: 'standard',
            summary: parsed.summary || `Kapitellista genererad för ${selectedGame.displayName}.`,
            items: rawItems.map((it: any, idx: number) => ({
              id: String(it.id || idx + 1),
              title: String(it.title || it.name || `Delmål ${idx + 1}`),
              order: Number(it.order || idx + 1),
              chapterGroup: it.chapterGroup || it.act || it.region || 'Huvudstory',
              description: it.description,
              isOptional: Boolean(it.isOptional),
            })),
            source: 'scraped_guide',
            sourceUrl: ignSourceUrl,
            modelUsed: modelName,
          };

          applyTemplateToState(selectedGame, newTemplate);
          return;
        } catch (err: any) {
          lastError = err;
        }
      }

      throw lastError || new Error('Timeout eller hög belastning hos AI-tjänsten.');
    } catch (err: any) {
      setErrorMsg(
        `Kunde inte hämta med AI just nu (${err.message || 'hög belastning / timeout'}). Du kan klistra in kapitellistan manuellt direkt här nedanför!`
      );
      setShowManualPaste(true);
    } finally {
      setIsLoading(false);
      setLoadingStatus('');
    }
  };

  // Skapa checklista från manuellt inklistrad text (ingen speltitel behöver skrivas in!)
  const handleCreateFromPaste = () => {
    const lines = rawTextInput
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean);

    const items: TemplateItem[] = [];
    let currentAct = 'Huvudstory';
    let order = 1;

    for (const line of lines) {
      if (line.length < 2 || line.length > 140) continue;
      if (/^(cookie|copyright|privacy|advertisement|follow us|subscribe|sign up)/i.test(line)) continue;

      // Om raden ser ut som en ren Akt-rubrik (t.ex. "Act 1", "Akt 2", "Prologue") utan kolon+undertitel
      if (/^(akt|act)\s*\d+\s*$/i.test(line) || /^(prolog|prologue|epilog|epilogue|final|finale)\s*$/i.test(line)) {
        currentAct = line;
        continue;
      }

      const cleaned = line
        .replace(/^[\d]+[\.\)\:\-]\s*/, '')
        .replace(/^[-*•]\s*/, '')
        .trim();

      if (cleaned.length >= 2) {
        items.push({
          id: `custom-${order}`,
          title: cleaned,
          order,
          chapterGroup: currentAct,
        });
        order++;
      }
    }

    if (items.length === 0) {
      setErrorMsg('Kunde inte hitta några rader. Klistra in en lista med ett kapitel eller uppdrag per rad.');
      return;
    }

    const customTemplate: LoadedTemplate = {
      gameTitle: selectedGame.displayName,
      hasLinearProgression: true,
      progressionType: 'chapters',
      summary: `Manuellt inlagd kapitellista för ${selectedGame.displayName} (${items.length} steg).`,
      items,
      source: 'custom',
    };

    setErrorMsg(null);
    setShowManualPaste(false);
    applyTemplateToState(selectedGame, customTemplate);
  };

  // Ta bort inlagd mall för ett testspel (för att kunna testa tomt läge på nytt)
  const clearCustomTemplateForCurrentGame = () => {
    setSessionTemplates((prev) => {
      const next = { ...prev };
      delete next[selectedGame.id];
      return next;
    });
    setSessionTodos((prev) => {
      const next = { ...prev };
      delete next[selectedGame.id];
      return next;
    });
    setTemplate(null);
    setTodos([]);
    setMasterTemplateTodos([]);
  };

  // Antal upptäckta rader i manuell inklistring
  const detectedPasteCount = useMemo(() => {
    return rawTextInput
      .split('\n')
      .map((l) => l.trim())
      .filter((l) => l.length >= 2 && l.length <= 140).length;
  }, [rawTextInput]);

  // Framstegsberäkningar
  const totalCount = todos.length;
  const doneCount = todos.filter((t) => t.isDone).length;
  const progressPercent = totalCount > 0 ? Math.round((doneCount / totalCount) * 100) : 0;

  const calculatedStoryMilestone = useMemo(() => {
    if (totalCount === 0) return 'Ej påbörjat';
    if (doneCount === 0) return 'Inte påbörjat';
    if (doneCount === totalCount) return '🏆 Klar';
    if (progressPercent >= 75) return '🔥 Närmar mig slutet';
    if (progressPercent >= 35) return '⚡ Mitt i det';
    return '🌱 Precis börjat';
  }, [doneCount, totalCount, progressPercent]);

  const estimatedRemainingHours = useMemo(() => {
    if (selectedGame.hltb <= 0 || totalCount === 0) return null;
    const remainingFraction = (totalCount - doneCount) / totalCount;
    return Math.round(selectedGame.hltb * remainingFraction * 10) / 10;
  }, [selectedGame.hltb, totalCount, doneCount]);

  const currentChapterIndex = useMemo(() => {
    const idx = todos.findIndex((t) => !t.isDone);
    return idx === -1 ? todos.length : idx;
  }, [todos]);

  // Plocka ut överordnad Huvudakt (t.ex. "Akt 2 (Panam)" -> "Akt 2")
  const getMajorAct = (chapterGroup?: string): string => {
    if (!chapterGroup) return 'Huvudstory';
    const match = chapterGroup.match(/^(Akt\s*\d+|Act\s*\d+|Prolog|Prologue|Epilog|Epilogue|Final|Byn|Slottet|Ön|Sommar|Höst|Vinter|Vår)/i);
    if (match) return match[1].trim();
    return chapterGroup.split('(')[0].trim() || 'Huvudstory';
  };

  const groups = useMemo(() => {
    const map = new Map<string, ActiveTodo[]>();
    todos.forEach((todo) => {
      const g = todo.chapterGroup || 'Huvudstory';
      if (!map.has(g)) map.set(g, []);
      map.get(g)!.push(todo);
    });
    return Array.from(map.entries()).map(([name, items]) => {
      const done = items.filter((i) => i.isDone).length;
      const total = items.length;
      const isCompleted = done === total && total > 0;
      const majorAct = getMajorAct(name);
      return { name, items, done, total, isCompleted, majorAct };
    });
  }, [todos]);

  const majorActs = useMemo(() => {
    const list: { name: string; isCompleted: boolean; done: number; total: number }[] = [];
    todos.forEach((todo) => {
      const actName = getMajorAct(todo.chapterGroup);
      let entry = list.find((a) => a.name.toLowerCase() === actName.toLowerCase());
      if (!entry) {
        entry = { name: actName, isCompleted: false, done: 0, total: 0 };
        list.push(entry);
      }
      entry.total++;
      if (todo.isDone) entry.done++;
    });
    list.forEach((a) => {
      a.isCompleted = a.done === a.total && a.total > 0;
    });
    return list;
  }, [todos]);

  const activeMajorActIndex = useMemo(() => {
    const idx = majorActs.findIndex((a) => !a.isCompleted);
    return idx === -1 ? majorActs.length : idx;
  }, [majorActs]);

  const activeMajorActName = useMemo(() => {
    return activeMajorActIndex < majorActs.length ? majorActs[activeMajorActIndex]?.name : null;
  }, [majorActs, activeMajorActIndex]);

  const isItemHiddenBySpoiler = (item: ActiveTodo, indexInFlatList: number) => {
    if (!spoilerProtection) return false;
    if (item.isDone) return false;
    if (revealedIds.has(item.id)) return false;

    if (majorActs.length > 1 && activeMajorActIndex !== -1) {
      const itemMajorAct = getMajorAct(item.chapterGroup);
      const actIdx = majorActs.findIndex((a) => a.name.toLowerCase() === itemMajorAct.toLowerCase());
      if (actIdx !== -1) {
        if (actIdx <= activeMajorActIndex) return false;
        return true;
      }
    }

    return indexInFlatList > currentChapterIndex;
  };

  // List-operationer
  const toggleTodo = (id: string) => {
    setTodos((prev) => prev.map((t) => (t.id === id ? { ...t, isDone: !t.isDone } : t)));
  };

  const toggleReveal = (id: string) => {
    setRevealedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleGroupCollapse = (groupName: string) => {
    setCollapsedGroups((prev) => {
      const next = new Set(prev);
      if (next.has(groupName)) next.delete(groupName);
      else next.add(groupName);
      return next;
    });
  };

  const startEditing = (todo: ActiveTodo) => {
    setEditingTodoId(todo.id);
    setEditingTodoText(todo.title);
    setEditingTodoGroup(todo.chapterGroup || '');
  };

  const saveEditing = (id: string) => {
    if (editingTodoText.trim()) {
      setTodos((prev) =>
        prev.map((t) =>
          t.id === id
            ? {
                ...t,
                title: editingTodoText.trim(),
                chapterGroup: editingTodoGroup.trim() || undefined,
              }
            : t
        )
      );
    }
    setEditingTodoId(null);
  };

  const moveTodoUp = (index: number) => {
    if (index <= 0) return;
    setTodos((prev) => {
      const updated = [...prev];
      const temp = updated[index];
      updated[index] = updated[index - 1];
      updated[index - 1] = temp;
      return updated.map((t, idx) => ({ ...t, order: idx + 1 }));
    });
  };

  const moveTodoDown = (index: number) => {
    if (index >= todos.length - 1) return;
    setTodos((prev) => {
      const updated = [...prev];
      const temp = updated[index];
      updated[index] = updated[index + 1];
      updated[index + 1] = temp;
      return updated.map((t, idx) => ({ ...t, order: idx + 1 }));
    });
  };

  const toggleOptional = (id: string) => {
    setTodos((prev) => prev.map((t) => (t.id === id ? { ...t, isOptional: !t.isOptional } : t)));
  };

  const removeTodo = (id: string) => {
    setTodos((prev) => prev.filter((t) => t.id !== id));
  };

  const handleAddCustomTodo = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTodoTitle.trim()) return;
    const newItem: ActiveTodo = {
      id: `custom-${Date.now()}`,
      title: newTodoTitle.trim(),
      chapterGroup: newTodoChapterGroup.trim() || activeMajorActName || 'Huvudstory',
      isDone: false,
      order: todos.length + 1,
    };
    setTodos((prev) => [...prev, newItem]);
    setNewTodoTitle('');
    setNewTodoChapterGroup('');
  };

  const restoreMasterTemplate = () => {
    if (masterTemplateTodos.length > 0) {
      setTodos(masterTemplateTodos.map((t) => ({ ...t, isDone: false })));
    }
  };

  const preloadedGames = LIBRARY_GAMES.filter((g) => g.hasPreloadedTemplate);
  const missingTemplateGames = LIBRARY_GAMES.filter((g) => !g.hasPreloadedTemplate);

  return (
    <div className="min-h-screen bg-gray-950 text-gray-100 pb-20">
      {/* Top Bar */}
      <header className="border-b border-gray-800/80 bg-gray-900/60 backdrop-blur sticky top-0 z-20">
        <div className="max-w-5xl mx-auto px-4 py-3.5 flex items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-9 h-9 rounded-xl bg-red-600/20 border border-red-500/40 flex items-center justify-center text-red-400">
              <Gamepad2 className="w-5 h-5" />
            </div>
            <div>
              <h1 className="text-base font-bold text-white">GameShelf – Speldetaljvy (Walkthrough & Framsteg)</h1>
              <p className="text-xs text-gray-400">
                Välj ett spel i biblioteket nedan för att se hur detaljsidan fungerar med eller utan förinlagd walkthrough
              </p>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => setShowApiKeyModal(!showApiKeyModal)}
              className={`px-3 py-1.5 rounded-xl border text-xs font-medium flex items-center gap-1.5 transition-colors ${
                geminiApiKey.trim()
                  ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300'
                  : 'bg-amber-500/10 border-amber-500/30 text-amber-300'
              }`}
            >
              <Key className="w-3.5 h-3.5" />
              <span>{geminiApiKey.trim() ? 'AI-nyckel aktiv' : 'Ställ in AI-nyckel'}</span>
            </button>
            <Link
              href="/"
              className="text-xs text-gray-400 hover:text-white px-3 py-1.5 rounded-lg bg-gray-800/60 hover:bg-gray-800 transition-colors"
            >
              Tillbaka
            </Link>
          </div>
        </div>

        {/* Inställningspanel för API-nyckel */}
        {showApiKeyModal && (
          <div className="max-w-5xl mx-auto px-4 pb-4">
            <div className="bg-gray-950 border border-amber-500/30 rounded-xl p-4 text-xs space-y-2">
              <div className="flex items-center justify-between">
                <span className="font-semibold text-amber-300 flex items-center gap-1.5">
                  <Key className="w-4 h-4" /> Google Gemini API-nyckel (används när ett spel saknar mall i databasen)
                </span>
                <button
                  type="button"
                  onClick={() => setShowApiKeyModal(false)}
                  className="text-gray-400 hover:text-white"
                >
                  Stäng
                </button>
              </div>
              <input
                type="password"
                placeholder="Klistra in din Gemini API-nyckel här..."
                value={geminiApiKey}
                onChange={(e) => saveApiKey(e.target.value)}
                className="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-xs text-white focus:outline-none focus:border-amber-500"
              />
            </div>
          </div>
        )}
      </header>

      <main className="max-w-5xl mx-auto px-4 py-6 space-y-6">
        {/* 1. BIBLIOTEKSVÄLJARE: Spel med mall vs Spel utan mall */}
        <section className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {/* Kolumn A: Spel som redan finns i databasen */}
          <div className="bg-gray-900/50 border border-gray-800 rounded-2xl p-4 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-emerald-400 flex items-center gap-1.5">
                <Shield className="w-3.5 h-3.5" /> Redan i databasen (6 spel)
              </span>
              <span className="text-[11px] text-gray-500">Visar listan direkt</span>
            </div>
            <div className="grid grid-cols-2 gap-2">
              {preloadedGames.map((g) => {
                const Icon = g.icon;
                const isSelected = selectedGame.id === g.id;
                return (
                  <button
                    key={g.id}
                    type="button"
                    onClick={() => selectLibraryGame(g)}
                    className={`p-2.5 rounded-xl border text-left transition-all flex items-center gap-2.5 ${
                      isSelected
                        ? 'bg-red-500/15 border-red-500 text-white shadow-md'
                        : 'bg-gray-950/60 border-gray-800/80 text-gray-300 hover:bg-gray-800/50'
                    }`}
                  >
                    <Icon className={`w-4 h-4 shrink-0 ${isSelected ? 'text-red-400' : 'text-emerald-400'}`} />
                    <div className="min-w-0 flex-1">
                      <div className="text-xs font-semibold truncate">{g.displayName}</div>
                      <div className="text-[10px] text-gray-500 truncate">{g.genre} • ~{g.hltb}h</div>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Kolumn B: Spel som SAKNAR mall i databasen */}
          <div className="bg-gray-900/50 border border-gray-800 rounded-2xl p-4 space-y-3">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5" /> Saknar mall i databasen (6 spel)
              </span>
              <span className="text-[11px] text-gray-500">Testa AI eller Klistra in</span>
            </div>
            <div className="grid grid-cols-2 gap-2">
              {missingTemplateGames.map((g) => {
                const Icon = g.icon;
                const isSelected = selectedGame.id === g.id;
                const hasAddedInSession = Boolean(sessionTemplates[g.id]);
                return (
                  <button
                    key={g.id}
                    type="button"
                    onClick={() => selectLibraryGame(g)}
                    className={`p-2.5 rounded-xl border text-left transition-all flex items-center gap-2.5 ${
                      isSelected
                        ? 'bg-red-500/15 border-red-500 text-white shadow-md'
                        : 'bg-gray-950/60 border-gray-800/80 text-gray-300 hover:bg-gray-800/50'
                    }`}
                  >
                    <Icon
                      className={`w-4 h-4 shrink-0 ${
                        isSelected ? 'text-red-400' : hasAddedInSession ? 'text-emerald-400' : 'text-amber-400/80'
                      }`}
                    />
                    <div className="min-w-0 flex-1">
                      <div className="text-xs font-semibold truncate flex items-center gap-1">
                        <span className="truncate">{g.displayName}</span>
                        {hasAddedInSession && <Check className="w-3 h-3 text-emerald-400 shrink-0" />}
                      </div>
                      <div className="text-[10px] text-gray-500 truncate">
                        {hasAddedInSession ? 'Mall tillagd!' : 'Ingen mall ännu'} • ~{g.hltb}h
                      </div>
                    </div>
                  </button>
                );
              })}
            </div>
          </div>
        </section>

        {/* 2. SPELDETALJSIDAN FÖR DET VALDA SPELET */}
        <section className="bg-gray-900/70 border border-gray-800 rounded-2xl overflow-hidden shadow-xl">
          {/* Spelhuvud (Precis som i GameDetailView i appen) */}
          <div className="p-5 sm:p-6 border-b border-gray-800 bg-gradient-to-r from-gray-900 via-gray-900 to-gray-950 flex flex-wrap items-center justify-between gap-4">
            <div className="space-y-1">
              <div className="flex flex-wrap items-center gap-2">
                <span className="text-[11px] uppercase tracking-wider font-semibold px-2.5 py-0.5 rounded-full bg-gray-800 text-gray-300">
                  {selectedGame.platform}
                </span>
                <span className="text-[11px] text-gray-400">{selectedGame.genre}</span>
                <span className="text-[11px] text-gray-500 flex items-center gap-1">
                  <Clock className="w-3 h-3" /> HLTB ~{selectedGame.hltb}h
                </span>
              </div>
              <h2 className="text-2xl font-extrabold text-white tracking-tight flex flex-wrap items-center gap-2.5">
                <span>{selectedGame.displayName}</span>
                {template?.source === 'curated' && (
                  <span className="text-[11px] bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 px-2.5 py-0.5 rounded-full font-semibold flex items-center gap-1">
                    <Shield className="w-3 h-3" /> Verifierad mall
                  </span>
                )}
                {template?.source === 'scraped_guide' && (
                  <span className="text-[11px] bg-purple-500/20 text-purple-300 border border-purple-500/30 px-2.5 py-0.5 rounded-full font-semibold flex items-center gap-1">
                    <Sparkles className="w-3 h-3" /> AI-genererad ({template.modelUsed})
                  </span>
                )}
                {template?.source === 'custom' && (
                  <span className="text-[11px] bg-blue-500/20 text-blue-300 border border-blue-500/30 px-2.5 py-0.5 rounded-full font-semibold flex items-center gap-1">
                    <FileText className="w-3 h-3" /> Manuellt inklistrad
                  </span>
                )}
              </h2>
              {template?.summary && <p className="text-xs text-gray-400 max-w-2xl">{template.summary}</p>}
            </div>

            {/* Om det är ett av testspelen utan förinlagd mall och man har lagt in en mall under testet: knapp för att testa tomt läge igen */}
            {!selectedGame.hasPreloadedTemplate && template && (
              <button
                type="button"
                onClick={clearCustomTemplateForCurrentGame}
                className="text-xs text-gray-400 hover:text-red-300 bg-gray-950/80 border border-gray-800 px-3 py-1.5 rounded-xl transition-colors flex items-center gap-1.5"
              >
                <RotateCcw className="w-3.5 h-3.5" />
                Nollställ till &quot;Saknar mall&quot;
              </button>
            )}
          </div>

          <div className="p-5 sm:p-6 space-y-6">
            {/* Laddningsindikator */}
            {isLoading && (
              <div className="p-6 rounded-2xl bg-gray-950/80 border border-purple-500/30 text-center space-y-2 animate-pulse">
                <Sparkles className="w-6 h-6 text-purple-400 mx-auto animate-spin" />
                <div className="text-sm font-semibold text-white">
                  {loadingStatus || `Hämtar kapitel för ${selectedGame.displayName}...`}
                </div>
                <p className="text-xs text-gray-400">
                  Om en AI-modell har hög belastning växlar vi automatiskt till en reservmodell...
                </p>
              </div>
            )}

            {/* Felmeddelande (med direkt hänvisning till manuell inmatning) */}
            {errorMsg && (
              <div className="p-4 rounded-xl bg-amber-950/40 border border-amber-500/40 text-amber-200 text-xs flex items-start gap-2.5">
                <AlertCircle className="w-4 h-4 text-amber-400 shrink-0 mt-0.5" />
                <div className="space-y-1">
                  <div className="font-semibold">Kunde inte hämta automatiskt</div>
                  <div>{errorMsg}</div>
                </div>
              </div>
            )}

            {/* SCENARIO B: SPELET SAKNAR WALKTHROUGH I DATABASEN */}
            {!isLoading && !template && (
              <div className="bg-gray-950/70 border border-gray-800/90 rounded-2xl p-6 space-y-5">
                <div className="text-center max-w-lg mx-auto space-y-2">
                  <div className="w-11 h-11 rounded-2xl bg-gray-900 border border-gray-800 flex items-center justify-center mx-auto text-gray-400">
                    <ListChecks className="w-6 h-6 text-red-400" />
                  </div>
                  <h3 className="text-base font-bold text-white">
                    Ingen walkthrough inlagd för {selectedGame.displayName} ännu
                  </h3>
                  <p className="text-xs text-gray-400 leading-relaxed">
                    Det här spelet saknar kapitel i databasen. Eftersom vi redan är inne på{' '}
                    <strong className="text-gray-200">{selectedGame.displayName}</strong> behöver du bara välja om AI
                    ska hämta kapitellistan åt dig eller om du vill klistra in en egen lista.
                  </p>
                </div>

                {/* De två huvudvalen */}
                <div className="flex flex-wrap items-center justify-center gap-3">
                  <button
                    type="button"
                    onClick={handleGenerateWithAI}
                    disabled={isLoading}
                    className="px-5 py-2.5 bg-purple-600 hover:bg-purple-500 text-white text-xs font-semibold rounded-xl transition-all shadow-lg shadow-purple-500/20 flex items-center gap-2"
                  >
                    <Sparkles className="w-4 h-4" />
                    Fyll i kapitel med AI ({selectedGame.displayName})
                  </button>

                  <button
                    type="button"
                    onClick={() => setShowManualPaste(!showManualPaste)}
                    className={`px-5 py-2.5 text-xs font-semibold rounded-xl transition-all border flex items-center gap-2 ${
                      showManualPaste
                        ? 'bg-blue-600 text-white border-blue-500'
                        : 'bg-gray-900 hover:bg-gray-800 text-gray-200 border-gray-700'
                    }`}
                  >
                    <FileText className="w-4 h-4" />
                    Klistra in text manuellt
                  </button>
                </div>

                {/* Manuell textinklistring (utan att behöva skriva speltitel!) */}
                {showManualPaste && (
                  <div className="bg-gray-900/90 border border-blue-500/30 rounded-xl p-4 space-y-3 pt-4">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <div>
                        <h4 className="text-xs font-bold text-white">
                          Klistra in kapitel eller uppdrag för {selectedGame.displayName}
                        </h4>
                        <p className="text-[11px] text-gray-400">
                          Kopiera en lista (t.ex. från IGN eller en guide) med ett kapitel per rad och klistra in här.
                        </p>
                      </div>
                      {selectedGame.samplePasteText && (
                        <button
                          type="button"
                          onClick={() => setRawTextInput(selectedGame.samplePasteText || '')}
                          className="text-[11px] px-2.5 py-1 rounded-lg bg-blue-500/15 text-blue-300 border border-blue-500/30 hover:bg-blue-500/25 transition-colors"
                        >
                          Fyll i exempeltext för {selectedGame.displayName}
                        </button>
                      )}
                    </div>

                    <textarea
                      rows={7}
                      placeholder={`Klistra in kapitellistan för ${selectedGame.displayName} här (en rad per kapitel/uppdrag)...`}
                      value={rawTextInput}
                      onChange={(e) => setRawTextInput(e.target.value)}
                      className="w-full bg-gray-950 border border-gray-800 rounded-xl p-3 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 font-mono leading-relaxed"
                    />

                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span className="text-xs text-gray-400 flex items-center gap-1.5">
                        <CheckCheck className="w-4 h-4 text-emerald-400" />
                        {detectedPasteCount > 0
                          ? `${detectedPasteCount} steg redo att läggas till`
                          : 'Väntar på inklistrad text...'}
                      </span>

                      <button
                        type="button"
                        onClick={handleCreateFromPaste}
                        disabled={detectedPasteCount === 0}
                        className="px-4 py-2 bg-blue-600 hover:bg-blue-500 disabled:opacity-40 text-white text-xs font-semibold rounded-xl transition-all"
                      >
                        Spara lista till {selectedGame.displayName}
                      </button>
                    </div>
                  </div>
                )}
              </div>
            )}

            {/* SCENARIO A: SPELET HAR EN WALKTHROUGH-LISTA */}
            {!isLoading && template && (
              <div className="space-y-5">
                {/* Kompakt Framstegsmätare (Som på detaljsidan i appen) */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  <div className="bg-gray-950/80 border border-gray-800/90 p-3.5 rounded-xl">
                    <span className="text-[10px] uppercase font-semibold text-gray-500 block">Framsteg</span>
                    <div className="text-xl font-bold text-white flex items-baseline gap-2 mt-0.5">
                      {doneCount} / {totalCount}
                      <span className="text-xs font-semibold text-red-400">({progressPercent}%)</span>
                    </div>
                  </div>

                  <div className="bg-gray-950/80 border border-gray-800/90 p-3.5 rounded-xl">
                    <span className="text-[10px] uppercase font-semibold text-gray-500 block">Story-status</span>
                    <div className="text-base font-bold text-white mt-0.5 truncate">{calculatedStoryMilestone}</div>
                  </div>

                  <div className="bg-gray-950/80 border border-gray-800/90 p-3.5 rounded-xl">
                    <span className="text-[10px] uppercase font-semibold text-gray-500 block">Uppskattad tid kvar</span>
                    <div className="text-xl font-bold text-white flex items-baseline gap-1.5 mt-0.5">
                      {estimatedRemainingHours !== null ? `${estimatedRemainingHours}h` : '–'}
                      <span className="text-xs text-gray-500 font-normal">(av ~{selectedGame.hltb}h)</span>
                    </div>
                  </div>
                </div>

                {/* Progress Bar */}
                <div className="w-full bg-gray-950 rounded-full h-3 overflow-hidden border border-gray-800 p-0.5">
                  <div
                    className="h-full rounded-full transition-all duration-500 bg-gradient-to-r from-red-600 via-orange-500 to-emerald-500"
                    style={{ width: `${progressPercent}%` }}
                  />
                </div>

                {/* Verktygsrad för listan */}
                <div className="flex flex-wrap items-center justify-between gap-2 pt-1">
                  <div className="flex flex-wrap items-center gap-2">
                    <div className="inline-flex rounded-xl bg-gray-950 p-1 border border-gray-800 text-xs">
                      <button
                        type="button"
                        onClick={() => setViewMode('grouped')}
                        className={`px-2.5 py-1 rounded-lg font-medium transition flex items-center gap-1.5 ${
                          viewMode === 'grouped' ? 'bg-red-600 text-white' : 'text-gray-400 hover:text-white'
                        }`}
                      >
                        <Layers className="w-3.5 h-3.5" />
                        <span>Akter ({groups.length})</span>
                      </button>
                      <button
                        type="button"
                        onClick={() => setViewMode('chronological')}
                        className={`px-2.5 py-1 rounded-lg font-medium transition flex items-center gap-1.5 ${
                          viewMode === 'chronological' ? 'bg-red-600 text-white' : 'text-gray-400 hover:text-white'
                        }`}
                      >
                        <ListChecks className="w-3.5 h-3.5" />
                        <span>Alla ({todos.length})</span>
                      </button>
                    </div>

                    <button
                      type="button"
                      onClick={() => setSpoilerProtection(!spoilerProtection)}
                      className={`px-3 py-1.5 rounded-xl border text-xs font-medium flex items-center gap-1.5 transition-all ${
                        spoilerProtection
                          ? 'bg-amber-500/15 border-amber-500/40 text-amber-300'
                          : 'bg-gray-800 border-gray-700 text-gray-400 hover:text-white'
                      }`}
                    >
                      <Shield className="w-3.5 h-3.5" />
                      {spoilerProtection ? 'Spoilerskydd PÅ' : 'Spoilerskydd AV'}
                    </button>
                  </div>

                  {/* Toggle för Redigeringsläge */}
                  <div className="flex items-center gap-2">
                    <button
                      type="button"
                      onClick={() => setIsEditMode(!isEditMode)}
                      className={`px-3 py-1.5 rounded-xl border text-xs font-medium flex items-center gap-1.5 transition-all ${
                        isEditMode
                          ? 'bg-blue-600 border-blue-500 text-white'
                          : 'bg-gray-950 border-gray-800 text-gray-300 hover:text-white'
                      }`}
                    >
                      <Settings2 className="w-3.5 h-3.5" />
                      {isEditMode ? 'Klar med redigering' : 'Redigera lista'}
                    </button>
                  </div>
                </div>

                {/* Kort info om akt-spoilerskydd */}
                {spoilerProtection && majorActs.length > 1 && (
                  <div className="flex items-center justify-between gap-2 px-3 py-2 rounded-xl bg-gray-950/60 border border-gray-800/80 text-[11px] text-gray-400">
                    <span>
                      Aktiv akt: <strong className="text-gray-200">{activeMajorActName || 'Klar'}</strong> (alla uppdrag
                      i denna akt är synliga och kan bockas av i valfri ordning, medan framtida akter döljs).
                    </span>
                    {template.sourceUrl && (
                      <a
                        href={template.sourceUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="text-blue-400 hover:underline flex items-center gap-1 shrink-0"
                      >
                        <span>IGN Källa</span>
                        <ExternalLink className="w-3 h-3" />
                      </a>
                    )}
                  </div>
                )}

                {/* Lägg till nytt delmål (visas i redigeringsläge) */}
                {isEditMode && (
                  <div className="bg-gray-950/90 border border-blue-500/30 rounded-xl p-3.5 space-y-3">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span className="text-xs font-semibold text-blue-300 flex items-center gap-1.5">
                        <Pencil className="w-3.5 h-3.5" /> Redigeringsläge: Klicka på ett uppdrag för att ändra namn,
                        flytta med pilarna eller lägg till ett nytt steg nedan.
                      </span>
                      <button
                        type="button"
                        onClick={restoreMasterTemplate}
                        className="text-[11px] px-2.5 py-1 rounded-lg bg-gray-800 hover:bg-gray-700 text-gray-300 flex items-center gap-1"
                      >
                        <RotateCcw className="w-3 h-3" /> Återställ grundmall
                      </button>
                    </div>
                    <form onSubmit={handleAddCustomTodo} className="flex flex-col sm:flex-row gap-2">
                      <input
                        type="text"
                        placeholder="Akt / Grupp (t.ex. Akt 2, Sidouppdrag...)"
                        value={newTodoChapterGroup}
                        onChange={(e) => setNewTodoChapterGroup(e.target.value)}
                        className="sm:w-44 bg-gray-900 border border-gray-700 rounded-lg px-3 py-1.5 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-blue-500"
                      />
                      <input
                        type="text"
                        placeholder="Lägg till eget delmål eller sidouppdrag..."
                        value={newTodoTitle}
                        onChange={(e) => setNewTodoTitle(e.target.value)}
                        className="flex-1 bg-gray-900 border border-gray-700 rounded-lg px-3 py-1.5 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-blue-500"
                      />
                      <button
                        type="submit"
                        disabled={!newTodoTitle.trim()}
                        className="px-4 py-1.5 bg-blue-600 hover:bg-blue-500 disabled:opacity-40 text-white text-xs font-semibold rounded-lg flex items-center justify-center gap-1"
                      >
                        <Plus className="w-3.5 h-3.5" /> Lägg till
                      </button>
                    </form>
                  </div>
                )}

                {/* CHECKLISTAN (Grupperad eller Kronologisk) */}
                {viewMode === 'grouped' ? (
                  <div className="space-y-3">
                    {groups
                      .filter((g) => selectedGroupFilter === 'all' || selectedGroupFilter === g.name)
                      .map((group) => {
                        const isCollapsed = collapsedGroups.has(group.name);
                        const isCurrentPhase =
                          group.majorAct.toLowerCase() === (activeMajorActName || '').toLowerCase() &&
                          !group.isCompleted;

                        return (
                          <div
                            key={group.name}
                            className={`border rounded-xl overflow-hidden transition-all ${
                              isCurrentPhase
                                ? 'border-red-500/40 bg-gray-950/70'
                                : group.isCompleted
                                ? 'border-emerald-800/40 bg-emerald-950/5'
                                : 'border-gray-800 bg-gray-950/40'
                            }`}
                          >
                            {/* Grupp-header */}
                            <div
                              onClick={() => toggleGroupCollapse(group.name)}
                              className="p-3 bg-gray-900/80 hover:bg-gray-900 flex items-center justify-between cursor-pointer select-none"
                            >
                              <div className="flex items-center gap-2">
                                {isCollapsed ? (
                                  <ChevronRight className="w-4 h-4 text-gray-400" />
                                ) : (
                                  <ChevronDown className="w-4 h-4 text-gray-400" />
                                )}
                                <span className="text-sm font-bold text-white">{group.name}</span>
                                {isCurrentPhase && (
                                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 font-semibold uppercase border border-red-500/30">
                                    Aktiv akt
                                  </span>
                                )}
                                {group.isCompleted && (
                                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400 font-semibold border border-emerald-500/30 flex items-center gap-1">
                                    <Check className="w-2.5 h-2.5" /> Klar
                                  </span>
                                )}
                              </div>

                              <div className="flex items-center gap-2">
                                <span className="text-xs font-mono text-gray-400">
                                  {group.done} / {group.total}
                                </span>
                                <div className="w-16 bg-gray-800 rounded-full h-1.5 overflow-hidden hidden sm:block">
                                  <div
                                    className={`h-full rounded-full ${
                                      group.isCompleted ? 'bg-emerald-500' : 'bg-red-500'
                                    }`}
                                    style={{ width: `${group.total > 0 ? (group.done / group.total) * 100 : 0}%` }}
                                  />
                                </div>
                              </div>
                            </div>

                            {/* Gruppens rader */}
                            {!isCollapsed && (
                              <div className="divide-y divide-gray-800/60 border-t border-gray-800/80">
                                {group.items.map((item) => {
                                  const flatIndex = todos.findIndex((t) => t.id === item.id);
                                  const isHiddenBySpoiler = isItemHiddenBySpoiler(item, flatIndex);

                                  return (
                                    <div
                                      key={item.id}
                                      className={`p-3 flex items-center gap-3 transition-colors ${
                                        item.isDone
                                          ? 'bg-emerald-950/10 text-gray-400'
                                          : 'text-gray-200 hover:bg-gray-900/40'
                                      }`}
                                    >
                                      {/* Sorteringspilar (endast i redigeringsläge) */}
                                      {isEditMode && (
                                        <div className="flex flex-col items-center -space-y-1 shrink-0">
                                          <button
                                            type="button"
                                            onClick={() => moveTodoUp(flatIndex)}
                                            disabled={flatIndex === 0}
                                            className="p-0.5 text-gray-500 hover:text-white disabled:opacity-20"
                                          >
                                            <ChevronUp className="w-3.5 h-3.5" />
                                          </button>
                                          <button
                                            type="button"
                                            onClick={() => moveTodoDown(flatIndex)}
                                            disabled={flatIndex === todos.length - 1}
                                            className="p-0.5 text-gray-500 hover:text-white disabled:opacity-20"
                                          >
                                            <ChevronDown className="w-3.5 h-3.5" />
                                          </button>
                                        </div>
                                      )}

                                      {/* Checkbox */}
                                      <button
                                        type="button"
                                        onClick={() => toggleTodo(item.id)}
                                        className="shrink-0 text-gray-400 hover:text-white transition-colors"
                                      >
                                        {item.isDone ? (
                                          <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                                        ) : (
                                          <Circle
                                            className={`w-5 h-5 ${
                                              flatIndex === currentChapterIndex ? 'text-red-400' : 'text-gray-600'
                                            }`}
                                          />
                                        )}
                                      </button>

                                      {/* Innehåll */}
                                      <div className="flex-1 min-w-0">
                                        {isHiddenBySpoiler ? (
                                          <div className="flex items-center gap-2 text-xs text-gray-500 italic">
                                            <Shield className="w-3.5 h-3.5 text-amber-500/70" />
                                            <span>Delmål {flatIndex + 1} (Dold av spoilerskydd)</span>
                                            <button
                                              type="button"
                                              onClick={() => toggleReveal(item.id)}
                                              className="text-[11px] not-italic text-amber-400 hover:underline flex items-center gap-1 ml-1"
                                            >
                                              <Eye className="w-3 h-3" /> Visa
                                            </button>
                                          </div>
                                        ) : (
                                          <div className="flex flex-wrap items-center gap-2">
                                            {editingTodoId === item.id ? (
                                              <div className="flex flex-wrap items-center gap-1.5 flex-1">
                                                <input
                                                  type="text"
                                                  placeholder="Akt/Grupp"
                                                  value={editingTodoGroup}
                                                  onChange={(e) => setEditingTodoGroup(e.target.value)}
                                                  className="bg-gray-900 border border-gray-700 rounded px-2 py-1 text-xs text-white w-28"
                                                />
                                                <input
                                                  type="text"
                                                  value={editingTodoText}
                                                  onChange={(e) => setEditingTodoText(e.target.value)}
                                                  onKeyDown={(e) => {
                                                    if (e.key === 'Enter') saveEditing(item.id);
                                                    if (e.key === 'Escape') setEditingTodoId(null);
                                                  }}
                                                  autoFocus
                                                  className="bg-gray-900 border border-blue-500 rounded px-2 py-1 text-xs text-white flex-1 min-w-[140px]"
                                                />
                                                <button
                                                  type="button"
                                                  onClick={() => saveEditing(item.id)}
                                                  className="px-2.5 py-1 bg-blue-600 text-white rounded text-xs font-medium"
                                                >
                                                  Spara
                                                </button>
                                              </div>
                                            ) : (
                                              <span
                                                onClick={() => (isEditMode ? startEditing(item) : toggleTodo(item.id))}
                                                className={`text-sm font-medium cursor-pointer transition-colors flex items-center gap-1.5 ${
                                                  item.isDone ? 'line-through text-gray-500' : 'text-gray-200 hover:text-white'
                                                }`}
                                              >
                                                <span>{item.title}</span>
                                                {isEditMode && <Pencil className="w-3 h-3 text-blue-400" />}
                                              </span>
                                            )}

                                            {item.isOptional && (
                                              <span className="text-[10px] px-2 py-0.5 rounded bg-amber-500/15 text-amber-300 border border-amber-500/30">
                                                Frivilligt
                                              </span>
                                            )}

                                            {isEditMode && (
                                              <button
                                                type="button"
                                                onClick={() => toggleOptional(item.id)}
                                                className="text-[10px] px-2 py-0.5 rounded bg-gray-800 text-gray-400 hover:text-white"
                                              >
                                                {item.isOptional ? 'Gör obligatoriskt' : 'Gör frivilligt'}
                                              </button>
                                            )}

                                            {spoilerProtection && revealedIds.has(item.id) && (
                                              <button
                                                type="button"
                                                onClick={() => toggleReveal(item.id)}
                                                className="text-[11px] text-gray-500 hover:text-gray-300"
                                                title="Dölj igen"
                                              >
                                                <EyeOff className="w-3 h-3" />
                                              </button>
                                            )}
                                          </div>
                                        )}
                                      </div>

                                      {/* Ta bort-knapp (endast i redigeringsläge) */}
                                      {isEditMode && (
                                        <button
                                          type="button"
                                          onClick={() => removeTodo(item.id)}
                                          className="text-gray-500 hover:text-red-400 p-1 shrink-0"
                                          title="Ta bort steg"
                                        >
                                          <Trash2 className="w-3.5 h-3.5" />
                                        </button>
                                      )}
                                    </div>
                                  );
                                })}
                              </div>
                            )}
                          </div>
                        );
                      })}
                  </div>
                ) : (
                  /* KRONOLOGISK VY */
                  <div className="border border-gray-800 rounded-xl overflow-hidden bg-gray-950/40 divide-y divide-gray-800/60">
                    {todos.map((item, flatIndex) => {
                      const isHiddenBySpoiler = isItemHiddenBySpoiler(item, flatIndex);
                      return (
                        <div
                          key={item.id}
                          className={`p-3 flex items-center gap-3 transition-colors ${
                            item.isDone ? 'bg-emerald-950/10 text-gray-400' : 'text-gray-200 hover:bg-gray-900/40'
                          }`}
                        >
                          <span className="text-[11px] font-mono text-gray-500 w-5 text-center shrink-0">
                            {flatIndex + 1}
                          </span>
                          <button
                            type="button"
                            onClick={() => toggleTodo(item.id)}
                            className="shrink-0 text-gray-400 hover:text-white"
                          >
                            {item.isDone ? (
                              <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                            ) : (
                              <Circle className="w-5 h-5 text-gray-600" />
                            )}
                          </button>
                          <div className="flex-1 min-w-0">
                            {isHiddenBySpoiler ? (
                              <div className="flex items-center gap-2 text-xs text-gray-500 italic">
                                <Shield className="w-3.5 h-3.5 text-amber-500/70" />
                                <span>Delmål {flatIndex + 1} (Dold av spoilerskydd)</span>
                                <button
                                  type="button"
                                  onClick={() => toggleReveal(item.id)}
                                  className="text-[11px] not-italic text-amber-400 hover:underline flex items-center gap-1 ml-1"
                                >
                                  <Eye className="w-3 h-3" /> Visa
                                </button>
                              </div>
                            ) : (
                              <div className="flex flex-wrap items-center gap-2">
                                {item.chapterGroup && (
                                  <span className="text-[10px] px-2 py-0.5 rounded bg-gray-800 text-gray-400">
                                    {item.chapterGroup}
                                  </span>
                                )}
                                <span
                                  onClick={() => toggleTodo(item.id)}
                                  className={`text-sm font-medium cursor-pointer ${
                                    item.isDone ? 'line-through text-gray-500' : 'text-gray-200'
                                  }`}
                                >
                                  {item.title}
                                </span>
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            )}
          </div>
        </section>
      </main>
    </div>
  );
}
