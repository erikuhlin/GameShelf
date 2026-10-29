'use client';

import React, { useState, useEffect, useMemo } from 'react';
import { Game, GameTodoItem, GameStoryProgress } from '@/types/game';
import { supabase } from '@/lib/supabase';
import {
  Check,
  Shield,
  ShieldOff,
  Eye,
  EyeOff,
  Sparkles,
  Plus,
  Trash2,
  ChevronDown,
  ChevronRight,
  Key,
  Layers,
  BookOpen,
  Clipboard,
  AlertCircle,
  Pencil,
  RotateCcw,
  ExternalLink,
  X,
  ListChecks,
} from 'lucide-react';

interface GameWalkthroughSectionProps {
  game: Game;
  onUpdateTodos: (todos: GameTodoItem[]) => void;
  onUpdateStoryProgress?: (progress: GameStoryProgress) => void;
}

export type TaskCategory = 'main' | 'side' | 'goal';

interface ActGroupInfo {
  name: string;
  majorAct: string;
  items: GameTodoItem[];
  done: number;
  total: number;
  isCompleted: boolean;
}

interface MajorActInfo {
  name: string;
  done: number;
  total: number;
  isCompleted: boolean;
}

// Normalisera speltitel för matchning mot sparade mallar
function normalizeWalkthroughTitle(title: string): string {
  return title
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\b(remake|remastered|definitive edition|gold edition|nintendo switch 2 edition|shadow of the erdtree edition)\b/gi, '')
    .replace(/[:\-–—'’()]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

// Hämta överordnad Akt (t.ex. "Akt 1: Trosky" -> "Akt 1", "Akt 2 (Panam)" -> "Akt 2")
function getMajorActName(raw?: string | null): string {
  if (!raw) return 'Huvudberättelsen';
  const trimmed = raw.trim();
  if (!trimmed) return 'Huvudberättelsen';

  const pattern = /^(Akt\s*\d+|Act\s*\d+|Del\s*\d+|Part\s*\d+|Kapitel\s*\d+|Chapter\s*\d+|Prolog|Prologue|Epilog|Epilogue|Final|Finale|Byn|Slottet|Ön|Sommar|Höst|Vinter|Vår)/i;
  const match = trimmed.match(pattern);
  if (match) return match[1].trim();

  const beforeParen = trimmed.split('(')[0].trim();
  const beforeColon = beforeParen.split(':')[0].trim();
  return beforeColon || 'Huvudberättelsen';
}

export function GameWalkthroughSection({
  game,
  onUpdateTodos,
  onUpdateStoryProgress,
}: GameWalkthroughSectionProps) {
  // Spoilerskydd
  const [spoilerProtection, setSpoilerProtection] = useState<boolean>(() => {
    if (typeof window === 'undefined') return true;
    const saved = localStorage.getItem('gameshelf_spoiler_protection');
    return saved !== null ? saved === 'true' : true;
  });
  const [revealedIds, setRevealedIds] = useState<Set<string>>(new Set());

  // Kategori- och vy-filter
  const [activeCategory, setActiveCategory] = useState<'all' | TaskCategory>('all');
  const [collapsedGroups, setCollapsedGroups] = useState<Set<string>>(new Set());

  // Laddningsstatus
  const [isLoadingTemplate, setIsLoadingTemplate] = useState(false);
  const [isGeneratingAI, setIsGeneratingAI] = useState(false);
  const [loadingStatus, setLoadingStatus] = useState('');
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  // Modaler
  const [showAddModal, setShowAddModal] = useState(false);
  const [newStepTitle, setNewStepTitle] = useState('');
  const [newStepCategory, setNewStepCategory] = useState<TaskCategory>('main');
  const [newStepActGroup, setNewStepActGroup] = useState('');

  const [showPasteModal, setShowPasteModal] = useState(false);
  const [pasteRawText, setPasteRawText] = useState('');

  const [showApiKeyModal, setShowApiKeyModal] = useState(false);
  const [apiKeyInput, setApiKeyInput] = useState('');

  const [showClearConfirmModal, setShowClearConfirmModal] = useState(false);

  // Redigering av enstaka uppdrag
  const [editingItem, setEditingItem] = useState<GameTodoItem | null>(null);
  const [editTitleDraft, setEditTitleDraft] = useState('');
  const [editCategoryDraft, setEditCategoryDraft] = useState<TaskCategory>('main');
  const [editActDraft, setEditActDraft] = useState('');

  // Ladda Gemini API-nyckel från localStorage
  useEffect(() => {
    const savedKey = localStorage.getItem('gameshelf_gemini_key') || '';
    setApiKeyInput(savedKey);
  }, []);

  const saveSpoilerSetting = (val: boolean) => {
    setSpoilerProtection(val);
    localStorage.setItem('gameshelf_spoiler_protection', String(val));
  };

  const saveApiKey = (key: string) => {
    const clean = key.trim();
    setApiKeyInput(clean);
    localStorage.setItem('gameshelf_gemini_key', clean);
  };

  const todos = useMemo(() => game.todos || [], [game.todos]);

  // Kategorisering som matchar iOS 1:1
  const mainQuests = useMemo(() => {
    return todos
      .filter((item) => {
        if (item.isOptional || item.chapterGroup === 'Sidouppdrag' || item.chapterGroup === 'Egna mål') {
          return false;
        }
        if (!item.chapterGroup && item.order === undefined) {
          const hasStructured = todos.some((t) => t.chapterGroup || t.order !== undefined);
          return !hasStructured;
        }
        return true;
      })
      .sort((a, b) => (a.order ?? 9999) - (b.order ?? 9999));
  }, [todos]);

  const sideQuests = useMemo(() => {
    return todos
      .filter((item) => item.isOptional || item.chapterGroup === 'Sidouppdrag')
      .sort((a, b) => (a.order ?? 9999) - (b.order ?? 9999));
  }, [todos]);

  const personalGoals = useMemo(() => {
    return todos
      .filter((item) => {
        if (item.chapterGroup === 'Egna mål') return true;
        const hasStructured = todos.some((t) => t.chapterGroup || t.order !== undefined);
        return hasStructured && !item.chapterGroup && item.order === undefined;
      })
      .sort((a, b) => (a.order ?? 9999) - (b.order ?? 9999));
  }, [todos]);

  const totalCount = todos.length;
  const completedCount = todos.filter((t) => t.isDone).length;
  const progressPercent = totalCount > 0 ? Math.round((completedCount / totalCount) * 100) : 0;

  // Akter och förgreningslogik (Act-aware branching)
  const actGroups = useMemo<ActGroupInfo[]>(() => {
    const orderKeys: string[] = [];
    const grouped = new Map<string, GameTodoItem[]>();

    for (const item of mainQuests) {
      const g = item.chapterGroup?.trim() || 'Huvudberättelsen';
      if (!grouped.has(g)) {
        orderKeys.push(g);
        grouped.set(g, []);
      }
      grouped.get(g)!.push(item);
    }

    return orderKeys.map((key) => {
      const list = grouped.get(key) || [];
      const done = list.filter((i) => i.isDone).length;
      return {
        name: key,
        majorAct: getMajorActName(key),
        items: list,
        done,
        total: list.length,
        isCompleted: done === list.length && list.length > 0,
      };
    });
  }, [mainQuests]);

  const majorActs = useMemo<MajorActInfo[]>(() => {
    const list: MajorActInfo[] = [];
    for (const item of mainQuests) {
      const mName = getMajorActName(item.chapterGroup);
      const existing = list.find((a) => a.name.toLowerCase() === mName.toLowerCase());
      if (existing) {
        existing.total += 1;
        if (item.isDone) existing.done += 1;
      } else {
        list.push({
          name: mName,
          done: item.isDone ? 1 : 0,
          total: 1,
          isCompleted: false,
        });
      }
    }
    list.forEach((a) => {
      a.isCompleted = a.done === a.total && a.total > 0;
    });
    return list;
  }, [mainQuests]);

  const activeMajorActIndex = useMemo(() => {
    const idx = majorActs.findIndex((a) => !a.isCompleted);
    return idx === -1 ? majorActs.length : idx;
  }, [majorActs]);

  const activeMajorActName = useMemo(() => {
    if (activeMajorActIndex < majorActs.length) {
      return majorActs[activeMajorActIndex]?.name;
    }
    return null;
  }, [majorActs, activeMajorActIndex]);

  const currentMainQuestIndex = useMemo(() => {
    const idx = mainQuests.findIndex((t) => !t.isDone);
    return idx === -1 ? mainQuests.length : idx;
  }, [mainQuests]);

  // Avgör om ett uppdrag ska döljas av spoilerskydd
  const isItemHiddenBySpoiler = (item: GameTodoItem, flatIndex: number) => {
    if (!spoilerProtection) return false;
    if (item.isDone) return false;
    if (revealedIds.has(item.id)) return false;

    // Om spelet har flera överordnade akter
    if (majorActs.length > 1) {
      const itemMajor = getMajorActName(item.chapterGroup);
      const actIdx = majorActs.findIndex((a) => a.name.toLowerCase() === itemMajor.toLowerCase());
      if (actIdx !== -1) {
        // Alla uppdrag i den nu aktiva akten samt alla tidigare akter är synliga
        return actIdx > activeMajorActIndex;
      }
    }

    // Linjär fallback: dölj allt efter nästa ouppfyllda uppdrag
    return flatIndex > currentMainQuestIndex;
  };

  // Toggle klar/inte klar
  const handleToggleTodo = (id: string) => {
    const updated = todos.map((t) => (t.id === id ? { ...t, isDone: !t.isDone } : t));
    onUpdateTodos(updated);
  };

  const toggleReveal = (id: string) => {
    setRevealedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const toggleGroupCollapse = (name: string) => {
    setCollapsedGroups((prev) => {
      const next = new Set(prev);
      if (next.has(name)) next.delete(name);
      else next.add(name);
      return next;
    });
  };

  // Lägg till nytt delmål / quest
  const handleAddNewItem = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newStepTitle.trim()) return;

    let group: string | undefined = undefined;
    let isOpt = false;

    if (newStepCategory === 'side') {
      group = newStepActGroup.trim() || 'Sidouppdrag';
      isOpt = true;
    } else if (newStepCategory === 'goal') {
      group = 'Egna mål';
      isOpt = false;
    } else {
      group = newStepActGroup.trim() || 'Huvudberättelsen';
      isOpt = false;
    }

    const maxOrder = todos.reduce((max, t) => Math.max(max, t.order ?? 0), 0);
    const newItem: GameTodoItem = {
      id: crypto.randomUUID(),
      title: newStepTitle.trim(),
      isDone: false,
      order: maxOrder + 1,
      chapterGroup: group,
      isOptional: isOpt,
    };

    onUpdateTodos([...todos, newItem]);
    setNewStepTitle('');
    setNewStepActGroup('');
    setShowAddModal(false);
  };

  // Spara redigerat uppdrag
  const handleSaveEdit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingItem || !editTitleDraft.trim()) return;

    let group: string | undefined = undefined;
    let isOpt = false;

    if (editCategoryDraft === 'side') {
      group = editActDraft.trim() || 'Sidouppdrag';
      isOpt = true;
    } else if (editCategoryDraft === 'goal') {
      group = 'Egna mål';
      isOpt = false;
    } else {
      group = editActDraft.trim() || 'Huvudberättelsen';
      isOpt = false;
    }

    const updated = todos.map((t) =>
      t.id === editingItem.id
        ? {
            ...t,
            title: editTitleDraft.trim(),
            chapterGroup: group,
            isOptional: isOpt,
          }
        : t
    );

    onUpdateTodos(updated);
    setEditingItem(null);
  };

  // Ta bort enskilt uppdrag
  const handleDeleteItem = (id: string) => {
    const updated = todos.filter((t) => t.id !== id);
    onUpdateTodos(updated);
  };

  // Rensa alla uppdrag
  const handleClearAllTodos = () => {
    onUpdateTodos([]);
    setShowClearConfirmModal(false);
  };

  // 1. Hämta förberedd eller kurerad mall från Supabase / API
  const handleFetchCuratedTemplate = async () => {
    setIsLoadingTemplate(true);
    setErrorMessage(null);
    setLoadingStatus(`Söker efter kurerad mall för ${game.title}...`);

    try {
      // 1. Försök hitta direkt i Supabase game_walkthroughs
      const normTitle = normalizeWalkthroughTitle(game.title);
      let foundItems: any[] | null = null;
      let templateProgression = 'chapters';
      let templateSummary = '';

      if (game.igdb_id) {
        const { data } = await supabase
          .from('game_walkthroughs')
          .select('*')
          .eq('igdb_id', game.igdb_id)
          .maybeSingle();
        if (data && Array.isArray(data.items) && data.items.length > 0) {
          foundItems = data.items;
          templateProgression = data.progression_type || 'chapters';
          templateSummary = data.summary || '';
        }
      }

      if (!foundItems) {
        const { data } = await supabase
          .from('game_walkthroughs')
          .select('*')
          .eq('normalized_title', normTitle)
          .maybeSingle();
        if (data && Array.isArray(data.items) && data.items.length > 0) {
          foundItems = data.items;
          templateProgression = data.progression_type || 'chapters';
          templateSummary = data.summary || '';
        }
      }

      // 2. Fallback till /api/games/progress-template
      if (!foundItems) {
        const res = await fetch('/api/games/progress-template', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            gameTitle: game.title,
            forceAI: false,
          }),
        });

        if (res.ok) {
          const apiData = await res.json();
          if (apiData && Array.isArray(apiData.items) && apiData.items.length > 0) {
            foundItems = apiData.items;
            templateProgression = apiData.progressionType || 'chapters';
            templateSummary = apiData.summary || '';
          }
        }
      }

      if (foundItems && foundItems.length > 0) {
        const newTodos: GameTodoItem[] = foundItems.map((it: any, idx: number) => ({
          id: crypto.randomUUID(),
          title: it.title,
          isDone: false,
          order: it.order ?? idx + 1,
          chapterGroup: it.chapterGroup || 'Huvudberättelsen',
          description: it.description,
          isOptional: Boolean(it.isOptional),
        }));

        onUpdateTodos(newTodos);
        return;
      }

      setErrorMessage(`Ingen förberedd mall hittades för "${game.title}". Du kan generera en med AI eller klistra in manuellt.`);
    } catch (err: any) {
      setErrorMessage(`Kunde inte ladda mall: ${err.message || 'Okänt fel'}`);
    } finally {
      setIsLoadingTemplate(false);
      setLoadingStatus('');
    }
  };

  // 2. Generera med Gemini AI med dynamisk modellupptäckt och thinkingBudget: 0
  const handleGenerateWithAI = async () => {
    const cleanKey = apiKeyInput.trim();
    if (!cleanKey) {
      setShowApiKeyModal(true);
      return;
    }

    setIsGeneratingAI(true);
    setErrorMessage(null);
    setLoadingStatus(`Hämtar 1:1 IGN Walkthrough-struktur för ${game.title}...`);

    const title = game.title;
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
      } catch {
        // Ignorera discovery-fel, kör standardmodeller
      }

      let lastError: Error | null = null;
      let rawItems: any[] = [];
      let parsedSummary = '';

      for (let i = 0; i < candidateModels.length; i++) {
        const modelName = candidateModels[i];
        try {
          if (i > 0) {
            setLoadingStatus(`Försöker med reservmodell (${modelName}) för ${game.title}...`);
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

          // Fallback utan thinkingConfig om 400
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
          const found = Array.isArray(parsed.items)
            ? parsed.items
            : Array.isArray(parsed.chapters)
            ? parsed.chapters
            : Array.isArray(parsed.walkthrough)
            ? parsed.walkthrough
            : [];

          if (found.length === 0) throw new Error('Inga kapitel returnerades från AI');

          rawItems = found;
          parsedSummary = parsed.summary || `Kapitellista genererad för ${game.title}.`;
          break;
        } catch (err: any) {
          lastError = err;
        }
      }

      if (rawItems.length === 0) {
        throw lastError || new Error('Timeout eller fel hos AI-tjänsten');
      }

      const newTodos: GameTodoItem[] = rawItems.map((it: any, idx: number) => ({
        id: crypto.randomUUID(),
        title: String(it.title || it.name || `Delmål ${idx + 1}`),
        isDone: false,
        order: Number(it.order || idx + 1),
        chapterGroup: it.chapterGroup || it.act || it.region || 'Huvudberättelsen',
        description: it.description,
        isOptional: Boolean(it.isOptional),
      }));

      // Lägg till eventuella personliga mål som redan fanns
      onUpdateTodos([...newTodos, ...personalGoals]);

      // Spara mallen till Supabase game_walkthroughs så den delas automatiskt
      if (game.igdb_id) {
        supabase
          .from('game_walkthroughs')
          .upsert(
            {
              igdb_id: game.igdb_id,
              title: game.title,
              normalized_title: normalizeWalkthroughTitle(game.title),
              has_linear_progression: true,
              progression_type: 'chapters',
              summary: parsedSummary,
              items: rawItems,
              source: 'ai',
              source_url: ignSourceUrl,
            },
            { onConflict: 'igdb_id' }
          )
          .then(({ error }) => {
            if (error) console.warn('Could not share template to Supabase:', error.message);
          });
      }
    } catch (err: any) {
      setErrorMessage(`AI-generering misslyckades: ${err.message || 'Okänt fel'}. Du kan klistra in listan manuellt.`);
      setShowPasteModal(true);
    } finally {
      setIsGeneratingAI(false);
      setLoadingStatus('');
    }
  };

  // 3. Manuell inklistring av textrader
  const handleImportPastedText = () => {
    const lines = pasteRawText.split('\n').map((l) => l.trim()).filter(Boolean);
    if (lines.length === 0) {
      setErrorMessage('Ingen text hittades. Klistra in en rad per kapitel.');
      return;
    }

    const items: GameTodoItem[] = [];
    let currentAct = 'Huvudberättelsen';
    let orderCounter = 1;

    for (const line of lines) {
      if (line.length < 2 || line.length > 140) continue;
      if (/^(cookie|copyright|privacy|advertisement|follow us|subscribe)/i.test(line)) continue;

      if (line.startsWith('#')) {
        currentAct = line.replace(/^#+\s*/, '').trim();
        continue;
      }
      if (line.endsWith(':') && line.length < 45) {
        currentAct = line.slice(0, -1).trim();
        continue;
      }
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
          id: crypto.randomUUID(),
          title: cleaned,
          isDone: false,
          order: orderCounter,
          chapterGroup: currentAct,
          isOptional: false,
        });
        orderCounter++;
      }
    }

    if (items.length === 0) {
      setErrorMessage('Kunde inte tolka några kapitel ur texten.');
      return;
    }

    onUpdateTodos([...items, ...personalGoals]);
    setShowPasteModal(false);
    setPasteRawText('');
    setErrorMessage(null);
  };

  return (
    <div className="bg-zinc-900/70 border border-zinc-800/80 rounded-2xl p-4 sm:p-5 space-y-4">
      {/* Sektionshuvud */}
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-zinc-800/60 pb-3">
        <div className="flex items-center gap-2.5">
          <Layers className="w-4 h-4 text-brand-red" />
          <h3 className="text-sm font-bold text-white tracking-wide">Kapitel & uppdrag</h3>
          {totalCount > 0 && (
            <span className="text-xs font-semibold text-zinc-400">
              · {completedCount} av {totalCount} klara ({progressPercent}%)
            </span>
          )}
        </div>

        {/* Åtgärder & Spoilerskydd */}
        <div className="flex items-center gap-2">
          {totalCount > 0 && (
            <button
              type="button"
              onClick={() => saveSpoilerSetting(!spoilerProtection)}
              className={`flex items-center gap-1.5 px-2.5 py-1 rounded-xl text-xs font-semibold transition cursor-pointer border ${
                spoilerProtection
                  ? 'bg-amber-500/15 border-amber-500/40 text-amber-300 hover:bg-amber-500/25'
                  : 'bg-zinc-800 border-zinc-700 text-zinc-400 hover:text-white'
              }`}
              title={spoilerProtection ? 'Spoilerskydd är aktivt. Klicka för att stänga av.' : 'Spoilerskydd är avstängt. Klicka för att aktivera.'}
            >
              {spoilerProtection ? <Shield className="w-3.5 h-3.5 text-amber-400" /> : <ShieldOff className="w-3.5 h-3.5" />}
              <span>{spoilerProtection ? 'Spoilerskydd PÅ' : 'Spoilerskydd AV'}</span>
            </button>
          )}

          <button
            type="button"
            onClick={() => setShowAddModal(true)}
            className="flex items-center gap-1 px-2.5 py-1 bg-zinc-800 hover:bg-zinc-700 text-white rounded-xl text-xs font-semibold border border-zinc-700/80 transition cursor-pointer"
            title="Lägg till eget delmål eller quest"
          >
            <Plus className="w-3.5 h-3.5" />
            <span className="hidden sm:inline">Ny punkt</span>
          </button>

          {totalCount > 0 && (
            <button
              type="button"
              onClick={() => setShowClearConfirmModal(true)}
              className="p-1.5 text-zinc-500 hover:text-red-400 rounded-xl hover:bg-zinc-800/60 transition cursor-pointer"
              title="Rensa alla kapitel"
            >
              <RotateCcw className="w-3.5 h-3.5" />
            </button>
          )}
        </div>
      </div>

      {/* Felmeddelande & Laddningsindikator */}
      {errorMessage && (
        <div className="p-3 bg-red-950/40 border border-red-900/60 rounded-xl text-xs text-red-300 flex items-start gap-2">
          <AlertCircle className="w-4 h-4 text-red-400 flex-shrink-0 mt-0.5" />
          <div className="flex-1">
            <span>{errorMessage}</span>
          </div>
          <button
            type="button"
            onClick={() => setErrorMessage(null)}
            className="text-red-400 hover:text-white cursor-pointer"
          >
            <X className="w-3.5 h-3.5" />
          </button>
        </div>
      )}

      {(isLoadingTemplate || isGeneratingAI) && (
        <div className="p-3.5 bg-brand-red/10 border border-brand-red/30 rounded-xl flex items-center gap-3">
          <div className="w-4 h-4 border-2 border-brand-red border-t-transparent rounded-full animate-spin flex-shrink-0" />
          <span className="text-xs font-medium text-white">{loadingStatus}</span>
        </div>
      )}

      {/* Framstegsindikator & Aktivt uppdrag */}
      {totalCount > 0 && (
        <div className="space-y-2">
          <div className="w-full bg-zinc-950 rounded-full h-2 overflow-hidden border border-zinc-800">
            <div
              className={`h-full transition-all duration-300 rounded-full ${
                completedCount === totalCount ? 'bg-emerald-500' : 'bg-brand-red'
              }`}
              style={{ width: `${progressPercent}%` }}
            />
          </div>

          {activeMajorActName && completedCount < totalCount && (
            <div className="flex items-center gap-2 text-xs text-zinc-400 pt-0.5">
              <span className="font-semibold text-zinc-300">Aktivt kapitel:</span>
              <span className="px-2 py-0.5 rounded-lg bg-zinc-800/90 border border-zinc-700/80 text-white font-medium">
                {activeMajorActName}
              </span>
            </div>
          )}
        </div>
      )}

      {/* Kategori-flikar (Huvuduppdrag, Sidouppdrag, Egna mål) */}
      {totalCount > 0 && (sideQuests.length > 0 || personalGoals.length > 0) && (
        <div className="flex flex-wrap gap-1.5 pt-1">
          <button
            type="button"
            onClick={() => setActiveCategory('all')}
            className={`px-2.5 py-1 rounded-xl text-xs font-semibold transition cursor-pointer border ${
              activeCategory === 'all'
                ? 'bg-zinc-700 border-zinc-600 text-white'
                : 'bg-zinc-950/60 border-zinc-800 text-zinc-400 hover:text-white'
            }`}
          >
            Alla ({totalCount})
          </button>
          <button
            type="button"
            onClick={() => setActiveCategory('main')}
            className={`px-2.5 py-1 rounded-xl text-xs font-semibold transition cursor-pointer border ${
              activeCategory === 'main'
                ? 'bg-zinc-700 border-zinc-600 text-white'
                : 'bg-zinc-950/60 border-zinc-800 text-zinc-400 hover:text-white'
            }`}
          >
            Huvuduppdrag ({mainQuests.length})
          </button>
          {sideQuests.length > 0 && (
            <button
              type="button"
              onClick={() => setActiveCategory('side')}
              className={`px-2.5 py-1 rounded-xl text-xs font-semibold transition cursor-pointer border ${
                activeCategory === 'side'
                  ? 'bg-zinc-700 border-zinc-600 text-white'
                  : 'bg-zinc-950/60 border-zinc-800 text-zinc-400 hover:text-white'
              }`}
            >
              Sidouppdrag ({sideQuests.length})
            </button>
          )}
          {personalGoals.length > 0 && (
            <button
              type="button"
              onClick={() => setActiveCategory('goal')}
              className={`px-2.5 py-1 rounded-xl text-xs font-semibold transition cursor-pointer border ${
                activeCategory === 'goal'
                  ? 'bg-zinc-700 border-zinc-600 text-white'
                  : 'bg-zinc-950/60 border-zinc-800 text-zinc-400 hover:text-white'
              }`}
            >
              Egna mål ({personalGoals.length})
            </button>
          )}
        </div>
      )}

      {/* TOMT TILLSTÅND: När spelet saknar kapitel/uppdrag */}
      {totalCount === 0 && !isLoadingTemplate && !isGeneratingAI && (
        <div className="p-6 bg-zinc-950/60 border border-zinc-800/80 rounded-xl text-center space-y-4">
          <div className="w-10 h-10 rounded-2xl bg-zinc-900 border border-zinc-800 mx-auto flex items-center justify-center text-zinc-400">
            <ListChecks className="w-5 h-5 text-brand-red" />
          </div>
          <div className="space-y-1">
            <h4 className="text-sm font-bold text-white">Inga kapitel eller uppdrag än</h4>
            <p className="text-xs text-zinc-400 max-w-sm mx-auto">
              Följ din resa genom spelet steg för steg med spoilerskydd och 1:1 IGN Walkthrough-struktur.
            </p>
          </div>

          <div className="flex flex-wrap items-center justify-center gap-2 pt-2">
            <button
              type="button"
              onClick={handleFetchCuratedTemplate}
              className="px-3.5 py-2 bg-brand-red hover:bg-brand-red/90 text-white rounded-xl text-xs font-bold transition flex items-center gap-2 cursor-pointer shadow-sm"
            >
              <BookOpen className="w-3.5 h-3.5" />
              <span>Hämta kurerad mall</span>
            </button>

            <button
              type="button"
              onClick={handleGenerateWithAI}
              className="px-3.5 py-2 bg-zinc-800 hover:bg-zinc-700 text-white rounded-xl text-xs font-bold transition flex items-center gap-2 cursor-pointer border border-zinc-700/80"
            >
              <Sparkles className="w-3.5 h-3.5 text-amber-400" />
              <span>Generera med Gemini AI</span>
            </button>

            <button
              type="button"
              onClick={() => setShowPasteModal(true)}
              className="px-3.5 py-2 bg-zinc-900 hover:bg-zinc-800 text-zinc-300 hover:text-white rounded-xl text-xs font-semibold transition flex items-center gap-2 cursor-pointer border border-zinc-800"
            >
              <Clipboard className="w-3.5 h-3.5" />
              <span>Klistra in manuellt</span>
            </button>
          </div>

          <div className="pt-2">
            <button
              type="button"
              onClick={() => setShowApiKeyModal(true)}
              className="text-[11px] text-zinc-500 hover:text-zinc-300 underline flex items-center justify-center gap-1 mx-auto cursor-pointer"
            >
              <Key className="w-3 h-3" />
              <span>{apiKeyInput ? 'Ändra Gemini API-nyckel' : 'Lägg till egen Gemini API-nyckel för fri AI-användning'}</span>
            </button>
          </div>
        </div>
      )}

      {/* LISTA MED AKTER & UPPDRAG */}
      {totalCount > 0 && (
        <div className="space-y-4 pt-1">
          {/* 1. Huvuduppdrag (Akt-grupperat) */}
          {(activeCategory === 'all' || activeCategory === 'main') &&
            actGroups.map((group) => {
              const isCollapsed = collapsedGroups.has(group.name);
              return (
                <div
                  key={group.name}
                  className="bg-zinc-950/60 border border-zinc-800/80 rounded-xl overflow-hidden"
                >
                  {/* Akt-rubrik */}
                  <button
                    type="button"
                    onClick={() => toggleGroupCollapse(group.name)}
                    className="w-full px-3.5 py-2.5 flex items-center justify-between bg-zinc-900/60 hover:bg-zinc-900 transition text-left cursor-pointer border-b border-zinc-800/50"
                  >
                    <div className="flex items-center gap-2">
                      {isCollapsed ? (
                        <ChevronRight className="w-3.5 h-3.5 text-zinc-500" />
                      ) : (
                        <ChevronDown className="w-3.5 h-3.5 text-zinc-500" />
                      )}
                      <span className="text-xs font-bold text-white tracking-wide">{group.name}</span>
                      <span className="text-[11px] font-semibold text-zinc-400">
                        ({group.done}/{group.total} klara)
                      </span>
                    </div>

                    {group.isCompleted && (
                      <span className="px-2 py-0.5 rounded-lg bg-emerald-500/15 border border-emerald-500/30 text-[10px] font-bold text-emerald-400 flex items-center gap-1">
                        <Check className="w-3 h-3" />
                        <span>Klar</span>
                      </span>
                    )}
                  </button>

                  {/* Uppdragen i akten */}
                  {!isCollapsed && (
                    <div className="p-2 space-y-1.5">
                      {group.items.map((item, idx) => {
                        const isHidden = isItemHiddenBySpoiler(item, idx);
                        return (
                          <div
                            key={item.id}
                            className={`flex items-center justify-between px-3 py-2 rounded-xl text-xs transition border ${
                              item.isDone
                                ? 'bg-zinc-950/40 border-zinc-900 text-zinc-500'
                                : isHidden
                                ? 'bg-zinc-900/40 border-zinc-800/60 text-zinc-400'
                                : 'bg-zinc-900/80 border-zinc-800 text-zinc-200'
                            }`}
                          >
                            {/* Checkbox & Titel */}
                            <div className="flex items-center gap-2.5 flex-1 min-w-0 mr-2">
                              <button
                                type="button"
                                onClick={() => handleToggleTodo(item.id)}
                                className={`w-4 h-4 rounded flex items-center justify-center border transition flex-shrink-0 cursor-pointer ${
                                  item.isDone
                                    ? 'bg-emerald-500 border-emerald-500 text-black'
                                    : 'border-zinc-700 bg-zinc-950 hover:border-zinc-500'
                                }`}
                              >
                                {item.isDone && <Check className="w-3 h-3 stroke-[3]" />}
                              </button>

                              {isHidden ? (
                                <button
                                  type="button"
                                  onClick={() => toggleReveal(item.id)}
                                  className="flex items-center gap-2 text-left text-zinc-500 hover:text-zinc-300 cursor-pointer flex-1 py-0.5"
                                  title="Klicka för att avslöja kapitelnamn"
                                >
                                  <Shield className="w-3.5 h-3.5 text-amber-400/80 flex-shrink-0" />
                                  <span className="italic font-medium text-[11px] select-none blur-[3px] hover:blur-none transition-all">
                                    {item.title}
                                  </span>
                                  <span className="text-[10px] text-amber-400/70 ml-1 font-semibold">
                                    (Klicka för att visa)
                                  </span>
                                </button>
                              ) : (
                                <div className="flex-1 min-w-0">
                                  <span
                                    className={`truncate block ${
                                      item.isDone
                                        ? 'line-through text-zinc-500 font-normal'
                                        : 'text-zinc-200 font-medium'
                                    }`}
                                  >
                                    {item.title}
                                  </span>
                                  {item.description && (
                                    <p className="text-[10px] text-zinc-500 truncate">{item.description}</p>
                                  )}
                                </div>
                              )}
                            </div>

                            {/* Åtgärder för uppdraget */}
                            <div className="flex items-center gap-1 flex-shrink-0">
                              {isHidden ? (
                                <button
                                  type="button"
                                  onClick={() => toggleReveal(item.id)}
                                  className="p-1 text-zinc-500 hover:text-amber-400 transition cursor-pointer"
                                  title="Visa titel"
                                >
                                  <Eye className="w-3.5 h-3.5" />
                                </button>
                              ) : (
                                revealedIds.has(item.id) && (
                                  <button
                                    type="button"
                                    onClick={() => toggleReveal(item.id)}
                                    className="p-1 text-zinc-500 hover:text-zinc-300 transition cursor-pointer"
                                    title="Dölj igen"
                                  >
                                    <EyeOff className="w-3.5 h-3.5" />
                                  </button>
                                )
                              )}

                              <button
                                type="button"
                                onClick={() => {
                                  setEditingItem(item);
                                  setEditTitleDraft(item.title);
                                  setEditCategoryDraft('main');
                                  setEditActDraft(item.chapterGroup || '');
                                }}
                                className="p-1 text-zinc-600 hover:text-zinc-300 transition cursor-pointer"
                                title="Redigera"
                              >
                                <Pencil className="w-3 h-3" />
                              </button>

                              <button
                                type="button"
                                onClick={() => handleDeleteItem(item.id)}
                                className="p-1 text-zinc-600 hover:text-red-400 transition cursor-pointer"
                                title="Ta bort"
                              >
                                <Trash2 className="w-3 h-3" />
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              );
            })}

          {/* 2. Sidouppdrag */}
          {(activeCategory === 'all' || activeCategory === 'side') && sideQuests.length > 0 && (
            <div className="bg-zinc-950/60 border border-zinc-800/80 rounded-xl p-3 space-y-2">
              <div className="flex items-center justify-between border-b border-zinc-800/60 pb-2">
                <span className="text-xs font-bold text-amber-300/90 tracking-wide uppercase">
                  Sidouppdrag ({sideQuests.filter((t) => t.isDone).length}/{sideQuests.length})
                </span>
              </div>
              <div className="space-y-1.5">
                {sideQuests.map((item) => (
                  <div
                    key={item.id}
                    className={`flex items-center justify-between px-3 py-2 rounded-xl text-xs border ${
                      item.isDone
                        ? 'bg-zinc-950/40 border-zinc-900 text-zinc-500'
                        : 'bg-zinc-900/80 border-zinc-800 text-zinc-200'
                    }`}
                  >
                    <button
                      type="button"
                      onClick={() => handleToggleTodo(item.id)}
                      className="flex items-center gap-2.5 text-left flex-1 min-w-0 mr-2 cursor-pointer"
                    >
                      <span
                        className={`w-4 h-4 rounded flex items-center justify-center border transition flex-shrink-0 ${
                          item.isDone
                            ? 'bg-emerald-500 border-emerald-500 text-black'
                            : 'border-zinc-700 bg-zinc-950'
                        }`}
                      >
                        {item.isDone && <Check className="w-3 h-3 stroke-[3]" />}
                      </span>
                      <span className={`truncate ${item.isDone ? 'line-through text-zinc-500' : 'text-zinc-200'}`}>
                        {item.title}
                      </span>
                    </button>
                    <button
                      type="button"
                      onClick={() => handleDeleteItem(item.id)}
                      className="p-1 text-zinc-600 hover:text-red-400 cursor-pointer"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* 3. Egna mål */}
          {(activeCategory === 'all' || activeCategory === 'goal') && personalGoals.length > 0 && (
            <div className="bg-zinc-950/60 border border-zinc-800/80 rounded-xl p-3 space-y-2">
              <div className="flex items-center justify-between border-b border-zinc-800/60 pb-2">
                <span className="text-xs font-bold text-sky-300/90 tracking-wide uppercase">
                  Egna mål ({personalGoals.filter((t) => t.isDone).length}/{personalGoals.length})
                </span>
              </div>
              <div className="space-y-1.5">
                {personalGoals.map((item) => (
                  <div
                    key={item.id}
                    className={`flex items-center justify-between px-3 py-2 rounded-xl text-xs border ${
                      item.isDone
                        ? 'bg-zinc-950/40 border-zinc-900 text-zinc-500'
                        : 'bg-zinc-900/80 border-zinc-800 text-zinc-200'
                    }`}
                  >
                    <button
                      type="button"
                      onClick={() => handleToggleTodo(item.id)}
                      className="flex items-center gap-2.5 text-left flex-1 min-w-0 mr-2 cursor-pointer"
                    >
                      <span
                        className={`w-4 h-4 rounded flex items-center justify-center border transition flex-shrink-0 ${
                          item.isDone
                            ? 'bg-emerald-500 border-emerald-500 text-black'
                            : 'border-zinc-700 bg-zinc-950'
                        }`}
                      >
                        {item.isDone && <Check className="w-3 h-3 stroke-[3]" />}
                      </span>
                      <span className={`truncate ${item.isDone ? 'line-through text-zinc-500' : 'text-zinc-200'}`}>
                        {item.title}
                      </span>
                    </button>
                    <button
                      type="button"
                      onClick={() => handleDeleteItem(item.id)}
                      className="p-1 text-zinc-600 hover:text-red-400 cursor-pointer"
                    >
                      <Trash2 className="w-3 h-3" />
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* MODAL: Lägg till delmål / quest */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-md p-5 space-y-4">
            <div className="flex items-center justify-between border-b border-zinc-800 pb-3">
              <h4 className="text-sm font-bold text-white">Lägg till delmål / quest</h4>
              <button
                type="button"
                onClick={() => setShowAddModal(false)}
                className="text-zinc-400 hover:text-white cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleAddNewItem} className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-zinc-400 block mb-1">Titel</label>
                <input
                  type="text"
                  value={newStepTitle}
                  onChange={(e) => setNewStepTitle(e.target.value)}
                  placeholder="t.ex. Hitta hemliga grottan eller Slå bossen..."
                  autoFocus
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-xs text-white placeholder-zinc-600 focus:outline-none focus:border-brand-red"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-zinc-400 block mb-1">Kategori</label>
                <div className="grid grid-cols-3 gap-2">
                  <button
                    type="button"
                    onClick={() => setNewStepCategory('main')}
                    className={`py-1.5 rounded-xl text-xs font-semibold border transition cursor-pointer ${
                      newStepCategory === 'main'
                        ? 'bg-zinc-800 border-brand-red text-white'
                        : 'bg-zinc-950 border-zinc-800 text-zinc-400 hover:text-white'
                    }`}
                  >
                    Huvuduppdrag
                  </button>
                  <button
                    type="button"
                    onClick={() => setNewStepCategory('side')}
                    className={`py-1.5 rounded-xl text-xs font-semibold border transition cursor-pointer ${
                      newStepCategory === 'side'
                        ? 'bg-zinc-800 border-amber-500 text-white'
                        : 'bg-zinc-950 border-zinc-800 text-zinc-400 hover:text-white'
                    }`}
                  >
                    Sidouppdrag
                  </button>
                  <button
                    type="button"
                    onClick={() => setNewStepCategory('goal')}
                    className={`py-1.5 rounded-xl text-xs font-semibold border transition cursor-pointer ${
                      newStepCategory === 'goal'
                        ? 'bg-zinc-800 border-sky-500 text-white'
                        : 'bg-zinc-950 border-zinc-800 text-zinc-400 hover:text-white'
                    }`}
                  >
                    Eget mål
                  </button>
                </div>
              </div>

              {newStepCategory !== 'goal' && (
                <div>
                  <label className="text-xs font-semibold text-zinc-400 block mb-1">
                    Akt eller Region (valfritt)
                  </label>
                  <input
                    type="text"
                    value={newStepActGroup}
                    onChange={(e) => setNewStepActGroup(e.target.value)}
                    placeholder="t.ex. Akt 1, Velen, South Vale..."
                    className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-xs text-white placeholder-zinc-600 focus:outline-none focus:border-brand-red"
                  />
                </div>
              )}

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowAddModal(false)}
                  className="px-3 py-2 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 rounded-xl text-xs font-semibold transition cursor-pointer"
                >
                  Avbryt
                </button>
                <button
                  type="submit"
                  disabled={!newStepTitle.trim()}
                  className="px-4 py-2 bg-brand-red hover:bg-brand-red/90 disabled:opacity-50 text-white rounded-xl text-xs font-bold transition cursor-pointer"
                >
                  Lägg till
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: Redigera befintligt uppdrag */}
      {editingItem && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-md p-5 space-y-4">
            <div className="flex items-center justify-between border-b border-zinc-800 pb-3">
              <h4 className="text-sm font-bold text-white">Redigera delmål / quest</h4>
              <button
                type="button"
                onClick={() => setEditingItem(null)}
                className="text-zinc-400 hover:text-white cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <form onSubmit={handleSaveEdit} className="space-y-3">
              <div>
                <label className="text-xs font-semibold text-zinc-400 block mb-1">Titel</label>
                <input
                  type="text"
                  value={editTitleDraft}
                  onChange={(e) => setEditTitleDraft(e.target.value)}
                  autoFocus
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-xs text-white placeholder-zinc-600 focus:outline-none focus:border-brand-red"
                />
              </div>

              <div>
                <label className="text-xs font-semibold text-zinc-400 block mb-1">Akt / Grupp</label>
                <input
                  type="text"
                  value={editActDraft}
                  onChange={(e) => setEditActDraft(e.target.value)}
                  placeholder="t.ex. Akt 1..."
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-xs text-white placeholder-zinc-600 focus:outline-none focus:border-brand-red"
                />
              </div>

              <div className="flex justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setEditingItem(null)}
                  className="px-3 py-2 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 rounded-xl text-xs font-semibold transition cursor-pointer"
                >
                  Avbryt
                </button>
                <button
                  type="submit"
                  disabled={!editTitleDraft.trim()}
                  className="px-4 py-2 bg-brand-red hover:bg-brand-red/90 disabled:opacity-50 text-white rounded-xl text-xs font-bold transition cursor-pointer"
                >
                  Spara ändringar
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MODAL: Klistra in text manuellt */}
      {showPasteModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-lg p-5 space-y-4">
            <div className="flex items-center justify-between border-b border-zinc-800 pb-3">
              <div className="flex items-center gap-2">
                <Clipboard className="w-4 h-4 text-brand-red" />
                <h4 className="text-sm font-bold text-white">Klistra in kapitellista manuellt</h4>
              </div>
              <button
                type="button"
                onClick={() => setShowPasteModal(false)}
                className="text-zinc-400 hover:text-white cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <p className="text-xs text-zinc-400">
              Klistra in en rad per kapitel eller uppdrag. Rader med <code>Akt 1</code> eller <code># Region</code> tolkas automatiskt som akt-rubriker.
            </p>

            <textarea
              value={pasteRawText}
              onChange={(e) => setPasteRawText(e.target.value)}
              placeholder={`# Akt 1: Prolog\nKapitel 1: Ankomsten\nKapitel 2: Skuggan i skogen\n\n# Akt 2: Hjärtat\nKapitel 3: Första templet\nKapitel 4: Slutstriden`}
              rows={9}
              className="w-full bg-zinc-950 border border-zinc-800 rounded-xl p-3 text-xs text-white placeholder-zinc-600 focus:outline-none focus:border-brand-red font-mono"
            />

            <div className="flex items-center justify-between pt-1">
              <span className="text-[11px] text-zinc-500">
                {pasteRawText.split('\n').filter((l) => l.trim().length > 1).length} rader identifierade
              </span>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setShowPasteModal(false)}
                  className="px-3 py-2 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 rounded-xl text-xs font-semibold transition cursor-pointer"
                >
                  Avbryt
                </button>
                <button
                  type="button"
                  onClick={handleImportPastedText}
                  disabled={!pasteRawText.trim()}
                  className="px-4 py-2 bg-brand-red hover:bg-brand-red/90 disabled:opacity-50 text-white rounded-xl text-xs font-bold transition cursor-pointer"
                >
                  Importera rader
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: Gemini API-nyckel */}
      {showApiKeyModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-md p-5 space-y-4">
            <div className="flex items-center justify-between border-b border-zinc-800 pb-3">
              <div className="flex items-center gap-2">
                <Key className="w-4 h-4 text-amber-400" />
                <h4 className="text-sm font-bold text-white">Google Gemini API-nyckel</h4>
              </div>
              <button
                type="button"
                onClick={() => setShowApiKeyModal(false)}
                className="text-zinc-400 hover:text-white cursor-pointer"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <p className="text-xs text-zinc-400 leading-relaxed">
              Ange din kostnadsfria Gemini API-nyckel från Google AI Studio. Nyckeln sparas lokalt i din webbläsare och används för att bygga 1:1 IGN Walkthrough-listor i realtid.
            </p>

            <div className="space-y-1">
              <input
                type="password"
                value={apiKeyInput}
                onChange={(e) => setApiKeyInput(e.target.value)}
                placeholder="AIzaSy..."
                className="w-full bg-zinc-950 border border-zinc-800 rounded-xl px-3 py-2 text-xs text-white placeholder-zinc-600 focus:outline-none focus:border-brand-red font-mono"
              />
              <div className="flex justify-end">
                <a
                  href="https://aistudio.google.com/app/apikey"
                  target="_blank"
                  rel="noreferrer"
                  className="text-[11px] text-zinc-500 hover:text-amber-400 underline flex items-center gap-1 pt-1"
                >
                  <span>Skaffa gratis nyckel på Google AI Studio</span>
                  <ExternalLink className="w-2.5 h-2.5" />
                </a>
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-zinc-800/80">
              <button
                type="button"
                onClick={() => setShowApiKeyModal(false)}
                className="px-3 py-2 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 rounded-xl text-xs font-semibold transition cursor-pointer"
              >
                Avbryt
              </button>
              <button
                type="button"
                onClick={() => {
                  saveApiKey(apiKeyInput);
                  setShowApiKeyModal(false);
                  if (apiKeyInput.trim()) {
                    handleGenerateWithAI();
                  }
                }}
                className="px-4 py-2 bg-brand-red hover:bg-brand-red/90 text-white rounded-xl text-xs font-bold transition cursor-pointer"
              >
                Spara nyckel
              </button>
            </div>
          </div>
        </div>
      )}

      {/* MODAL: Bekräfta rensning av alla kapitel */}
      {showClearConfirmModal && (
        <div className="fixed inset-0 bg-black/80 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-zinc-900 border border-zinc-800 rounded-2xl w-full max-w-sm p-5 space-y-4">
            <div className="flex items-center gap-2.5 text-red-400">
              <AlertCircle className="w-5 h-5 flex-shrink-0" />
              <h4 className="text-sm font-bold text-white">Rensa alla kapitel?</h4>
            </div>

            <p className="text-xs text-zinc-400 leading-relaxed">
              Är du säker på att du vill rensa samtliga {totalCount} kapitel och uppdrag för{' '}
              <strong className="text-white">{game.title}</strong>? Detta går inte att ångra.
            </p>

            <div className="flex justify-end gap-2 pt-2 border-t border-zinc-800/80">
              <button
                type="button"
                onClick={() => setShowClearConfirmModal(false)}
                className="px-3 py-2 bg-zinc-800 hover:bg-zinc-700 text-zinc-300 rounded-xl text-xs font-semibold transition cursor-pointer"
              >
                Behåll
              </button>
              <button
                type="button"
                onClick={handleClearAllTodos}
                className="px-4 py-2 bg-red-600 hover:bg-red-500 text-white rounded-xl text-xs font-bold transition cursor-pointer"
              >
                Rensa alla
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
