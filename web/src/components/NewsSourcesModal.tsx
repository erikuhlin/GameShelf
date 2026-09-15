'use client';

import React, { useState, useMemo } from 'react';
import {
  X,
  Check,
  RotateCcw,
  SlidersHorizontal,
  Search,
  Sparkles,
  Layers,
} from 'lucide-react';

interface NewsSourcesModalProps {
  isOpen: boolean;
  onClose: () => void;
  allSources: string[];
  enabledSources: string[];
  onChangeEnabledSources: (sources: string[]) => void;
}

interface SourceCategory {
  id: string;
  name: string;
  icon: string;
  sources: string[];
}

const KNOWN_CATEGORIES: SourceCategory[] = [
  {
    id: 'swedish',
    name: 'Svenska spelmedier',
    icon: '🇸🇪',
    sources: ['FZ.se', 'Gamereactor SE'],
  },
  {
    id: 'official',
    name: 'Officiella bloggar',
    icon: '🏛️',
    sources: ['PlayStation Blog', 'Xbox Wire'],
  },
  {
    id: 'major',
    name: 'Stora globala medier',
    icon: '🌟',
    sources: [
      'Game Informer',
      'IGN',
      'Eurogamer',
      'GameSpot',
      'Polygon',
      'Kotaku',
      'VGC',
      'GamesRadar+',
      'VG247',
      'Destructoid',
    ],
  },
  {
    id: 'platform',
    name: 'Plattform & Format',
    icon: '🎮',
    sources: [
      'Push Square',
      'Nintendo Life',
      'Pure Xbox',
      'PC Gamer',
      'Rock Paper Shotgun',
      'PCGamesN',
      'Nintendo Everything',
    ],
  },
  {
    id: 'specialty',
    name: 'Nisch & Japanskt',
    icon: '🗾',
    sources: ['Gematsu', 'Siliconera', 'TouchArcade'],
  },
];

export function NewsSourcesModal({
  isOpen,
  onClose,
  allSources,
  enabledSources,
  onChangeEnabledSources,
}: NewsSourcesModalProps) {
  const [searchQuery, setSearchQuery] = useState('');

  // Skapa en lookup-set för snabb kontroll
  const enabledSet = useMemo(() => new Set(enabledSources), [enabledSources]);

  // Gruppera alla källor baserat på de fördefinierade kategorierna
  const categorizedGroups = useMemo(() => {
    const assigned = new Set<string>();
    const groups = KNOWN_CATEGORIES.map((cat) => {
      const available = cat.sources.filter((s) => allSources.includes(s));
      available.forEach((s) => assigned.add(s));
      return {
        ...cat,
        availableSources: available,
      };
    }).filter((g) => g.availableSources.length > 0);

    // Fånga eventuella nya källor som inte lagts till i en kategori än
    const leftover = allSources.filter((s) => !assigned.has(s) && s !== 'Alla källor');
    if (leftover.length > 0) {
      groups.push({
        id: 'other',
        name: 'Övriga källor',
        icon: '📰',
        sources: leftover,
        availableSources: leftover,
      });
    }

    return groups;
  }, [allSources]);

  if (!isOpen) return null;

  const toggleSource = (source: string) => {
    if (enabledSet.has(source)) {
      // Förhindra att avmarkera absolut alla källor
      if (enabledSources.length <= 1) return;
      onChangeEnabledSources(enabledSources.filter((s) => s !== source));
    } else {
      onChangeEnabledSources([...enabledSources, source]);
    }
  };

  const selectAll = () => {
    onChangeEnabledSources(allSources.filter((s) => s !== 'Alla källor'));
  };

  const selectSwedishOnly = () => {
    const swedish = allSources.filter((s) => ['FZ.se', 'Gamereactor SE'].includes(s));
    onChangeEnabledSources(swedish.length > 0 ? swedish : allSources);
  };

  const selectMajorOnly = () => {
    const major = allSources.filter((s) =>
      ['FZ.se', 'Gamereactor SE', 'Game Informer', 'IGN', 'Eurogamer', 'PlayStation Blog', 'Xbox Wire'].includes(s)
    );
    onChangeEnabledSources(major.length > 0 ? major : allSources);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 md:p-6 bg-black/85 backdrop-blur-md overflow-y-auto">
      <div className="relative bg-zinc-950 border border-zinc-800/90 rounded-3xl max-w-xl w-full max-h-[90vh] flex flex-col shadow-2xl overflow-hidden animate-in fade-in zoom-in-95 duration-200">
        {/* Header */}
        <div className="flex items-center justify-between px-5 sm:px-6 py-4 border-b border-zinc-800/80 bg-zinc-900/50 backdrop-blur-md">
          <div className="flex items-center gap-2.5">
            <div className="w-8 h-8 rounded-xl bg-brand-red/15 border border-brand-red/30 flex items-center justify-center text-brand-red">
              <SlidersHorizontal className="w-4 h-4" />
            </div>
            <div>
              <h2 className="text-base sm:text-lg font-bold text-white">Anpassa nyhetskällor</h2>
              <p className="text-xs text-zinc-400">
                Visar {enabledSources.length} av {allSources.filter((s) => s !== 'Alla källor').length} källor
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-2 rounded-full hover:bg-zinc-800 text-zinc-400 hover:text-white transition cursor-pointer"
            title="Stäng"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Snabbval & Sök */}
        <div className="p-4 sm:p-5 border-b border-zinc-800/60 bg-zinc-900/20 space-y-3">
          {/* Snabbknappar */}
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={selectAll}
              className="px-2.5 py-1.5 rounded-lg bg-zinc-800/90 hover:bg-zinc-700 text-zinc-200 hover:text-white text-xs font-semibold border border-zinc-700/60 transition cursor-pointer flex items-center gap-1.5"
            >
              <Check className="w-3.5 h-3.5 text-brand-red" />
              <span>Välj alla</span>
            </button>
            <button
              type="button"
              onClick={selectSwedishOnly}
              className="px-2.5 py-1.5 rounded-lg bg-zinc-800/90 hover:bg-zinc-700 text-zinc-200 hover:text-white text-xs font-semibold border border-zinc-700/60 transition cursor-pointer flex items-center gap-1.5"
            >
              <span>🇸🇪 Endast svenska</span>
            </button>
            <button
              type="button"
              onClick={selectMajorOnly}
              className="px-2.5 py-1.5 rounded-lg bg-zinc-800/90 hover:bg-zinc-700 text-zinc-200 hover:text-white text-xs font-semibold border border-zinc-700/60 transition cursor-pointer flex items-center gap-1.5"
            >
              <Sparkles className="w-3.5 h-3.5 text-amber-400" />
              <span>Största källorna</span>
            </button>
          </div>

          {/* Sökfilter */}
          <div className="relative">
            <Search className="w-4 h-4 text-zinc-400 absolute left-3 top-1/2 -translate-y-1/2 pointer-events-none" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Filtrera bland källor..."
              className="w-full pl-9 pr-3 py-2 bg-zinc-900/80 border border-zinc-800 rounded-xl text-xs text-white placeholder-zinc-500 focus:outline-none focus:border-brand-red transition"
            />
          </div>
        </div>

        {/* Källista per grupp */}
        <div className="flex-1 overflow-y-auto p-4 sm:p-5 space-y-6">
          {categorizedGroups.map((group) => {
            const filteredSources = group.availableSources.filter((s) =>
              s.toLowerCase().includes(searchQuery.toLowerCase())
            );
            if (filteredSources.length === 0) return null;

            const allInGroupSelected = filteredSources.every((s) => enabledSet.has(s));

            const toggleGroup = () => {
              if (allInGroupSelected) {
                // Avmarkera alla i gruppen så länge minst 1 källa totalt kvarstår
                const toRemove = new Set(filteredSources);
                const next = enabledSources.filter((s) => !toRemove.has(s));
                if (next.length > 0) onChangeEnabledSources(next);
              } else {
                // Markera alla i gruppen
                const next = new Set([...enabledSources, ...filteredSources]);
                onChangeEnabledSources(Array.from(next));
              }
            };

            return (
              <div key={group.id} className="space-y-2.5">
                {/* Grupprubrik med klickbar toggle */}
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="text-sm">{group.icon}</span>
                    <h3 className="text-xs font-bold uppercase tracking-wider text-zinc-300">
                      {group.name}
                    </h3>
                  </div>
                  <button
                    type="button"
                    onClick={toggleGroup}
                    className="text-[11px] font-semibold text-zinc-400 hover:text-brand-red transition cursor-pointer"
                  >
                    {allInGroupSelected ? 'Avmarkera alla' : 'Markera alla'}
                  </button>
                </div>

                {/* Grid med källor */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  {filteredSources.map((source) => {
                    const isChecked = enabledSet.has(source);
                    return (
                      <button
                        key={source}
                        type="button"
                        onClick={() => toggleSource(source)}
                        className={`flex items-center justify-between p-3 rounded-xl border text-left transition cursor-pointer ${
                          isChecked
                            ? 'bg-zinc-900/90 border-brand-red/50 text-white shadow-sm'
                            : 'bg-zinc-950/40 border-zinc-800/80 text-zinc-400 hover:border-zinc-700'
                        }`}
                      >
                        <span className="text-xs font-semibold truncate pr-2">
                          {source}
                        </span>
                        <div
                          className={`w-5 h-5 rounded-lg flex items-center justify-center flex-shrink-0 transition ${
                            isChecked
                              ? 'bg-brand-red text-white'
                              : 'bg-zinc-800 border border-zinc-700 text-transparent'
                          }`}
                        >
                          <Check className="w-3.5 h-3.5" />
                        </div>
                      </button>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </div>

        {/* Footer */}
        <div className="px-5 sm:px-6 py-4 border-t border-zinc-800/80 bg-zinc-900/50 backdrop-blur-md flex items-center justify-between gap-3">
          <span className="text-xs text-zinc-400">
            Ändringar sparas automatiskt
          </span>
          <button
            type="button"
            onClick={onClose}
            className="px-5 py-2.5 rounded-xl bg-brand-red hover:bg-red-700 text-white text-xs font-bold transition shadow-lg shadow-brand-red/20 cursor-pointer"
          >
            Klar
          </button>
        </div>
      </div>
    </div>
  );
}
