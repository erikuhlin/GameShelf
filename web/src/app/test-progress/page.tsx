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
  { name: '007 First Light', displayName: '007 First Light', type: 'chapters', icon: BookOpen, tag: '10 Kapitel (18 Uppdrag)', hltb: 14 },
  { name: 'Silent Hill 2', displayName: 'Silent Hill 2 (Remake)', type: 'chapters', icon: BookOpen, tag: '14 Zoner & Skräck', hltb: 16 },
  { name: 'The Last of Us Part I', displayName: 'The Last of Us Part I', type: 'chapters', icon: BookOpen, tag: '12 Kapitel & 4 Årstider', hltb: 15 },
  { name: 'Cyberpunk 2077', displayName: 'Cyberpunk 2077', type: 'main_quests', icon: Layers, tag: 'Huvuduppdrag i Akterna', hltb: 25 },
  { name: 'Elden Ring', displayName: 'Elden Ring', type: 'bosses', icon: Skull, tag: '11 Huvudbossar', hltb: 58 },
  { name: 'Super Mario Odyssey', displayName: 'Super Mario Odyssey', type: 'worlds', icon: Globe, tag: 'Riken / Världar', hltb: 13 },
  { name: 'The Witcher 3: Wild Hunt', displayName: 'The Witcher 3', type: 'main_quests', icon: Layers, tag: 'Regioner & Storyquests', hltb: 52 },
  { name: 'Resident Evil 4', displayName: 'Resident Evil 4', type: 'chapters', icon: BookOpen, tag: 'Byn, Slottet, Ön', hltb: 16 },
  { name: 'Baldur\'s Gate 3', displayName: 'Baldur\'s Gate 3', type: 'main_quests', icon: Layers, tag: 'Akter & Vändpunkter', hltb: 65 },
  { name: 'Rocket League', displayName: 'Rocket League', type: 'none', icon: Gamepad2, tag: 'Ej linjärt / MP', hltb: 0 },
];

export default function TestProgressPage() {
  const [selectedGameName, setSelectedGameName] = useState<string>('Kingdom Come: Deliverance II');
  const [searchInput, setSearchInput] = useState<string>('');
  const [guideUrlInput, setGuideUrlInput] = useState<string>('');
  const [rawTextInput, setRawTextInput] = useState<string>('');
  const [inputMode, setInputMode] = useState<'url' | 'text'>('text');
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
  const [estimatedHours, setEstimatedHours] = useState<number>(16);

  // Inställningar för test
  const [spoilerProtection, setSpoilerProtection] = useState<boolean>(true);
  const [revealedIds, setRevealedIds] = useState<Set<string>>(new Set());
  const [newTodoTitle, setNewTodoTitle] = useState<string>('');
  const [copiedJson, setCopiedJson] = useState<boolean>(false);

  // Inline-redigering av delmål
  const [editingTodoId, setEditingTodoId] = useState<string | null>(null);
  const [editingTodoText, setEditingTodoText] = useState<string>('');

  const startEditing = (todo: ActiveTodo) => {
    setEditingTodoId(todo.id);
    setEditingTodoText(todo.title);
  };

  const saveEditing = (id: string) => {
    if (editingTodoText.trim()) {
      setTodos((prev) =>
        prev.map((t) => (t.id === id ? { ...t, title: editingTodoText.trim() } : t))
      );
    }
    setEditingTodoId(null);
  };

  // Ladda API-nyckel från localStorage om den sparats tidigare
  useEffect(() => {
    const savedKey = localStorage.getItem('gameshelf_gemini_key');
    if (savedKey) setGeminiApiKey(savedKey);
  }, []);

  const saveApiKey = (key: string) => {
    setGeminiApiKey(key);
    localStorage.setItem('gameshelf_gemini_key', key);
  };

  // Hämta mall för ett spel
  const loadGameTemplate = async (
    title: string,
    currentGranularity: Granularity = granularity,
    shouldForceAI: boolean = forceAI,
    customGuideUrl?: string
  ) => {
    setIsLoading(true);
    setErrorMsg(null);
    setRevealedIds(new Set());

    const activeUrl = customGuideUrl !== undefined ? customGuideUrl : guideUrlInput;

    try {
      const res = await fetch('/api/games/progress-template', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        signal: AbortSignal.timeout(45000),
        body: JSON.stringify({
          gameTitle: title,
          guideUrl: activeUrl.trim() || undefined,
          geminiApiKey: geminiApiKey.trim() || undefined,
          granularity: currentGranularity,
          forceAI: shouldForceAI || Boolean(activeUrl.trim()),
        }),
      });

      const data = await res.json();

      if (!res.ok) {
        if (data.notFound) {
          setErrorMsg(data.message);
        } else {
          setErrorMsg(data.error || 'Kunde inte hämta progression.');
        }
        setIsLoading(false);
        return;
      }

      setTemplate(data);
      setSelectedGameName(data.gameTitle);

      // Skapa aktiva todos från mallen
      const initialTodos: ActiveTodo[] = (data.items || []).map((item: TemplateItem, index: number) => ({
        id: item.id || `todo-${index}`,
        title: item.title,
        chapterGroup: item.chapterGroup,
        isDone: false,
        order: item.order || index + 1,
        isOptional: item.isOptional,
      }));
      setTodos(initialTodos);

      // Sätt ungefärlig HLTB om vi känner till spelet
      const preset = PRESET_GAMES.find(
        (p) => p.name.toLowerCase() === title.toLowerCase() || p.displayName.toLowerCase() === title.toLowerCase()
      );
      if (preset) {
        setEstimatedHours(preset.hltb);
      } else {
        setEstimatedHours(20);
      }
    } catch (err: any) {
      if (err.name === 'TimeoutError' || err.name === 'AbortError') {
        setErrorMsg('Hämtningen tog för lång tid (timeout). Kontrollera att länken fungerar eller prova igen.');
      } else {
        setErrorMsg(err.message || 'Nätverksfel vid hämtning');
      }
    } finally {
      setIsLoading(false);
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
      isDone: false,
      order: todos.length + 1,
    };
    setTodos([...todos, newItem]);
    setNewTodoTitle('');
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

        {/* Steg 1: Välj / Sök Spel */}
        <section className="bg-gray-900/60 border border-gray-800 rounded-2xl p-5 sm:p-6 space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <h2 className="text-sm font-semibold uppercase tracking-wider text-gray-300 flex items-center gap-2">
              <span className="w-5 h-5 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center text-xs font-bold">1</span>
              Välj förberett exempel eller sök valfritt spel
            </h2>

            <div className="flex items-center gap-3">
              <button
                onClick={() => setShowApiKeyInput(!showApiKeyInput)}
                className="text-xs text-amber-400 hover:text-amber-300 flex items-center gap-1.5 transition-colors font-medium"
              >
                <Key className="w-3.5 h-3.5" />
                {showApiKeyInput ? 'Dölj AI-nyckel' : 'Gemini AI-nyckel'}
              </button>
            </div>
          </div>

          {/* Valfri Gemini API Key inställning */}
          {showApiKeyInput && (
            <div className="bg-gray-950/80 border border-amber-500/30 rounded-xl p-4 text-xs space-y-2">
              <div className="flex items-center gap-2 text-amber-300 font-medium">
                <Key className="w-4 h-4" />
                Google Gemini API-inställning
              </div>
              <p className="text-gray-400">
                För att testa <strong>vilket spel som helst i världen</strong> eller tvinga AI att analysera om kurerade spel med olika detaljnivåer:
              </p>
              <div className="flex gap-2">
                <input
                  type="password"
                  placeholder="Klistra in Gemini API-nyckel här..."
                  value={geminiApiKey}
                  onChange={(e) => saveApiKey(e.target.value)}
                  className="bg-gray-900 border border-gray-700 rounded-lg px-3 py-1.5 text-xs text-white w-full focus:outline-none focus:border-red-500"
                />
              </div>
              <div className="flex items-center gap-2 pt-1 text-gray-400">
                <label className="flex items-center gap-1.5 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={forceAI}
                    onChange={(e) => setForceAI(e.target.checked)}
                    className="rounded border-gray-700 bg-gray-900 text-red-600 focus:ring-0"
                  />
                  <span>Tvinga AI-generering (använd inte förberedda mallar för snabbvalsspelen)</span>
                </label>
              </div>
            </div>
          )}

          {/* Snabbvals-knappar */}
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
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
                      : 'bg-gray-950/50 border-gray-800 text-gray-300 hover:bg-gray-800/50 hover:border-gray-700'
                  }`}
                >
                  <div className="flex items-center justify-between mb-2">
                    <Icon className={`w-4 h-4 ${isSelected ? 'text-red-400' : 'text-gray-500'}`} />
                    <span className="text-[10px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-400 font-mono">
                      {p.tag}
                    </span>
                  </div>
                  <span className="text-xs font-semibold line-clamp-1">{p.displayName}</span>
                </button>
              );
            })}
          </div>

          {/* Sökfält för valfritt spel */}
          <form
            onSubmit={(e) => {
              e.preventDefault();
              if (searchInput.trim()) {
                setSelectedGameName(searchInput.trim());
                loadGameTemplate(searchInput.trim(), granularity, forceAI);
              }
            }}
            className="flex gap-2 pt-2"
          >
            <div className="relative flex-1">
              <Search className="w-4 h-4 text-gray-500 absolute left-3 top-1/2 -translate-y-1/2" />
              <input
                type="text"
                placeholder="Skriv in valfritt spel (t.ex. Silent Hill 2, Alan Wake 2, Halo...)"
                value={searchInput}
                onChange={(e) => setSearchInput(e.target.value)}
                className="w-full bg-gray-950 border border-gray-800 rounded-xl pl-9 pr-4 py-2 text-sm text-white placeholder-gray-500 focus:outline-none focus:border-red-500 transition-colors"
              />
            </div>
            <button
              type="submit"
              disabled={isLoading || !searchInput.trim()}
              className="px-4 py-2 bg-red-600 hover:bg-red-500 disabled:opacity-50 text-white text-sm font-semibold rounded-xl transition-colors flex items-center gap-1.5 shadow-md"
            >
              {isLoading ? 'Söker på IGN...' : 'Sök guide på IGN'}
            </button>
          </form>

          {/* Alternativ 2: Importera från guide (Text eller URL) */}
          <div className="bg-gray-950/70 border border-blue-500/30 rounded-xl p-3.5 space-y-3">
            <div className="flex flex-wrap items-center justify-between gap-2 text-xs">
              <span className="font-semibold text-blue-400 flex items-center gap-1.5">
                <Globe className="w-4 h-4" />
                Alternativ 2: Importera guide (100% träffsäkert)
              </span>
              <div className="inline-flex rounded-lg bg-gray-900 p-0.5 border border-gray-800 text-[11px]">
                <button
                  type="button"
                  onClick={() => setInputMode('text')}
                  className={`px-2.5 py-1 rounded-md font-medium transition ${
                    inputMode === 'text'
                      ? 'bg-blue-600 text-white shadow-sm'
                      : 'text-gray-400 hover:text-white'
                  }`}
                >
                  Klistra in text / lista
                </button>
                <button
                  type="button"
                  onClick={() => setInputMode('url')}
                  className={`px-2.5 py-1 rounded-md font-medium transition ${
                    inputMode === 'url'
                      ? 'bg-blue-600 text-white shadow-sm'
                      : 'text-gray-400 hover:text-white'
                  }`}
                >
                  Guide-URL
                </button>
              </div>
            </div>

            {inputMode === 'text' ? (
              <div className="space-y-2">
                <p className="text-[11px] text-gray-400">
                  Kopiera kapitellistan eller texten från en walkthrough (t.ex. PowerPyx, IGN eller Reddit) och klistra in här. Den skapar checklistan <strong>omedelbart på 1 millisekund</strong> utan risk för blockering eller timeout!
                </p>
                <textarea
                  rows={4}
                  placeholder={`Klistra in kapitel eller uppdrag här (ett per rad, t.ex):\n1. East South Vale\n2. Wood Side Apartments\n3. Blue Creek Apartments\n4. Brookhaven Hospital...`}
                  value={rawTextInput}
                  onChange={(e) => setRawTextInput(e.target.value)}
                  className="w-full bg-gray-900 border border-gray-700 rounded-lg p-2.5 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 font-mono leading-relaxed"
                />
                <div className="flex justify-between items-center pt-1">
                  <span className="text-[10px] text-gray-500">
                    Tips: Tar bort siffror, bindestreck och formatering automatiskt.
                  </span>
                  <button
                    type="button"
                    onClick={() => parseFromRawText(rawTextInput, searchInput.trim() || selectedGameName)}
                    disabled={!rawTextInput.trim()}
                    className="px-4 py-2 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white text-xs font-semibold rounded-lg transition-colors flex items-center gap-1.5 shadow-md shadow-blue-500/10"
                  >
                    <ListChecks className="w-3.5 h-3.5" />
                    Skapa checklista direkt
                  </button>
                </div>
              </div>
            ) : (
              <div className="space-y-2">
                <p className="text-[11px] text-gray-400">
                  Klistra in en länk till spelets walkthrough eller kapitelöversikt (från t.ex. PowerPyx, IGN, Game8).
                </p>
                <div className="flex flex-col sm:flex-row gap-2 pt-1">
                  <input
                    type="url"
                    placeholder="https://www.powerpyx.com/... eller https://www.ign.com/wikis/..."
                    value={guideUrlInput}
                    onChange={(e) => setGuideUrlInput(e.target.value)}
                    className="flex-1 bg-gray-900 border border-gray-700 rounded-lg px-3 py-2 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-blue-500 font-mono"
                  />
                  <button
                    type="button"
                    onClick={() => {
                      if (guideUrlInput.trim()) {
                        loadGameTemplate(searchInput.trim() || selectedGameName, granularity, true, guideUrlInput.trim());
                      }
                    }}
                    disabled={isLoading || !guideUrlInput.trim()}
                    className="px-4 py-2 bg-blue-600 hover:bg-blue-500 disabled:opacity-50 text-white text-xs font-semibold rounded-lg transition-colors flex items-center justify-center gap-1.5 whitespace-nowrap shadow-md shadow-blue-500/10"
                  >
                    {isLoading ? (
                      <>
                        <Globe className="w-3.5 h-3.5 animate-spin" />
                        Läser guide...
                      </>
                    ) : (
                      <>
                        <Globe className="w-3.5 h-3.5" />
                        Extrahera från guide-URL
                      </>
                    )}
                  </button>
                </div>
              </div>
            )}
          </div>

          {errorMsg && (
            <div className="p-3 rounded-xl bg-red-950/40 border border-red-800/60 text-red-300 text-xs flex items-start gap-2">
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
                  {template.gameTitle}
                  {template.source === 'curated' && (
                    <span className="text-[10px] bg-green-500/20 text-green-400 border border-green-500/30 px-2 py-0.5 rounded-full font-medium">
                      Verifierad mall
                    </span>
                  )}
                  {template.source === 'ai' && (
                    <span className="text-[10px] bg-purple-500/20 text-purple-400 border border-purple-500/30 px-2 py-0.5 rounded-full font-medium flex items-center gap-1">
                      <Sparkles className="w-3 h-3" /> Genererad med {template.modelUsed || 'Gemini'}
                    </span>
                  )}
                  {template.source === 'scraped_guide' && (
                    <span className="text-[10px] bg-blue-500/20 text-blue-400 border border-blue-500/30 px-2 py-0.5 rounded-full font-medium flex items-center gap-1">
                      <Globe className="w-3 h-3" /> Hämtad från källguide ({template.modelUsed || 'Gemini'})
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
                  <div className="flex items-center justify-between">
                    <h3 className="text-sm font-semibold uppercase tracking-wider text-gray-300 flex items-center gap-2">
                      <span className="w-5 h-5 rounded-full bg-red-500/20 text-red-400 flex items-center justify-center text-xs font-bold">2</span>
                      Interaktiv Framstegsmätare
                    </h3>

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

                  {/* Snabbknappar */}
                  <div className="flex flex-wrap items-center justify-between gap-2 pt-2">
                    <button
                      onClick={checkNextTodo}
                      disabled={doneCount === totalCount}
                      className="px-4 py-2 bg-red-600 hover:bg-red-500 disabled:opacity-40 text-white text-xs font-semibold rounded-xl transition-all shadow-md flex items-center gap-1.5"
                    >
                      <CheckCircle2 className="w-4 h-4" />
                      Bocka av nästa kapitel ({currentChapterIndex < todos.length ? todos[currentChapterIndex]?.title : 'Alla klara!'})
                    </button>

                    <button
                      onClick={resetAll}
                      className="px-3 py-1.5 bg-gray-800 hover:bg-gray-700 text-gray-300 text-xs rounded-xl transition-colors flex items-center gap-1"
                    >
                      <RotateCcw className="w-3.5 h-3.5" />
                      Nollställ framsteg
                    </button>
                  </div>

                  {/* Steg 4: Själva Checklistan */}
                  <div className="border border-gray-800 rounded-xl overflow-hidden bg-gray-950/40 divide-y divide-gray-800/60 mt-4">
                    {todos.map((item, idx) => {
                      const isFuture = idx > currentChapterIndex && !item.isDone;
                      const isHiddenBySpoiler = spoilerProtection && isFuture && !revealedIds.has(item.id);

                      return (
                        <div
                          key={item.id}
                          className={`p-3.5 flex items-center gap-3 transition-colors ${
                            item.isDone
                              ? 'bg-emerald-950/10 text-gray-400'
                              : idx === currentChapterIndex
                              ? 'bg-red-500/5 text-white'
                              : 'text-gray-300 hover:bg-gray-900/40'
                          }`}
                        >
                          {/* Checkbox */}
                          <button
                            onClick={() => toggleTodo(item.id)}
                            className="flex-shrink-0 text-gray-400 hover:text-white transition-colors"
                          >
                            {item.isDone ? (
                              <CheckCircle2 className="w-5 h-5 text-emerald-400" />
                            ) : (
                              <Circle className={`w-5 h-5 ${idx === currentChapterIndex ? 'text-red-400' : 'text-gray-600'}`} />
                            )}
                          </button>

                          {/* Titel & ChapterGroup */}
                          <div className="flex-1 min-w-0">
                            {isHiddenBySpoiler ? (
                              <div className="flex items-center gap-2 text-xs text-gray-500 italic">
                                <Shield className="w-3.5 h-3.5 text-amber-500/70" />
                                <span>Delmål {idx + 1} (Titel dold av spoilerskydd)</span>
                                <button
                                  onClick={() => toggleReveal(item.id)}
                                  className="text-[11px] not-italic text-amber-400 hover:underline flex items-center gap-1 ml-1"
                                >
                                  <Eye className="w-3 h-3" /> Visa
                                </button>
                              </div>
                            ) : (
                              <div className="flex flex-wrap items-center gap-2">
                                {item.chapterGroup && (
                                  <span className="text-[10px] px-2 py-0.5 rounded-md bg-gray-800/90 text-gray-400 font-medium shrink-0 border border-gray-700/50">
                                    {item.chapterGroup}
                                  </span>
                                )}
                                {editingTodoId === item.id ? (
                                  <div className="flex items-center gap-1.5 flex-1 min-w-[200px]">
                                    <input
                                      type="text"
                                      value={editingTodoText}
                                      onChange={(e) => setEditingTodoText(e.target.value)}
                                      onBlur={() => saveEditing(item.id)}
                                      onKeyDown={(e) => {
                                        if (e.key === 'Enter') saveEditing(item.id);
                                        if (e.key === 'Escape') setEditingTodoId(null);
                                      }}
                                      autoFocus
                                      className="bg-gray-900 border border-blue-500 rounded px-2 py-0.5 text-xs text-white focus:outline-none w-full"
                                    />
                                    <button
                                      type="button"
                                      onClick={() => saveEditing(item.id)}
                                      className="px-2 py-0.5 bg-blue-600 hover:bg-blue-500 text-white rounded text-[11px] font-medium"
                                    >
                                      Spara
                                    </button>
                                  </div>
                                ) : (
                                  <span
                                    onClick={() => startEditing(item)}
                                    className={`text-sm font-medium cursor-pointer hover:text-white transition-colors group/title flex items-center gap-1.5 ${
                                      item.isDone ? 'line-through text-gray-500' : 'text-gray-200'
                                    }`}
                                    title="Klicka för att redigera titel"
                                  >
                                    <span>{item.title}</span>
                                    <Pencil className="w-3 h-3 text-gray-500 opacity-40 group-hover/title:opacity-100 transition-opacity" />
                                  </span>
                                )}
                                {idx === currentChapterIndex && !item.isDone && (
                                  <span className="text-[10px] px-1.5 py-0.5 rounded bg-red-500/20 text-red-400 font-semibold uppercase">
                                    Aktuellt mål
                                  </span>
                                )}
                                {item.isOptional && (
                                  <span className="text-[10px] px-1.5 py-0.5 rounded bg-gray-800 text-gray-400">
                                    Frivilligt
                                  </span>
                                )}
                                {spoilerProtection && isFuture && revealedIds.has(item.id) && (
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
                            className="text-gray-600 hover:text-red-400 p-1 transition-colors"
                            title="Ta bort från lista"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      );
                    })}
                  </div>

                  {/* Lägg till eget delmål */}
                  <form onSubmit={handleAddCustomTodo} className="flex gap-2 pt-2">
                    <input
                      type="text"
                      placeholder="Lägg till eget delmål (t.ex. 'Klara DLC' eller 'Samla alla vapen')..."
                      value={newTodoTitle}
                      onChange={(e) => setNewTodoTitle(e.target.value)}
                      className="flex-1 bg-gray-950 border border-gray-800 rounded-xl px-3.5 py-2 text-xs text-white placeholder-gray-500 focus:outline-none focus:border-red-500"
                    />
                    <button
                      type="submit"
                      disabled={!newTodoTitle.trim()}
                      className="px-3 py-2 bg-gray-800 hover:bg-gray-700 disabled:opacity-50 text-white text-xs font-semibold rounded-xl flex items-center gap-1 transition-colors"
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
