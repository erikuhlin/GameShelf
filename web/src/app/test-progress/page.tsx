'use client';

import React, { useState, useEffect, useMemo } from 'react';
import Link from 'next/link';
import {
  CheckCircle2,
  Circle,
  Trophy,
  Eye,
  EyeOff,
  Sparkles,
  Plus,
  Trash2,
  Clock,
  Shield,
  ListChecks,
  Search,
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
  Copy,
  Check,
  Sliders,
  Flame,
  ExternalLink,
  Pencil,
  FileText,
  Info,
  ArrowUpDown,
  Tag,
  Star,
  CheckCheck,
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

const PRESET_GAMES = [
  { name: 'Kingdom Come: Deliverance', displayName: 'Kingdom Come I', type: 'main_quests', icon: Layers, tag: '27 Huvuduppdrag (Böhmen)', hltb: 41 },
  { name: 'Kingdom Come: Deliverance II', displayName: 'Kingdom Come II', type: 'main_quests', icon: Layers, tag: '17 Uppdrag (Trosky & Kuttenberg)', hltb: 50 },
  { name: 'Resident Evil 4', displayName: 'Resident Evil 4', type: 'chapters', icon: BookOpen, tag: '16 Kapitel (1:1 Byn, Slottet, Ön)', hltb: 16 },
  { name: 'Resident Evil 2', displayName: 'Resident Evil 2', type: 'chapters', icon: BookOpen, tag: '12 Zoner (R.P.D., Kloakerna, NEST)', hltb: 9 },
  { name: 'The Last of Us Part I', displayName: 'The Last of Us Part I', type: 'chapters', icon: BookOpen, tag: '12 Kapitel & 4 Årstider', hltb: 15 },
  { name: 'Silent Hill 2', displayName: 'Silent Hill 2 (Remake)', type: 'chapters', icon: BookOpen, tag: '14 Zoner & Skräck', hltb: 16 },
  { name: '007 First Light', displayName: '007 First Light', type: 'chapters', icon: BookOpen, tag: '10 Kapitel (18 Uppdrag)', hltb: 14 },
  { name: 'Cyberpunk 2077', displayName: 'Cyberpunk 2077', type: 'main_quests', icon: Layers, tag: '26 Huvuduppdrag (Main Jobs 1:1)', hltb: 25 },
  { name: 'The Witcher 3: Wild Hunt', displayName: 'The Witcher 3', type: 'main_quests', icon: Layers, tag: '41 Storyquests (Prolog till Final)', hltb: 52 },
  { name: 'Baldur\'s Gate 3', displayName: 'Baldur\'s Gate 3', type: 'main_quests', icon: Layers, tag: '20 Huvuddelmål (Akt 1, 2, 3)', hltb: 65 },
  { name: 'Super Mario Odyssey', displayName: 'Super Mario Odyssey', type: 'worlds', icon: Globe, tag: '17 Riken (Cap till Darker Side)', hltb: 13 },
  { name: 'Elden Ring', displayName: 'Elden Ring', type: 'bosses', icon: Skull, tag: '14 Huvudbossar (1:1)', hltb: 58 },
  { name: 'Rocket League', displayName: 'Rocket League', type: 'none', icon: Gamepad2, tag: 'Ej linjärt / MP', hltb: 0 },
];

export default function TestProgressPage() {
  const [selectedGameName, setSelectedGameName] = useState<string>('Kingdom Come: Deliverance II');
  const [activeStep1Tab, setActiveStep1Tab] = useState<'presets' | 'paste' | 'search'>('presets');
  const [searchInput, setSearchInput] = useState<string>('');
  const [guideUrlInput, setGuideUrlInput] = useState<string>('');
  const [rawTextInput, setRawTextInput] = useState<string>('');
  const [rawTextGameTitle, setRawTextGameTitle] = useState<string>('Alan Wake 2');
  const [geminiApiKey, setGeminiApiKey] = useState<string>('');
  const [showApiKeyInput, setShowApiKeyInput] = useState<boolean>(false);

  // Detaljnivå och AI-tvingande
  const [granularity, setGranularity] = useState<Granularity>('standard');
  const [forceAI, setForceAI] = useState<boolean>(false);

  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [template, setTemplate] = useState<LoadedTemplate | null>(null);

  // Användarens aktiva bocklista (motsvarar Game.todos i iOS/web)
  const [todos, setTodos] = useState<ActiveTodo[]>([]);
  // Grundmallen sparad för att användaren när som helst ska kunna "Återställa till grundmall"
  const [masterTemplateTodos, setMasterTemplateTodos] = useState<ActiveTodo[]>([]);
  const [estimatedHours, setEstimatedHours] = useState<number>(16);

  // Inställningar för test
  const [spoilerProtection, setSpoilerProtection] = useState<boolean>(true);
  const [revealedIds, setRevealedIds] = useState<Set<string>>(new Set());
  const [newTodoTitle, setNewTodoTitle] = useState<string>('');
  const [newTodoChapterGroup, setNewTodoChapterGroup] = useState<string>('');
  const [copiedJson, setCopiedJson] = useState<boolean>(false);

  // Visningsläge: Grupperad per Akt/Tråd (RPG-anpassat) eller platt kronologisk
  const [viewMode, setViewMode] = useState<'grouped' | 'chronological'>('grouped');
  const [collapsedGroups, setCollapsedGroups] = useState<Set<string>>(new Set());
  const [selectedGroupFilter, setSelectedGroupFilter] = useState<string>('all');

  const toggleGroupCollapse = (groupName: string) => {
    setCollapsedGroups((prev) => {
      const next = new Set(prev);
      if (next.has(groupName)) next.delete(groupName);
      else next.add(groupName);
      return next;
    });
  };

  // Inline-redigering av delmål
  const [editingTodoId, setEditingTodoId] = useState<string | null>(null);
  const [editingTodoText, setEditingTodoText] = useState<string>('');
  const [editingTodoGroup, setEditingTodoGroup] = useState<string>('');

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

  // Flytta delmål uppåt
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

  // Flytta delmål nedåt
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

  // Växla om ett delmål är frivilligt
  const toggleOptional = (id: string) => {
    setTodos((prev) =>
      prev.map((t) => (t.id === id ? { ...t, isOptional: !t.isOptional } : t))
    );
  };

  // Återställ listan till den ursprungliga grundmallen
  const restoreMasterTemplate = () => {
    if (masterTemplateTodos.length > 0) {
      setTodos(masterTemplateTodos.map((t) => ({ ...t, isDone: false })));
    }
  };

  // Fyll i exempel för Alan Wake 2
  const fillAlanWakeExample = () => {
    setRawTextGameTitle('Alan Wake 2');
    setRawTextInput(
`Chapter 1: The Cult (Return 1)
Chapter 2: The Heart (Return 2)
Chapter 3: Local Girl (Return 3)
Chapter 4: No Chance (Return 4)
Chapter 5: Old Gods (Return 5)
Chapter 6: Scratch (Return 6)
Chapter 7: Summoning (Return 7)
Chapter 8: Deerfest (Return 8)
Chapter 9: Come Home (Return 9)
Initiation 1: Victims
Initiation 2: Casey
Initiation 3: Haunting
Initiation 4: We Sing
Initiation 5: Room 665
Initiation 6: Return
Initiation 7: Masks
Initiation 8: Zane's Film
Initiation 9: Gone`
    );
  };

  // Räkna antal upptäckta rader i råtext i realtid
  const detectedItemsCount = useMemo(() => {
    return rawTextInput
      .split('\n')
      .map((l) => l.trim())
      .filter((line) => {
        if (line.length < 2 || line.length > 140) return false;
        if (/^(cookie|copyright|privacy|advertisement|follow us|subscribe|sign up)/i.test(line)) return false;
        return true;
      }).length;
  }, [rawTextInput]);

  // Ladda API-nyckel från localStorage om den sparats tidigare
  useEffect(() => {
    const savedKey = localStorage.getItem('gameshelf_gemini_key');
    if (savedKey) setGeminiApiKey(savedKey);
  }, []);

  const saveApiKey = (key: string) => {
    setGeminiApiKey(key);
    localStorage.setItem('gameshelf_gemini_key', key);
  };

  // Applicera mall på sidans tillstånd
  const applyTemplate = (data: LoadedTemplate, title: string) => {
    setTemplate(data);
    setSelectedGameName(data.gameTitle || title);
    setSelectedGroupFilter('all');
    setCollapsedGroups(new Set());

    const initialTodos: ActiveTodo[] = (data.items || []).map((item: TemplateItem, index: number) => ({
      id: item.id || `todo-${index}`,
      title: item.title,
      chapterGroup: item.chapterGroup,
      isDone: false,
      order: item.order || index + 1,
      isOptional: item.isOptional,
    }));
    setTodos(initialTodos);
    setMasterTemplateTodos(initialTodos);

    const preset = PRESET_GAMES.find(
      (p) => p.name.toLowerCase() === title.toLowerCase() || p.displayName.toLowerCase() === title.toLowerCase()
    );
    if (preset) {
      setEstimatedHours(preset.hltb);
    } else {
      setEstimatedHours(20);
    }
  };

  const [loadingStatus, setLoadingStatus] = useState<string>('');

  // Anropa Google Gemini direkt från webbläsaren med IGN Walkthrough som källa
  const generateDirectlyWithGemini = async (
    title: string,
    key: string,
    gran: Granularity,
    ignLookup?: { found: boolean; ignUrl: string; extractedText: string }
  ): Promise<LoadedTemplate> => {
    const cleanKey = key.trim();
    const hasIgnText = Boolean(ignLookup?.found && ignLookup?.extractedText);
    const ignSourceUrl = ignLookup?.ignUrl || `https://www.ign.com/wikis/${title.toLowerCase().replace(/[^a-z0-9]+/g, '-')}/Walkthrough`;

    const buildPrompt = (includeScrapedText: boolean) =>
      includeScrapedText && hasIgnText
        ? `You are building the complete 1:1 progression checklist for the video game "${title}" based on IGN's official Walkthrough (${ignSourceUrl}).

Below is the extracted data from IGN's Walkthrough page.

STRICT EXTRACTION RULES:
1. COMPLETE 1:1 WALKTHROUGH LIST (NEVER EMPTY):
   - Extract every single chapter, main quest, or walkthrough area in chronological order (1:1).
   - NEVER combine two chapters, areas, or quests into one item.
   - CRITICAL: If the extracted IGN page snippet below only contains the overview/intro text (because IGN's sidebar menu was collapsed), you MUST still output the COMPLETE 1:1 list of all chapters / main quests / areas from IGN's "${title}" Walkthrough from start to finish (e.g., for Dark Souls: every walkthrough area from Northern Undead Asylum to Kiln of the First Flame). The "items" array MUST NOT be empty!
2. ONLY WALKTHROUGH STEPS:
   - Exclude non-walkthrough wiki sections such as "Weapons", "Armor", "Collectibles", "Side Quests", "Cheats", "Trophies", "Characters", "Tips and Tricks".
3. OFFICIAL ENGLISH TITLES:
   - Keep the exact English chapter/quest/area titles from IGN's walkthrough. Do not translate them to Swedish.
4. ACT / REGION GROUPING:
   - Put the overarching Act, Phase, or Region in "chapterGroup" (e.g. "Act 1", "Act 2", "Early Game", "Lordvessel Areas") and the specific chapter/quest/area in "title".
5. Output ONLY valid JSON matching this schema:
{
  "gameTitle": "${title}",
  "hasLinearProgression": true,
  "progressionType": "chapters" | "acts" | "main_quests" | "bosses" | "worlds" | "none",
  "summary": "Kort svensk sammanfattning baserad på IGN:s walkthrough",
  "items": [
    {
      "id": "1",
      "title": "Exact English Chapter / Quest / Area Title from IGN",
      "order": 1,
      "chapterGroup": "Act or Phase",
      "description": "Kort info",
      "isOptional": false
    }
  ]
}

--- IGN WALKTHROUGH DATA ---
${ignLookup!.extractedText}
--- END IGN WALKTHROUGH DATA ---`
        : `Provide the COMPLETE 1:1 main story walkthrough list (all chapters / main quests / walkthrough areas in chronological order) for the video game "${title}" following IGN's official Wiki Walkthrough (${ignSourceUrl}).

STRICT RULES:
1. COMPLETE 1:1 LIST (NEVER EMPTY): Every single chapter, main quest, or walkthrough area on IGN's Walkthrough for "${title}" must be its own separate item in "items". NEVER combine multiple chapters or quests into one item, and NEVER return an empty "items" array for a story/progression game.
2. ONLY WALKTHROUGH STEPS: Exclude side quests, collectibles, weapons, trophies, and general tips.
3. OFFICIAL ENGLISH TITLES: Keep exact English titles from IGN.
4. ACT / REGION GROUPING: Put the Act, Phase, or Character arc in "chapterGroup" and the specific chapter/quest/area name in "title".
5. Output ONLY valid JSON matching this schema:
{
  "gameTitle": "${title}",
  "hasLinearProgression": true,
  "progressionType": "chapters" | "acts" | "main_quests" | "bosses" | "worlds" | "none",
  "summary": "Kort svensk sammanfattning baserad på IGN:s walkthrough",
  "items": [
    {
      "id": "1",
      "title": "Exact English Chapter / Quest / Area Title from IGN",
      "order": 1,
      "chapterGroup": "Act or Phase",
      "description": "Kort info",
      "isOptional": false
    }
  ]
}`;

    // 1. Fråga Google efter aktiva modeller för denna API-nyckel
    let candidateModels = ['gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-3.8-flash'];
    try {
      const listRes = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(cleanKey)}`
      );
      if (!listRes.ok) {
        const errJson = await listRes.json().catch(() => null);
        throw new Error(errJson?.error?.message || `Google API-fel (${listRes.status})`);
      }
      const listData = await listRes.json();
      if (Array.isArray(listData.models)) {
        const supported = listData.models
          .filter((m: any) => m.supportedGenerationMethods?.includes('generateContent'))
          .map((m: any) => (m.name as string).replace(/^models\//, ''))
          .filter((n: string) => !n.includes('tts') && !n.includes('audio') && !n.includes('embed') && !n.includes('imagen') && !n.includes('aqa'));

        const getVer = (n: string): number => {
          const match = n.match(/gemini[^\d]*(\d+(?:\.\d+)?)/i);
          return match ? parseFloat(match[1]) : 0;
        };

        const flash = supported.filter((m: string) => m.includes('flash')).sort((a: string, b: string) => getVer(b) - getVer(a));
        const others = supported.filter((m: string) => !m.includes('flash')).sort((a: string, b: string) => getVer(b) - getVer(a));
        const unique = Array.from(new Set([...flash, ...others]));
        if (unique.length > 0) candidateModels = unique.slice(0, 2);
      }
    } catch (listErr: any) {
      if (listErr.message?.includes('API key')) throw listErr;
    }

    const callModelAndParse = async (modelName: string, promptText: string, useGoogleSearch: boolean) => {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${modelName}:generateContent?key=${encodeURIComponent(cleanKey)}`;
      const bodyPayload: any = {
        contents: [{ parts: [{ text: promptText }] }],
        generationConfig: {
          temperature: 0.1,
          maxOutputTokens: 8192,
        },
      };
      if (useGoogleSearch) {
        bodyPayload.tools = [{ google_search: {} }];
      } else {
        bodyPayload.generationConfig.responseMimeType = 'application/json';
      }

      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(bodyPayload),
      });

      if (!response.ok) {
        const errJson = await response.json().catch(() => null);
        throw new Error(errJson?.error?.message || `Modell ${modelName} (${response.status})`);
      }

      const data = await response.json();
      const parts = data.candidates?.[0]?.content?.parts || [];
      const textContent = parts.map((p: any) => p.text || '').join('\n').trim();
      if (!textContent) throw new Error(`Modell ${modelName} returnerade tomt svar.`);

      let groundedIgnUrl = ignSourceUrl;
      const chunks = data.candidates?.[0]?.groundingMetadata?.groundingChunks || [];
      for (const chunk of chunks) {
        const uri = chunk?.web?.uri;
        if (typeof uri === 'string' && uri.includes('ign.com/wikis/')) {
          groundedIgnUrl = uri;
          break;
        }
      }

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

      return { parsed, rawItems, groundedIgnUrl };
    };

    let lastError: Error | null = null;
    for (const modelName of candidateModels) {
      try {
        // Försök 1: Med hämtad IGN-data (eller Google Search om IGN-data saknades)
        let result = await callModelAndParse(modelName, buildPrompt(true), !hasIgnText).catch(() => null);

        // Försök 2: Om IGN-sidans råtext bara innehöll en intro-sammanfattning och items blev tom,
        // hämta hela IGN Walkthrough-listan med Google Search / direkt IGN-struktur!
        if (!result || (result.rawItems.length === 0 && result.parsed?.hasLinearProgression !== false)) {
          result = await callModelAndParse(modelName, buildPrompt(false), true).catch(() => null);
        }

        // Försök 3: Utan google_search-tool ifall modellen inte stöder search-grounding i JSON-läge
        if (!result || (result.rawItems.length === 0 && result.parsed?.hasLinearProgression !== false)) {
          result = await callModelAndParse(modelName, buildPrompt(false), false);
        }

        const { parsed, rawItems, groundedIgnUrl } = result;

        return {
          gameTitle: parsed.gameTitle || title,
          hasLinearProgression: parsed.hasLinearProgression !== undefined ? Boolean(parsed.hasLinearProgression) : rawItems.length > 0,
          progressionType: parsed.progressionType || (rawItems.length > 0 ? 'chapters' : 'none'),
          granularity: gran,
          summary: parsed.summary || '',
          items: rawItems.map((it: any, idx: number) => ({
            id: String(it.id || idx + 1),
            title: String(it.title || it.name || `Delmål ${idx + 1}`),
            order: Number(it.order || idx + 1),
            chapterGroup: it.chapterGroup || it.act || it.region,
            description: it.description,
            isOptional: Boolean(it.isOptional),
          })),
          source: 'scraped_guide',
          sourceUrl: groundedIgnUrl,
          modelUsed: modelName,
        };
      } catch (err: any) {
        lastError = err;
      }
    }

    throw lastError || new Error('Kunde inte generera progression från IGN med Gemini.');
  };

  // Hämta mall för ett spel (Verifierad mall -> annars IGN Walkthrough + AI)
  const loadGameTemplate = async (
    title: string,
    currentGranularity: Granularity = granularity,
    shouldForceAI: boolean = forceAI,
    customGuideUrl?: string
  ) => {
    setIsLoading(true);
    setLoadingStatus(`Söker i verifierade mallar eller på IGN Walkthrough för "${title}"...`);
    setErrorMsg(null);
    setRevealedIds(new Set());

    const activeUrl = customGuideUrl !== undefined ? customGuideUrl : guideUrlInput;

    try {
      // 1. Fråga servern:
      // - Om spelet finns som verifierad mall (och forceAI är false): returneras direkt på ~20ms.
      // - Annars: går servern in på IGN:s Walkthrough-sida i bakgrunden och hämtar kapitellistan!
      setLoadingStatus(`Steg 1/2: Går in på IGN:s Walkthrough-sida för "${title}"...`);
      const res = await fetch('/api/games/progress-template', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          gameTitle: title,
          guideUrl: activeUrl.trim() || undefined,
          granularity: currentGranularity,
          forceAI: shouldForceAI,
          fetchIgnOnly: true,
        }),
      });

      let ignLookup: { found: boolean; ignUrl: string; extractedText: string } | undefined;

      if (res.ok) {
        const data = await res.json();
        // Om det var en kurerad mall:
        if (data && data.items && data.items.length > 0) {
          applyTemplate(data, title);
          return;
        }
        // Om servern returnerade IGN Walkthrough-data:
        if (data && data.ignLookup) {
          ignLookup = data.ignLookup;
        }
      }

      // 2. Använd Gemini AI för att omvandla IGN:s walkthrough-lista till steg i appen
      if (geminiApiKey.trim()) {
        if (ignLookup?.found) {
          setLoadingStatus(`Steg 2/2: Hämtade ${ignLookup.ignUrl} – extraherar kapitellistan med AI...`);
        } else {
          setLoadingStatus(`Steg 2/2: Söker upp IGN Walkthrough för "${title}" med Gemini AI...`);
        }
        const aiTemplate = await generateDirectlyWithGemini(
          title,
          geminiApiKey.trim(),
          currentGranularity,
          ignLookup
        );
        applyTemplate(aiTemplate, title);
        return;
      }

      // 3. Om ingen mall finns och ingen API-nyckel angetts:
      setErrorMsg(
        `Ingen förberedd mall hittades för "${title}". Ange din Gemini API-nyckel under knappen "Konfigurera Gemini AI-nyckel" så hämtar vi automatiskt kapitellistan från IGN:s Walkthrough (${ignLookup?.ignUrl || 'ign.com/wikis'})!`
      );
    } catch (err: any) {
      setErrorMsg(err.message || 'Kunde inte hämta progression.');
    } finally {
      setIsLoading(false);
      setLoadingStatus('');
    }
  };

  // Parsa rå text direkt (100% oberoende av nätverk, blixtsnabbt)
  const parseFromRawText = (text: string, title: string) => {
    setIsLoading(true);
    setErrorMsg(null);
    setRevealedIds(new Set());

    const lines = text
      .split('\n')
      .map((l) => l.trim())
      .filter(Boolean);

    const items: ActiveTodo[] = [];
    let order = 1;

    for (const line of lines) {
      if (line.length < 2 || line.length > 140) continue;
      if (/^(cookie|copyright|privacy|advertisement|follow us|subscribe|sign up)/i.test(line)) continue;

      const cleaned = line
        .replace(/^[\d]+[\.\)\:\-]\s*/, '')
        .replace(/^(kapitel|chapter|akt|act|mission|quest)\s*\d+[\:\.\-]?\s*/i, '')
        .replace(/^[-*•]\s*/, '')
        .trim();

      if (cleaned.length >= 2) {
        items.push({
          id: `custom-${order}`,
          title: cleaned,
          order: order,
          isDone: false,
        });
        order++;
      }
    }

    if (items.length === 0) {
      setErrorMsg('Kunde inte hitta några rader att skapa delmål från. Klistra in en lista med ett kapitel eller uppdrag per rad.');
      setIsLoading(false);
      return;
    }

    const gameTitle = title.trim() || 'Eget spel';
    setTemplate({
      gameTitle,
      hasLinearProgression: true,
      progressionType: 'chapters',
      summary: `Skapad direkt från inklistrad text (${items.length} delmål).`,
      items: items.map((it) => ({
        id: it.id,
        title: it.title,
        order: it.order,
      })),
      source: 'custom',
    });
    setSelectedGameName(gameTitle);
    setTodos(items);
    setMasterTemplateTodos(items);
    setEstimatedHours(Math.max(10, Math.round(items.length * 1.5)));
    setIsLoading(false);
  };

  // Ladda initialt spel vid start
  useEffect(() => {
    loadGameTemplate('Kingdom Come: Deliverance II');
  }, []);

  // Byt detaljnivå och ladda om
  const handleGranularityChange = (newGranularity: Granularity) => {
    setGranularity(newGranularity);
    loadGameTemplate(selectedGameName, newGranularity, forceAI);
  };

  // Beräkningar för framsteg
  const totalCount = todos.length;
  const doneCount = todos.filter((t) => t.isDone).length;
  const progressPercent = totalCount > 0 ? Math.round((doneCount / totalCount) * 100) : 0;

  // Automatisk Story-milstolpe (matchar GameStoryProgress i iOS)
  const calculatedStoryMilestone = useMemo(() => {
    if (totalCount === 0) return 'Ej tillämpligt';
    if (doneCount === 0) return 'Inte påbörjat';
    if (doneCount === totalCount) return '🏆 Klar';
    if (progressPercent >= 75) return '🔥 Närmar mig slutet';
    if (progressPercent >= 35) return '⚡ Mitt i det';
    return '🌱 Precis börjat';
  }, [doneCount, totalCount, progressPercent]);

  // Återstående speltid i timmar
  const estimatedRemainingHours = useMemo(() => {
    if (estimatedHours <= 0 || totalCount === 0) return null;
    const remainingFraction = (totalCount - doneCount) / totalCount;
    return Math.round(estimatedHours * remainingFraction * 10) / 10;
  }, [estimatedHours, totalCount, doneCount]);

  // Hitta index för det aktuella (första oklara) kapitlet för spoilerskydd
  const currentChapterIndex = useMemo(() => {
    const idx = todos.findIndex((t) => !t.isDone);
    return idx === -1 ? todos.length : idx;
  }, [todos]);

  // Hjälpfunktion för att plocka ut den överordnade Huvudakten (t.ex. "Akt 2 (Panam)" -> "Akt 2")
  const getMajorAct = (chapterGroup?: string): string => {
    if (!chapterGroup) return 'Huvudstory';
    const match = chapterGroup.match(/^(Akt\s*\d+|Prolog|Epilog|Final|Byn|Slottet|Ön|Sommar|Höst|Vinter|Vår)/i);
    if (match) return match[1].trim();
    return chapterGroup.split('(')[0].trim() || 'Huvudstory';
  };

  // Grupperade delmål per Akt / Zon / Tråd (undergrupper)
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

  // Lista över alla unika Huvudakter i ordning (t.ex. ['Prolog', 'Akt 1', 'Akt 2', 'Akt 3', 'Final'])
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

  // Index för den aktiva HUVUDAKTEN (den första huvudakten med oklara uppdrag)
  const activeMajorActIndex = useMemo(() => {
    const idx = majorActs.findIndex((a) => !a.isCompleted);
    return idx === -1 ? majorActs.length : idx;
  }, [majorActs]);

  const activeMajorActName = useMemo(() => {
    return activeMajorActIndex < majorActs.length ? majorActs[activeMajorActIndex]?.name : null;
  }, [majorActs, activeMajorActIndex]);

  // Smart Spoilerskydd per Huvudakt (precis som användaren föreslog):
  // Om du har klarat Akt 1 visas ALLA uppdrag i hela Akt 2 (både Evelyn, Panam, Takemura och Voodoo Boys)!
  // Först Akt 3 och Finalen hålls dolda bakom spoilerskydd tills du är klar med hela Akt 2.
  const isItemHiddenBySpoiler = (item: ActiveTodo, indexInFlatList: number) => {
    if (!spoilerProtection) return false;
    if (item.isDone) return false;
    if (revealedIds.has(item.id)) return false;

    if (majorActs.length > 0 && activeMajorActIndex !== -1) {
      const itemMajorAct = getMajorAct(item.chapterGroup);
      const actIdx = majorActs.findIndex((a) => a.name.toLowerCase() === itemMajorAct.toLowerCase());
      if (actIdx !== -1) {
        // Om uppdraget tillhör nuvarande huvudakt eller en tidigare huvudakt: SYNLIGT!
        if (actIdx <= activeMajorActIndex) return false;
        // Om uppdraget tillhör en framtida huvudakt: DOLD AV SPOILERSKYDD!
        return true;
      }
    }

    return indexInFlatList > currentChapterIndex;
  };

  // Filtrerade delmål för visning
  const filteredTodos = useMemo(() => {
    if (selectedGroupFilter === 'all') return todos;
    return todos.filter((t) => (t.chapterGroup || 'Huvudstory') === selectedGroupFilter);
  }, [todos, selectedGroupFilter]);

  // Bocka av / på ett delmål
  const toggleTodo = (id: string) => {
    setTodos((prev) =>
      prev.map((t) => (t.id === id ? { ...t, isDone: !t.isDone } : t))
    );
  };

  // Snabb-knapp: Bocka av nästa delmål
  const checkNextTodo = () => {
    const firstUnchecked = todos.find((t) => !t.isDone);
    if (firstUnchecked) {
      toggleTodo(firstUnchecked.id);
    }
  };

  // Återställ alla
  const resetAll = () => {
    setTodos((prev) => prev.map((t) => ({ ...t, isDone: false })));
  };

  // Lägg till eget delmål
  const handleAddCustomTodo = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTodoTitle.trim()) return;
    const newItem: ActiveTodo = {
      id: `custom-${Date.now()}`,
      title: newTodoTitle.trim(),
      chapterGroup: newTodoChapterGroup.trim() || undefined,
      isDone: false,
      order: todos.length + 1,
    };
    setTodos([...todos, newItem]);
    setNewTodoTitle('');
    setNewTodoChapterGroup('');
  };

  // Ta bort delmål
  const removeTodo = (id: string) => {
    setTodos((prev) => prev.filter((t) => t.id !== id));
  };

  // Avtäcka ett dolt kapitel
  const toggleReveal = (id: string) => {
    setRevealedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  // Kopiera Gameshelf JSON
  const copyJson = () => {
    const output = JSON.stringify(
      todos.map((t) => ({
        id: t.id,
        title: t.title,
        chapterGroup: t.chapterGroup,
        isDone: t.isDone,
      })),
      null,
      2
    );
    navigator.clipboard.writeText(output);
    setCopiedJson(true);
    setTimeout(() => setCopiedJson(false), 2000);
  };

  return (
    <div className="min-h-screen bg-[#0d0e12] text-gray-100 p-4 sm:p-8 font-sans">
      <div className="max-w-4xl mx-auto space-y-8">
        {/* Header / Intro */}
        <header className="border-b border-gray-800 pb-6">
          <div className="flex items-center justify-between mb-3">
            <Link
              href="/"
              className="inline-flex items-center gap-1.5 text-xs text-gray-400 hover:text-white transition-colors py-1 px-2.5 rounded-lg bg-gray-900 border border-gray-800"
            >
              ← Tillbaka till Gameshelf
            </Link>
            <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wider text-red-500">
              <Sparkles className="w-4 h-4" />
              Gameshelf Lab • Prototyp
            </div>
          </div>
          <h1 className="text-2xl sm:text-4xl font-bold tracking-tight text-white mb-2">
            Spelframsteg via Kapitel & Quests
          </h1>
          <p className="text-gray-400 text-sm sm:text-base leading-relaxed">
            Ett experimentellt gränssnitt för att testa hur Gameshelf kan hämta och spåra spelets faktiska handling (kapitel, akter, huvuduppdrag och bossar) istället för att enbart förlita sig på loggad tid.
          </p>
        </header>

        {/* Steg 1: Välj / Importera / Sök Spel */}
        <section className="bg-gray-900/60 border border-gray-800 rounded-2xl p-5 sm:p-6 space-y-5">
          <div className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-800 pb-3">
            <div>
              <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-200 flex items-center gap-2">
                <span className="w-5 h-5 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center text-xs font-bold">1</span>
                Välj spelmall eller importera egen guide
              </h2>
              <p className="text-xs text-gray-400 mt-0.5">
                Välj bland förberedda verifierade spel, eller klistra in en rå lista från valfri walkthrough.
              </p>
            </div>

            {/* Huvudflikar för Steg 1 */}
            <div className="inline-flex rounded-xl bg-gray-950 p-1 border border-gray-800 text-xs">
              <button
                type="button"
                onClick={() => setActiveStep1Tab('presets')}
                className={`px-3 py-1.5 rounded-lg font-medium transition flex items-center gap-1.5 ${
                  activeStep1Tab === 'presets'
                    ? 'bg-red-600 text-white shadow-sm'
                    : 'text-gray-400 hover:text-white'
                }`}
              >
                <Shield className="w-3.5 h-3.5" />
                <span>Verifierade mallar (12 st)</span>
              </button>
              <button
                type="button"
                onClick={() => setActiveStep1Tab('paste')}
                className={`px-3 py-1.5 rounded-lg font-medium transition flex items-center gap-1.5 ${
                  activeStep1Tab === 'paste'
                    ? 'bg-blue-600 text-white shadow-sm'
                    : 'text-gray-400 hover:text-white'
                }`}
              >
                <FileText className="w-3.5 h-3.5" />
                <span>Klistra in guide / lista</span>
              </button>
              <button
                type="button"
                onClick={() => setActiveStep1Tab('search')}
                className={`px-3 py-1.5 rounded-lg font-medium transition flex items-center gap-1.5 ${
                  activeStep1Tab === 'search'
                    ? 'bg-purple-600 text-white shadow-sm'
                    : 'text-gray-400 hover:text-white'
                }`}
              >
                <Search className="w-3.5 h-3.5" />
                <span>Sök (IGN + AI)</span>
              </button>
            </div>
          </div>

          {/* FLIK 1: Verifierade mallar */}
          {activeStep1Tab === 'presets' && (
            <div className="space-y-3">
              <div className="flex items-center justify-between text-xs text-gray-400 bg-gray-950/60 p-2.5 rounded-xl border border-gray-800/80">
                <span className="flex items-center gap-1.5 text-gray-300 font-medium">
                  <Shield className="w-4 h-4 text-emerald-400" />
                  Officiellt kurerade och verifierade spel i Gameshelf
                </span>
                <span className="text-[11px] text-gray-500">Laddas omedelbart • 0 ms fördröjning</span>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2.5">
                {PRESET_GAMES.map((p) => {
                  const Icon = p.icon;
                  const isSelected = selectedGameName.toLowerCase() === p.name.toLowerCase() || selectedGameName.toLowerCase() === p.displayName.toLowerCase();
                  return (
                    <button
                      key={p.name}
                      onClick={() => {
                        setSelectedGameName(p.name);
                        loadGameTemplate(p.name, granularity, forceAI);
                      }}
                      className={`p-3 rounded-xl border text-left transition-all flex flex-col justify-between ${
                        isSelected
                          ? 'bg-red-500/15 border-red-500 text-white shadow-lg shadow-red-500/10'
                          : 'bg-gray-950/60 border-gray-800 text-gray-300 hover:bg-gray-800/50 hover:border-gray-700'
                      }`}
                    >
                      <div className="flex items-center justify-between mb-2">
                        <Icon className={`w-4 h-4 ${isSelected ? 'text-red-400' : 'text-gray-400'}`} />
                        {p.type !== 'none' ? (
                          <span className="text-[9px] px-1.5 py-0.5 rounded bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 font-medium flex items-center gap-0.5">
                            <Shield className="w-2.5 h-2.5" /> Verifierad
                          </span>
                        ) : (
                          <span className="text-[9px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-400">
                            Ej linjär
                          </span>
                        )}
                      </div>
                      <span className="text-xs font-semibold line-clamp-1">{p.displayName}</span>
                      <div className="flex items-center justify-between mt-2 pt-1 border-t border-gray-800/60 text-[10px] text-gray-400">
                        <span className="line-clamp-1 text-gray-400">{p.tag}</span>
                        {p.hltb > 0 && <span className="font-mono text-gray-500 ml-1 shrink-0">~{p.hltb}h</span>}
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* FLIK 2: Klistra in text / guide */}
          {activeStep1Tab === 'paste' && (
            <div className="bg-gray-950/80 border border-blue-500/30 rounded-xl p-4 sm:p-5 space-y-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div>
                  <h3 className="text-sm font-bold text-white flex items-center gap-2">
                    <FileText className="w-4 h-4 text-blue-400" />
                    Enkel textimport (100% träffsäkert, 1 millisekund)
                  </h3>
                  <p className="text-xs text-gray-400 mt-0.5">
                    Kopiera kapitel eller uppdrag från IGN, PowerPyx eller Reddit och klistra in här.
                  </p>
                </div>
                <button
                  type="button"
                  onClick={fillAlanWakeExample}
                  className="px-3 py-1.5 bg-blue-500/10 hover:bg-blue-500/20 text-blue-300 border border-blue-500/30 text-xs font-medium rounded-lg transition-colors flex items-center gap-1.5"
                >
                  <Sparkles className="w-3.5 h-3.5 text-blue-400" />
                  Fyll i Alan Wake 2 (Exempel)
                </button>
              </div>

              {/* Speltitel */}
              <div>
                <label className="block text-xs font-medium text-gray-300 mb-1">Speltitel:</label>
                <input
                  type="text"
                  placeholder="T.ex. Alan Wake 2, Dead Space, Sekiro..."
                  value={rawTextGameTitle}
                  onChange={(e) => setRawTextGameTitle(e.target.value)}
                  className="w-full bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-blue-500"
                />
              </div>

              {/* Textarea */}
              <div>
                <label className="block text-xs font-medium text-gray-300 mb-1">
                  Klistra in kapitel (ett per rad):
                </label>
                <textarea
                  rows={7}
                  placeholder={`Klistra in kapitellista här, t.ex:\nChapter 1: The Cult\nChapter 2: The Heart\nChapter 3: Local Girl\nChapter 4: No Chance\nChapter 5: Old Gods...`}
                  value={rawTextInput}
                  onChange={(e) => setRawTextInput(e.target.value)}
                  className="w-full bg-gray-900 border border-gray-700 rounded-lg p-3 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 font-mono leading-relaxed"
                />
              </div>

              {/* Nedre statusrad med Live Counter & Skapa-knapp */}
              <div className="flex flex-wrap items-center justify-between gap-3 pt-1 border-t border-gray-800">
                <div className="flex items-center gap-2">
                  <span className={`text-xs px-2.5 py-1 rounded-full font-medium flex items-center gap-1.5 ${
                    detectedItemsCount > 0
                      ? 'bg-emerald-500/20 text-emerald-300 border border-emerald-500/30'
                      : 'bg-gray-800 text-gray-400'
                  }`}>
                    <CheckCheck className="w-3.5 h-3.5" />
                    {detectedItemsCount > 0
                      ? `${detectedItemsCount} delmål upptäckta och redo att importeras`
                      : 'Inga rader upptäckta ännu'}
                  </span>
                </div>

                <button
                  type="button"
                  onClick={() => parseFromRawText(rawTextInput, rawTextGameTitle)}
                  disabled={detectedItemsCount === 0}
                  className="px-5 py-2.5 bg-blue-600 hover:bg-blue-500 disabled:opacity-40 text-white text-xs font-semibold rounded-xl transition-all shadow-lg shadow-blue-500/20 flex items-center gap-2"
                >
                  <ListChecks className="w-4 h-4" />
                  Skapa checklista direkt (1 ms)
                </button>
              </div>
            </div>
          )}

          {/* FLIK 3: Sök & Gemini AI (IGN Walkthrough) */}
          {activeStep1Tab === 'search' && (
            <div className="space-y-4">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="text-xs text-gray-400">
                  Skriv in spelet så går vi automatiskt in på <strong>IGN:s Walkthrough-sida</strong>, hämtar endast kapitellistan (1:1) och gör om den till steg i appen.
                </span>
                <button
                  onClick={() => setShowApiKeyInput(!showApiKeyInput)}
                  className="text-xs text-amber-400 hover:text-amber-300 flex items-center gap-1.5 transition-colors font-medium"
                >
                  <Key className="w-3.5 h-3.5" />
                  {showApiKeyInput ? 'Dölj Gemini AI-nyckel' : 'Konfigurera Gemini AI-nyckel'}
                </button>
              </div>

              {showApiKeyInput && (
                <div className="bg-gray-950/80 border border-amber-500/30 rounded-xl p-4 text-xs space-y-2">
                  <div className="flex items-center gap-2 text-amber-300 font-medium">
                    <Key className="w-4 h-4" />
                    Google Gemini API-inställning (IGN Walkthrough + AI)
                  </div>
                  <p className="text-gray-400">
                    Servern hämtar först IGN:s Walkthrough-sida i bakgrunden (~1s) och låter sedan Gemini i webbläsaren omvandla listan till 1:1-steg utan spoilers.
                  </p>
                  <input
                    type="password"
                    placeholder="Klistra in Gemini API-nyckel här..."
                    value={geminiApiKey}
                    onChange={(e) => saveApiKey(e.target.value)}
                    className="bg-gray-900 border border-gray-700 rounded-lg px-3 py-1.5 text-xs text-white w-full focus:outline-none focus:border-red-500"
                  />
                  <label className="flex items-center gap-1.5 cursor-pointer pt-1 text-gray-400">
                    <input
                      type="checkbox"
                      checked={forceAI}
                      onChange={(e) => setForceAI(e.target.checked)}
                      className="rounded border-gray-700 bg-gray-900 text-red-600 focus:ring-0"
                    />
                    <span>Tvinga IGN + AI-hämtning (även för redan verifierade mallar)</span>
                  </label>
                </div>
              )}

              {/* Sökfält för valfritt spel */}
              <form
                onSubmit={(e) => {
                  e.preventDefault();
                  if (searchInput.trim()) {
                    setSelectedGameName(searchInput.trim());
                    loadGameTemplate(searchInput.trim(), granularity, forceAI);
                  }
                }}
                className="flex gap-2"
              >
                <div className="relative flex-1">
                  <Search className="w-4 h-4 text-gray-500 absolute left-3 top-1/2 -translate-y-1/2" />
                  <input
                    type="text"
                    placeholder="Skriv in valfritt spel (t.ex. Dark Souls, Alan Wake 2, Dead Space, God of War Ragnarök...)"
                    value={searchInput}
                    onChange={(e) => setSearchInput(e.target.value)}
                    className="w-full bg-gray-950 border border-gray-800 rounded-xl pl-9 pr-4 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-purple-500 transition-colors"
                  />
                </div>
                <button
                  type="submit"
                  disabled={isLoading || !searchInput.trim()}
                  className="px-4 py-2 bg-purple-600 hover:bg-purple-500 disabled:opacity-50 text-white text-sm font-semibold rounded-xl transition-colors flex items-center gap-1.5 shadow-md shadow-purple-500/10"
                >
                  {isLoading ? 'Hämtar från IGN...' : 'Hämta från IGN'}
                </button>
              </form>

              {/* Live status under IGN + AI hämtning */}
              {isLoading && loadingStatus && (
                <div className="p-3 rounded-xl bg-purple-950/30 border border-purple-500/30 text-purple-200 text-xs flex items-center gap-2.5 animate-pulse">
                  <Globe className="w-4 h-4 text-purple-400 shrink-0" />
                  <span>{loadingStatus}</span>
                </div>
              )}

              {/* Guide URL */}
              <div className="pt-2 border-t border-gray-800">
                <span className="text-xs text-gray-400 block mb-1.5">Eller klistra in en specifik IGN Walkthrough-länk direkt:</span>
                <div className="flex flex-col sm:flex-row gap-2">
                  <input
                    type="url"
                    placeholder="https://www.ign.com/wikis/dark-souls/Walkthrough"
                    value={guideUrlInput}
                    onChange={(e) => setGuideUrlInput(e.target.value)}
                    className="flex-1 bg-gray-950 border border-gray-800 rounded-lg px-3 py-2 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-purple-500 font-mono"
                  />
                  <button
                    type="button"
                    onClick={() => {
                      if (guideUrlInput.trim()) {
                        loadGameTemplate(searchInput.trim() || selectedGameName, granularity, true, guideUrlInput.trim());
                      }
                    }}
                    disabled={isLoading || !guideUrlInput.trim()}
                    className="px-4 py-2 bg-purple-600 hover:bg-purple-500 disabled:opacity-50 text-white text-xs font-semibold rounded-lg transition-colors flex items-center justify-center gap-1.5 whitespace-nowrap"
                  >
                    {isLoading ? 'Läser IGN...' : 'Extrahera från URL'}
                  </button>
                </div>
              </div>
            </div>
          )}

          {errorMsg && (
            <div className="p-3.5 rounded-xl bg-red-950/40 border border-red-800/60 text-red-300 text-xs flex items-start gap-2">
              <AlertCircle className="w-4 h-4 flex-shrink-0 mt-0.5" />
              <div>{errorMsg}</div>
            </div>
          )}
        </section>

        {/* Steg 2: Progression Metadata & Sammanfattning */}
        {template && (
          <section className="bg-gray-900/60 border border-gray-800 rounded-2xl p-5 sm:p-6 space-y-4">
            <div className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-800 pb-4">
              <div>
                <h2 className="text-lg font-bold text-white flex flex-wrap items-center gap-2">
                  <span>{template.gameTitle}</span>
                  {template.source === 'curated' && (
                    <span className="text-[10px] bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 px-2.5 py-0.5 rounded-full font-semibold flex items-center gap-1">
                      <Shield className="w-3 h-3 text-emerald-400" /> Verifierad Gameshelf-mall
                    </span>
                  )}
                  {template.source === 'custom' && (
                    <span className="text-[10px] bg-blue-500/20 text-blue-400 border border-blue-500/30 px-2.5 py-0.5 rounded-full font-semibold flex items-center gap-1">
                      <FileText className="w-3 h-3 text-blue-400" /> Egen textimport
                    </span>
                  )}
                  {template.source === 'ai' && (
                    <span className="text-[10px] bg-purple-500/20 text-purple-400 border border-purple-500/30 px-2.5 py-0.5 rounded-full font-semibold flex items-center gap-1">
                      <Sparkles className="w-3 h-3" /> Genererad med {template.modelUsed || 'Gemini'}
                    </span>
                  )}
                  {template.source === 'scraped_guide' && (
                    <span className="text-[10px] bg-purple-500/20 text-purple-300 border border-purple-500/30 px-2.5 py-0.5 rounded-full font-semibold flex items-center gap-1">
                      <Globe className="w-3 h-3 text-purple-400" /> IGN Walkthrough + AI ({template.modelUsed || 'Gemini'})
                    </span>
                  )}
                </h2>
                {template.summary && (
                  <p className="text-xs text-gray-400 mt-1 max-w-xl">{template.summary}</p>
                )}
                {template.sourceUrl && (
                  <a
                    href={template.sourceUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 text-[11px] text-blue-400 hover:text-blue-300 mt-1 underline"
                  >
                    <span>Öppna källan: {template.sourceUrl}</span>
                    <ExternalLink className="w-3 h-3" />
                  </a>
                )}
              </div>

              {/* Detaljnivå Selector */}
              <div className="flex flex-col sm:flex-row items-start sm:items-center gap-2">
                <span className="text-[11px] text-gray-400 uppercase font-semibold flex items-center gap-1">
                  <Sliders className="w-3.5 h-3.5 text-gray-400" /> Detaljnivå:
                </span>
                <div className="inline-flex rounded-xl bg-gray-950 p-1 border border-gray-800 text-xs">
                  <button
                    onClick={() => handleGranularityChange('compact')}
                    className={`px-2.5 py-1 rounded-lg font-medium transition ${
                      granularity === 'compact'
                        ? 'bg-red-600 text-white'
                        : 'text-gray-400 hover:text-white'
                    }`}
                  >
                    Kompakt (Akter)
                  </button>
                  <button
                    onClick={() => handleGranularityChange('standard')}
                    className={`px-2.5 py-1 rounded-lg font-medium transition ${
                      granularity === 'standard'
                        ? 'bg-red-600 text-white'
                        : 'text-gray-400 hover:text-white'
                    }`}
                  >
                    Standard (12–18)
                  </button>
                  <button
                    onClick={() => handleGranularityChange('detailed')}
                    className={`px-2.5 py-1 rounded-lg font-medium transition ${
                      granularity === 'detailed'
                        ? 'bg-red-600 text-white'
                        : 'text-gray-400 hover:text-white'
                    }`}
                  >
                    Detaljerad (Fler quests)
                  </button>
                </div>
              </div>
            </div>

            {/* Information om personlig isolering */}
            <div className="flex items-center gap-2.5 p-3 rounded-xl bg-gray-950/70 border border-gray-800 text-xs text-gray-400">
              <Info className="w-4 h-4 text-blue-400 shrink-0" />
              <span>
                <strong className="text-gray-200">Personliga anpassningar:</strong> Du kan ändra ordning (pil upp/ned), redigera titlar och grupper, markera delmål som frivilliga eller ta bort dem. Ändringarna är helt isolerade till ditt spelbibliotek och påverkar aldrig grundmallen.
              </span>
            </div>

            {!template.hasLinearProgression ? (
              <div className="p-6 text-center space-y-3 bg-gray-950/50 rounded-xl border border-gray-800">
                <Gamepad2 className="w-10 h-10 text-gray-500 mx-auto" />
                <h3 className="text-base font-semibold text-gray-200">Detta spel saknar en linjär storykampanj</h3>
                <p className="text-xs text-gray-400 max-w-md mx-auto">
                  För multiplayer-, sport- eller sandlådespel som detta fungerar inte automatisk kapitelnedbrytning. I Gameshelf spåras dessa bäst med speltid, personliga mål eller sessioner.
                </p>
              </div>
            ) : (
              <>
                {/* Steg 3: Framstegs-Dashboard (Hur det ser ut i appen) */}
                <div className="space-y-4 pt-1">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <h3 className="text-sm font-semibold uppercase tracking-wider text-gray-300 flex items-center gap-2">
                      <span className="w-5 h-5 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center text-xs font-bold">2</span>
                      Interaktiv Framstegsmätare
                    </h3>

                    <div className="flex flex-wrap items-center gap-2">
                      {/* Vy-väljare: Grupperad per Akt eller Kronologisk */}
                      <div className="inline-flex rounded-xl bg-gray-950 p-1 border border-gray-800 text-xs">
                        <button
                          type="button"
                          onClick={() => setViewMode('grouped')}
                          className={`px-2.5 py-1 rounded-lg font-medium transition flex items-center gap-1.5 ${
                            viewMode === 'grouped'
                              ? 'bg-red-600 text-white shadow-sm'
                              : 'text-gray-400 hover:text-white'
                          }`}
                        >
                          <Layers className="w-3.5 h-3.5" />
                          <span>Grupperad (Akter/Trådar)</span>
                        </button>
                        <button
                          type="button"
                          onClick={() => setViewMode('chronological')}
                          className={`px-2.5 py-1 rounded-lg font-medium transition flex items-center gap-1.5 ${
                            viewMode === 'chronological'
                              ? 'bg-red-600 text-white shadow-sm'
                              : 'text-gray-400 hover:text-white'
                          }`}
                        >
                          <ListChecks className="w-3.5 h-3.5" />
                          <span>Kronologisk</span>
                        </button>
                      </div>

                      {/* Spoilerskydd Toggle */}
                      <button
                        onClick={() => setSpoilerProtection(!spoilerProtection)}
                        className={`px-3 py-1.5 rounded-xl border text-xs font-medium flex items-center gap-1.5 transition-all ${
                          spoilerProtection
                            ? 'bg-amber-500/15 border-amber-500/40 text-amber-300'
                            : 'bg-gray-800 border-gray-700 text-gray-400 hover:text-white'
                        }`}
                      >
                        <Shield className="w-3.5 h-3.5" />
                        {spoilerProtection ? '🛡️ Spoilerskydd PÅ' : 'Spoilerskydd AV'}
                      </button>
                    </div>
                  </div>

                  {/* Stora framstegskort */}
                  <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    <div className="bg-gray-950/80 border border-gray-800 p-4 rounded-xl">
                      <span className="text-[11px] uppercase font-semibold text-gray-400 block mb-1">
                        Genomfört
                      </span>
                      <div className="text-2xl font-bold text-white flex items-baseline gap-2">
                        {doneCount} / {totalCount}
                        <span className="text-sm font-semibold text-red-400">({progressPercent}%)</span>
                      </div>
                      <span className="text-[11px] text-gray-500">delmål avklarade</span>
                    </div>

                    <div className="bg-gray-950/80 border border-gray-800 p-4 rounded-xl">
                      <span className="text-[11px] uppercase font-semibold text-gray-400 block mb-1">
                        Beräknad Story-status
                      </span>
                      <div className="text-lg font-bold text-white line-clamp-1">
                        {calculatedStoryMilestone}
                      </div>
                      <span className="text-[11px] text-gray-500">synkas mot Game.storyProgress</span>
                    </div>

                    <div className="bg-gray-950/80 border border-gray-800 p-4 rounded-xl">
                      <span className="text-[11px] uppercase font-semibold text-gray-400 block mb-1">
                        Uppskattad tid kvar
                      </span>
                      <div className="text-2xl font-bold text-white flex items-baseline gap-1">
                        {estimatedRemainingHours !== null ? `${estimatedRemainingHours}h` : '–'}
                        <span className="text-xs text-gray-500 font-normal">
                          (av ~{estimatedHours}h HLTB)
                        </span>
                      </div>
                      <span className="text-[11px] text-gray-500">baserat på andel klara kapitel</span>
                    </div>
                  </div>

                  {/* Progress Bar */}
                  <div className="space-y-1.5">
                    <div className="w-full bg-gray-950 rounded-full h-3.5 overflow-hidden border border-gray-800 p-0.5">
                      <div
                        className="h-full rounded-full transition-all duration-500 bg-gradient-to-r from-red-600 via-orange-500 to-emerald-500"
                        style={{ width: `${progressPercent}%` }}
                      />
                    </div>
                  </div>

                  {/* Förklaringsruta om spoilerskydd per akt */}
                  <div className="flex items-center gap-2.5 p-3 rounded-xl bg-gray-950/80 border border-blue-500/20 text-xs text-blue-300">
                    <Shield className="w-4 h-4 text-blue-400 shrink-0" />
                    <span>
                      <strong>Spoilerskydd per Akt:</strong> Alla uppdrag i <strong>{activeMajorActName || 'nuvarande akt'}</strong> visas samtidigt så att du kan spela dem i valfri ordning (t.ex. Panam, Judy eller Takemura). Framtida akter hålls dolda tills hela denna akt är klar!
                    </span>
                  </div>

                  {/* Snabbknappar */}
                  <div className="flex flex-wrap items-center justify-between gap-2 pt-1">
                    <button
                      onClick={checkNextTodo}
                      disabled={doneCount === totalCount}
                      className="px-4 py-2 bg-red-600 hover:bg-red-500 disabled:opacity-40 text-white text-xs font-semibold rounded-xl transition-all shadow-md flex items-center gap-1.5"
                    >
                      <CheckCircle2 className="w-4 h-4" />
                      Bocka av nästa uppdrag ({currentChapterIndex < todos.length ? todos[currentChapterIndex]?.title : 'Alla klara!'})
                    </button>

                    <div className="flex items-center gap-2">
                      <button
                        onClick={restoreMasterTemplate}
                        className="px-3 py-1.5 bg-gray-800 hover:bg-gray-700 text-gray-300 text-xs rounded-xl transition-colors flex items-center gap-1"
                        title="Återställer listan till ursprungsmallen ifall du flyttat eller raderat delmål"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                        Återställ till grundmall
                      </button>

                      <button
                        onClick={resetAll}
                        className="px-3 py-1.5 bg-gray-800 hover:bg-gray-700 text-gray-300 text-xs rounded-xl transition-colors flex items-center gap-1"
                      >
                        <RotateCcw className="w-3.5 h-3.5" />
                        Nollställ framsteg
                      </button>
                    </div>
                  </div>

                  {/* Snabbfilter för Akter / Trådar */}
                  {groups.length > 1 && (
                    <div className="flex items-center gap-1.5 overflow-x-auto pb-1 pt-1 text-xs">
                      <span className="text-[11px] text-gray-500 font-medium shrink-0 mr-1">Fasfilter:</span>
                      <button
                        onClick={() => setSelectedGroupFilter('all')}
                        className={`px-2.5 py-1 rounded-lg font-medium transition shrink-0 ${
                          selectedGroupFilter === 'all'
                            ? 'bg-red-600/20 text-red-300 border border-red-500/30'
                            : 'bg-gray-900 border border-gray-800 text-gray-400 hover:text-white'
                        }`}
                      >
                        Alla akter ({todos.length})
                      </button>
                      {groups.map((g) => {
                        const isSelected = selectedGroupFilter === g.name;
                        return (
                          <button
                            key={g.name}
                            onClick={() => setSelectedGroupFilter(isSelected ? 'all' : g.name)}
                            className={`px-2.5 py-1 rounded-lg font-medium transition shrink-0 flex items-center gap-1.5 ${
                              isSelected
                                ? 'bg-red-600 text-white shadow-sm'
                                : g.isCompleted
                                ? 'bg-emerald-950/30 border border-emerald-800/40 text-emerald-400'
                                : 'bg-gray-900 border border-gray-800 text-gray-400 hover:text-white'
                            }`}
                          >
                            <span>{g.name}</span>
                            <span className={`text-[10px] px-1.5 py-0.2 rounded font-mono ${
                              g.isCompleted ? 'bg-emerald-500/20 text-emerald-300' : 'bg-gray-800 text-gray-400'
                            }`}>
                              {g.done}/{g.total}
                            </span>
                          </button>
                        );
                      })}
                    </div>
                  )}

                  {/* Steg 4: Själva Checklistan */}
                  {viewMode === 'grouped' ? (
                    /* GRUPPERAD VY PER AKT / TRÅD (Perfekt för RPG) */
                    <div className="space-y-3 mt-4">
                      {groups
                        .filter((g) => selectedGroupFilter === 'all' || selectedGroupFilter === g.name)
                        .map((group) => {
                          const isCollapsed = collapsedGroups.has(group.name);
                          const isCurrentPhase = group.majorAct.toLowerCase() === (activeMajorActName || '').toLowerCase() && !group.isCompleted;

                          return (
                            <div
                              key={group.name}
                              className={`border rounded-xl overflow-hidden transition-all ${
                                isCurrentPhase
                                  ? 'border-red-500/40 bg-gray-950/60 shadow-lg shadow-red-500/5'
                                  : group.isCompleted
                                  ? 'border-emerald-500/30 bg-gray-950/40'
                                  : 'border-gray-800 bg-gray-950/30'
                              }`}
                            >
                              {/* Grupprubrik (Fällbar) */}
                              <div
                                onClick={() => toggleGroupCollapse(group.name)}
                                className="p-3 sm:p-3.5 flex items-center justify-between cursor-pointer hover:bg-gray-900/50 transition-colors select-none"
                              >
                                <div className="flex items-center gap-2.5">
                                  {isCollapsed ? (
                                    <ChevronRight className="w-4 h-4 text-gray-400" />
                                  ) : (
                                    <ChevronDown className="w-4 h-4 text-gray-400" />
                                  )}
                                  <span className="text-sm font-bold text-white">{group.name}</span>
                                  {isCurrentPhase && (
                                    <span className="text-[10px] px-2 py-0.5 rounded-full bg-red-500/20 text-red-400 font-semibold uppercase border border-red-500/30">
                                      Aktiv fas
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

                              {/* Gruppens delmål */}
                              {!isCollapsed && (
                                <div className="divide-y divide-gray-800/60 border-t border-gray-800/80">
                                  {group.items.map((item) => {
                                    const flatIndex = todos.findIndex((t) => t.id === item.id);
                                    const isHiddenBySpoiler = isItemHiddenBySpoiler(item, flatIndex);

                                    return (
                                      <div
                                        key={item.id}
                                        className={`p-3 sm:p-3.5 flex items-center gap-2 sm:gap-3 transition-colors ${
                                          item.isDone
                                            ? 'bg-emerald-950/10 text-gray-400'
                                            : flatIndex === currentChapterIndex
                                            ? 'bg-red-500/5 text-white'
                                            : 'text-gray-300 hover:bg-gray-900/40'
                                        }`}
                                      >
                                        {/* Sorteringspilar upp/ner */}
                                        <div className="flex flex-col items-center -space-y-1 shrink-0">
                                          <button
                                            type="button"
                                            onClick={() => moveTodoUp(flatIndex)}
                                            disabled={flatIndex === 0}
                                            className="p-0.5 text-gray-500 hover:text-white disabled:opacity-20 transition-colors"
                                            title="Flytta uppåt"
                                          >
                                            <ChevronUp className="w-3.5 h-3.5" />
                                          </button>
                                          <button
                                            type="button"
                                            onClick={() => moveTodoDown(flatIndex)}
                                            disabled={flatIndex === todos.length - 1}
                                            className="p-0.5 text-gray-500 hover:text-white disabled:opacity-20 transition-colors"
                                            title="Flytta nedåt"
                                          >
                                            <ChevronDown className="w-3.5 h-3.5" />
                                          </button>
                                        </div>

                                        {/* Index-nummer */}
                                        <span className="text-[11px] font-mono text-gray-500 w-4 text-center shrink-0">
                                          {flatIndex + 1}
                                        </span>

                                        {/* Checkbox */}
                                        <button
                                          onClick={() => toggleTodo(item.id)}
                                          className="flex-shrink-0 text-gray-400 hover:text-white transition-colors"
                                        >
                                          {item.isDone ? (
                                            <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                                          ) : (
                                            <Circle className={`w-5 h-5 ${flatIndex === currentChapterIndex ? 'text-red-400' : 'text-gray-600'}`} />
                                          )}
                                        </button>

                                        {/* Titel & ChapterGroup / Spoilerskydd */}
                                        <div className="flex-1 min-w-0">
                                          {isHiddenBySpoiler ? (
                                            <div className="flex items-center gap-2 text-xs text-gray-500 italic">
                                              <Shield className="w-3.5 h-3.5 text-amber-500/70" />
                                              <span>Delmål {flatIndex + 1} (Dold av spoilerskydd - Framtida akt)</span>
                                              <button
                                                onClick={() => toggleReveal(item.id)}
                                                className="text-[11px] not-italic text-amber-400 hover:underline flex items-center gap-1 ml-1"
                                              >
                                                <Eye className="w-3 h-3" /> Visa
                                              </button>
                                            </div>
                                          ) : (
                                            <div className="flex flex-wrap items-center gap-2">
                                              {editingTodoId === item.id ? (
                                                <div className="flex flex-wrap items-center gap-1.5 flex-1 min-w-[240px]">
                                                  <input
                                                    type="text"
                                                    placeholder="Grupp / Akt (valfritt)"
                                                    value={editingTodoGroup}
                                                    onChange={(e) => setEditingTodoGroup(e.target.value)}
                                                    className="bg-gray-900 border border-gray-700 rounded px-2 py-1 text-xs text-white focus:outline-none w-28"
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
                                                    className="bg-gray-900 border border-blue-500 rounded px-2 py-1 text-xs text-white focus:outline-none flex-1 min-w-[140px]"
                                                  />
                                                  <button
                                                    type="button"
                                                    onClick={() => saveEditing(item.id)}
                                                    className="px-2.5 py-1 bg-blue-600 hover:bg-blue-500 text-white rounded text-xs font-medium"
                                                  >
                                                    Spara
                                                  </button>
                                                  <button
                                                    type="button"
                                                    onClick={() => setEditingTodoId(null)}
                                                    className="px-2 py-1 bg-gray-800 hover:bg-gray-700 text-gray-300 rounded text-xs"
                                                  >
                                                    Avbryt
                                                  </button>
                                                </div>
                                              ) : (
                                                <span
                                                  onClick={() => startEditing(item)}
                                                  className={`text-sm font-medium cursor-pointer hover:text-white transition-colors group/title flex items-center gap-1.5 ${
                                                    item.isDone ? 'line-through text-gray-500' : 'text-gray-200'
                                                  }`}
                                                  title="Klicka för att redigera titel och grupp"
                                                >
                                                  <span>{item.title}</span>
                                                  <Pencil className="w-3 h-3 text-gray-500 opacity-40 group-hover/title:opacity-100 transition-opacity" />
                                                </span>
                                              )}

                                              {flatIndex === currentChapterIndex && !item.isDone ? (
                                                <span className="text-[10px] px-1.5 py-0.5 rounded bg-red-500/20 text-red-400 font-semibold uppercase">
                                                  Nästa i listan
                                                </span>
                                              ) : !item.isDone && group.majorAct.toLowerCase() === (activeMajorActName || "").toLowerCase() ? (
                                                <span className="text-[10px] px-1.5 py-0.5 rounded bg-blue-500/15 text-blue-300 font-medium border border-blue-500/20">
                                                  Öppen
                                                </span>
                                              ) : null}

                                              {/* Knapp för frivillig / obligatorisk */}
                                              <button
                                                type="button"
                                                onClick={() => toggleOptional(item.id)}
                                                className={`text-[10px] px-2 py-0.5 rounded transition ${
                                                  item.isOptional
                                                    ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                                                    : 'bg-gray-800/70 text-gray-500 hover:text-gray-300'
                                                }`}
                                                title={item.isOptional ? 'Klicka för att göra obligatoriskt' : 'Klicka för att göra frivilligt'}
                                              >
                                                {item.isOptional ? 'Frivilligt' : 'Obligatoriskt'}
                                              </button>

                                              {spoilerProtection && revealedIds.has(item.id) && (
                                                <button
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

                                        {/* Ta bort knapp */}
                                        <button
                                          onClick={() => removeTodo(item.id)}
                                          className="text-gray-600 hover:text-red-400 p-1 transition-colors shrink-0"
                                          title="Ta bort från din lista"
                                        >
                                          <Trash2 className="w-3.5 h-3.5" />
                                        </button>
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
                    /* KRONOLOGISK PLATT VY */
                    <div className="border border-gray-800 rounded-xl overflow-hidden bg-gray-950/40 divide-y divide-gray-800/60 mt-4">
                      {filteredTodos.map((item) => {
                        const flatIndex = todos.findIndex((t) => t.id === item.id);
                        const isHiddenBySpoiler = isItemHiddenBySpoiler(item, flatIndex);

                        return (
                          <div
                            key={item.id}
                            className={`p-3 sm:p-3.5 flex items-center gap-2 sm:gap-3 transition-colors ${
                              item.isDone
                                ? 'bg-emerald-950/10 text-gray-400'
                                : flatIndex === currentChapterIndex
                                ? 'bg-red-500/5 text-white'
                                : 'text-gray-300 hover:bg-gray-900/40'
                            }`}
                          >
                            {/* Sorteringspilar upp/ner */}
                            <div className="flex flex-col items-center -space-y-1 shrink-0">
                              <button
                                type="button"
                                onClick={() => moveTodoUp(flatIndex)}
                                disabled={flatIndex === 0}
                                className="p-0.5 text-gray-500 hover:text-white disabled:opacity-20 transition-colors"
                                title="Flytta uppåt"
                              >
                                <ChevronUp className="w-3.5 h-3.5" />
                              </button>
                              <button
                                type="button"
                                onClick={() => moveTodoDown(flatIndex)}
                                disabled={flatIndex === todos.length - 1}
                                className="p-0.5 text-gray-500 hover:text-white disabled:opacity-20 transition-colors"
                                title="Flytta nedåt"
                              >
                                <ChevronDown className="w-3.5 h-3.5" />
                              </button>
                            </div>

                            {/* Index-nummer */}
                            <span className="text-[11px] font-mono text-gray-500 w-4 text-center shrink-0">
                              {flatIndex + 1}
                            </span>

                            {/* Checkbox */}
                            <button
                              onClick={() => toggleTodo(item.id)}
                              className="flex-shrink-0 text-gray-400 hover:text-white transition-colors"
                            >
                              {item.isDone ? (
                                <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                              ) : (
                                <Circle className={`w-5 h-5 ${flatIndex === currentChapterIndex ? 'text-red-400' : 'text-gray-600'}`} />
                              )}
                            </button>

                            {/* Titel & ChapterGroup / Spoilerskydd */}
                            <div className="flex-1 min-w-0">
                              {isHiddenBySpoiler ? (
                                <div className="flex items-center gap-2 text-xs text-gray-500 italic">
                                  <Shield className="w-3.5 h-3.5 text-amber-500/70" />
                                  <span>Delmål {flatIndex + 1} (Dold av spoilerskydd - Framtida akt)</span>
                                  <button
                                    onClick={() => toggleReveal(item.id)}
                                    className="text-[11px] not-italic text-amber-400 hover:underline flex items-center gap-1 ml-1"
                                  >
                                    <Eye className="w-3 h-3" /> Visa
                                  </button>
                                </div>
                              ) : (
                                <div className="flex flex-wrap items-center gap-2">
                                  {editingTodoId === item.id ? (
                                    <div className="flex flex-wrap items-center gap-1.5 flex-1 min-w-[240px]">
                                      <input
                                        type="text"
                                        placeholder="Grupp / Akt (valfritt)"
                                        value={editingTodoGroup}
                                        onChange={(e) => setEditingTodoGroup(e.target.value)}
                                        className="bg-gray-900 border border-gray-700 rounded px-2 py-1 text-xs text-white focus:outline-none w-28"
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
                                        className="bg-gray-900 border border-blue-500 rounded px-2 py-1 text-xs text-white focus:outline-none flex-1 min-w-[140px]"
                                      />
                                      <button
                                        type="button"
                                        onClick={() => saveEditing(item.id)}
                                        className="px-2.5 py-1 bg-blue-600 hover:bg-blue-500 text-white rounded text-xs font-medium"
                                      >
                                        Spara
                                      </button>
                                      <button
                                        type="button"
                                        onClick={() => setEditingTodoId(null)}
                                        className="px-2 py-1 bg-gray-800 hover:bg-gray-700 text-gray-300 rounded text-xs"
                                      >
                                        Avbryt
                                      </button>
                                    </div>
                                  ) : (
                                    <>
                                      {item.chapterGroup && (
                                        <span className="text-[10px] px-2 py-0.5 rounded-md bg-gray-800/90 text-gray-400 font-medium shrink-0 border border-gray-700/50">
                                          {item.chapterGroup}
                                        </span>
                                      )}
                                      <span
                                        onClick={() => startEditing(item)}
                                        className={`text-sm font-medium cursor-pointer hover:text-white transition-colors group/title flex items-center gap-1.5 ${
                                          item.isDone ? 'line-through text-gray-500' : 'text-gray-200'
                                        }`}
                                        title="Klicka för att redigera titel och grupp"
                                      >
                                        <span>{item.title}</span>
                                        <Pencil className="w-3 h-3 text-gray-500 opacity-40 group-hover/title:opacity-100 transition-opacity" />
                                      </span>
                                    </>
                                  )}

                                  {flatIndex === currentChapterIndex && !item.isDone ? (
                                    <span className="text-[10px] px-1.5 py-0.5 rounded bg-red-500/20 text-red-400 font-semibold uppercase">
                                      Nästa i listan
                                    </span>
                                  ) : !item.isDone && getMajorAct(item.chapterGroup).toLowerCase() === (activeMajorActName || "").toLowerCase() ? (
                                    <span className="text-[10px] px-1.5 py-0.5 rounded bg-blue-500/15 text-blue-300 font-medium border border-blue-500/20">
                                      Öppen
                                    </span>
                                  ) : null}

                                  {/* Knapp för frivillig / obligatorisk */}
                                  <button
                                    type="button"
                                    onClick={() => toggleOptional(item.id)}
                                    className={`text-[10px] px-2 py-0.5 rounded transition ${
                                      item.isOptional
                                        ? 'bg-amber-500/20 text-amber-300 border border-amber-500/30'
                                        : 'bg-gray-800/70 text-gray-500 hover:text-gray-300'
                                    }`}
                                    title={item.isOptional ? 'Klicka för att göra obligatoriskt' : 'Klicka för att göra frivilligt'}
                                  >
                                    {item.isOptional ? 'Frivilligt' : 'Obligatoriskt'}
                                  </button>

                                  {spoilerProtection && revealedIds.has(item.id) && (
                                    <button
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

                            {/* Ta bort knapp */}
                            <button
                              onClick={() => removeTodo(item.id)}
                              className="text-gray-600 hover:text-red-400 p-1 transition-colors shrink-0"
                              title="Ta bort från din lista"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        );
                      })}
                    </div>
                  )}

                  {/* Lägg till eget delmål med valfri grupp */}
                  <form onSubmit={handleAddCustomTodo} className="flex flex-col sm:flex-row gap-2 pt-2">
                    <input
                      type="text"
                      placeholder="Grupp / Akt (t.ex. Akt 2, DLC)"
                      value={newTodoChapterGroup}
                      onChange={(e) => setNewTodoChapterGroup(e.target.value)}
                      className="w-full sm:w-44 bg-gray-950 border border-gray-800 rounded-xl px-3 py-2 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-red-500"
                    />
                    <input
                      type="text"
                      placeholder="Titel på delmål (t.ex. 'Klara sidouppdrag' eller 'Hitta alla samlarobjekt')..."
                      value={newTodoTitle}
                      onChange={(e) => setNewTodoTitle(e.target.value)}
                      className="flex-1 bg-gray-950 border border-gray-800 rounded-xl px-3.5 py-2 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-red-500"
                    />
                    <button
                      type="submit"
                      disabled={!newTodoTitle.trim()}
                      className="px-4 py-2 bg-gray-800 hover:bg-gray-700 disabled:opacity-50 text-white text-xs font-semibold rounded-xl flex items-center justify-center gap-1.5 transition-colors whitespace-nowrap"
                    >
                      <Plus className="w-4 h-4" /> Lägg till
                    </button>
                  </form>
                </div>

                {/* Steg 5: Datamodell & Gameshelf Kompatibilitet */}
                <div className="mt-8 pt-6 border-t border-gray-800 space-y-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <h3 className="text-xs font-semibold uppercase tracking-wider text-gray-400 flex items-center gap-1.5">
                        <ListChecks className="w-4 h-4 text-emerald-400" />
                        Kompatibilitet med Gameshelf iOS & Supabase
                      </h3>
                      <p className="text-[11px] text-gray-500 mt-0.5">
                        Dessa punkter sparas direkt i spelets befintliga <code className="text-gray-300">todos</code>-fält i Supabase och synkas automatiskt till iPhone-appen utan att vi behöver ändra någon databasstruktur.
                      </p>
                    </div>
                    <button
                      onClick={copyJson}
                      className="px-2.5 py-1.5 bg-gray-950 border border-gray-800 hover:border-gray-700 text-gray-300 text-xs rounded-lg flex items-center gap-1.5 transition-colors"
                    >
                      {copiedJson ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                      {copiedJson ? 'Kopierat!' : 'Kopiera JSON'}
                    </button>
                  </div>

                  <pre className="p-3 bg-gray-950 rounded-xl border border-gray-800 text-[11px] text-gray-400 overflow-x-auto max-h-40 font-mono">
                    {JSON.stringify(
                      todos.slice(0, 4).map((t) => ({
                        id: t.id,
                        title: t.title,
                        chapterGroup: t.chapterGroup,
                        isDone: t.isDone,
                      })),
                      null,
                      2
                    ).replace(']', `  // ... samt ${Math.max(0, todos.length - 4)} fler delmål\n]`)}
                  </pre>
                </div>
              </>
            )}
          </section>
        )}
      </div>
    </div>
  );
}
