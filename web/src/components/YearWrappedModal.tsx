'use client';

import React, { useState, useMemo } from 'react';
import { Game } from '@/types/game';
import { UserProfile } from '@/types/profile';
import {
  X,
  Trophy,
  Crown,
  Star,
  Clock,
  Sparkles,
  Share2,
  Check,
  Gamepad2,
  Calendar,
  Layers,
  ChevronDown,
} from 'lucide-react';

interface YearWrappedModalProps {
  isOpen: boolean;
  onClose: () => void;
  games: Game[];
  profile: UserProfile | null;
  onUpdateProfile: (updated: UserProfile) => void;
}

export function YearWrappedModal({
  isOpen,
  onClose,
  games,
  profile,
  onUpdateProfile,
}: YearWrappedModalProps) {
  const currentYear = new Date().getFullYear();
  const [selectedYear, setSelectedYear] = useState<number>(currentYear);
  const [showStoryPreview, setShowStoryPreview] = useState(false);
  const [copiedLink, setCopiedLink] = useState(false);

  // Samla alla tillgängliga år
  const availableYears = useMemo(() => {
    const years = new Set<number>([currentYear, currentYear - 1, currentYear - 2]);
    games.forEach((g) => {
      if (g.completed_year) {
        years.add(g.completed_year);
      } else if (g.completed_date) {
        const y = new Date(g.completed_date).getFullYear();
        if (!isNaN(y)) years.add(y);
      }
    });
    return Array.from(years).sort((a, b) => b - a);
  }, [games, currentYear]);

  // Spel som avklarats under det valda året
  const yearCompletedGames = useMemo(() => {
    return games.filter((g) => {
      if (g.status !== 'completed') return false;
      if (g.completed_year === selectedYear) return true;
      if (g.completed_date) {
        const y = new Date(g.completed_date).getFullYear();
        return y === selectedYear;
      }
      return false;
    });
  }, [games, selectedYear]);

  // Kandidater för GOTY (om inga är datumförsedda för året, visa alla genomspelade)
  const candidateGames = useMemo(() => {
    if (yearCompletedGames.length > 0) return yearCompletedGames;
    return games.filter((g) => g.status === 'completed');
  }, [yearCompletedGames, games]);

  // Krönt GOTY för valt år
  const crownedGotyGame = useMemo(() => {
    const gotyId = profile?.gotyByYear?.[String(selectedYear)];
    if (!gotyId) return null;
    return games.find((g) => g.id === gotyId || String(g.igdb_id) === gotyId) || null;
  }, [profile, selectedYear, games]);

  // Total speltid (timmar)
  const totalYearHours = useMemo(() => {
    return yearCompletedGames.reduce((acc, g) => {
      const hours = Math.max(g.hours_played || 0, g.estimated_hours || 0);
      return acc + hours;
    }, 0);
  }, [yearCompletedGames]);

  // Snittbetyg
  const averageYearRating = useMemo(() => {
    const rated = yearCompletedGames.filter((g) => g.rating && g.rating > 0);
    if (rated.length === 0) return null;
    const sum = rated.reduce((acc, g) => acc + (g.rating || 0), 0);
    return (sum / rated.length).toFixed(1);
  }, [yearCompletedGames]);

  // Toppgenre
  const topGenre = useMemo(() => {
    const counts: Record<string, number> = {};
    yearCompletedGames.forEach((g) => {
      g.genres?.forEach((genre) => {
        counts[genre] = (counts[genre] || 0) + 1;
      });
    });
    const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
    return sorted[0]?.[0] || null;
  }, [yearCompletedGames]);

  // Topp-plattform
  const topPlatform = useMemo(() => {
    const counts: Record<string, number> = {};
    yearCompletedGames.forEach((g) => {
      g.platforms?.forEach((p) => {
        counts[p] = (counts[p] || 0) + 1;
      });
    });
    const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
    return sorted[0]?.[0] || null;
  }, [yearCompletedGames]);

  if (!isOpen) return null;

  const handleSelectGoty = (game: Game) => {
    if (!profile) return;
    const currentMap = { ...(profile.gotyByYear || {}) };
    currentMap[String(selectedYear)] = game.id;
    onUpdateProfile({
      ...profile,
      gotyByYear: currentMap,
    });
  };

  const handleRemoveGoty = () => {
    if (!profile) return;
    const currentMap = { ...(profile.gotyByYear || {}) };
    delete currentMap[String(selectedYear)];
    onUpdateProfile({
      ...profile,
      gotyByYear: currentMap,
    });
  };

  const handleCopyStoryText = () => {
    const text = `🏆 Mitt Spelår ${selectedYear} Wrapped på Gameshelf!\n👑 Årets Spel (GOTY): ${
      crownedGotyGame ? crownedGotyGame.title : 'Ej vald än'
    }\n🎮 Genomspelade: ${yearCompletedGames.length} spel\n⏱️ Total speltid: ${
      totalYearHours > 0 ? totalYearHours + ' timmar' : '—'
    }\n⭐ Snittbetyg: ${averageYearRating ? averageYearRating + '/10' : '—'}\n#Gameshelf #GOTY #SpelåretWrapped`;

    navigator.clipboard.writeText(text);
    setCopiedLink(true);
    setTimeout(() => setCopiedLink(false), 2500);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/80 backdrop-blur-md overflow-y-auto">
      <div className="relative w-full max-w-2xl bg-[#121318] border border-amber-500/30 rounded-3xl shadow-2xl overflow-hidden my-auto max-h-[92vh] flex flex-col">
        {/* Header med årsväljare */}
        <div className="flex items-center justify-between p-4 sm:p-5 border-b border-white/10 bg-gradient-to-r from-amber-500/15 via-transparent to-amber-500/10 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-10 h-10 rounded-2xl bg-amber-500/20 border border-amber-500/40 flex items-center justify-center text-xl shadow-md">
              👑
            </div>
            <div>
              <div className="text-[10px] font-black tracking-widest text-amber-400 uppercase">
                Spelåret Wrapped
              </div>
              <h2 className="text-lg sm:text-xl font-extrabold text-white">
                Game of the Year & Sammanfattning
              </h2>
            </div>
          </div>

          <div className="flex items-center gap-2">
            <select
              value={selectedYear}
              onChange={(e) => setSelectedYear(Number(e.target.value))}
              className="bg-zinc-900 border border-amber-500/40 text-amber-300 font-bold text-xs rounded-xl px-3 py-1.5 focus:outline-none focus:border-amber-400 cursor-pointer"
            >
              {availableYears.map((y) => (
                <option key={y} value={y}>
                  År {y}
                </option>
              ))}
            </select>

            <button
              onClick={onClose}
              className="w-8 h-8 rounded-full bg-zinc-800 hover:bg-zinc-700 text-zinc-400 hover:text-white flex items-center justify-center transition"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Modal Scroll Content */}
        <div className="p-4 sm:p-6 space-y-6 overflow-y-auto">
          {/* 1. KORA GOTY KORT */}
          <div className="rounded-2xl p-4 sm:p-5 bg-gradient-to-r from-amber-500/10 via-zinc-900/90 to-amber-950/20 border border-amber-500/30 relative">
            <div className="flex items-center justify-between mb-3">
              <div className="flex items-center gap-2">
                <span className="text-base">👑</span>
                <h3 className="font-extrabold text-sm sm:text-base text-white">
                  Ditt Game of the Year {selectedYear}
                </h3>
              </div>
              {crownedGotyGame && (
                <button
                  onClick={handleRemoveGoty}
                  className="text-[11px] font-bold text-amber-400 hover:text-amber-300 transition"
                >
                  Byt vinnare
                </button>
              )}
            </div>

            {crownedGotyGame ? (
              // Krönt vinnare
              <div className="flex items-center gap-4 bg-zinc-950/60 p-3.5 rounded-xl border border-amber-500/40">
                <div className="relative w-16 h-22 rounded-lg overflow-hidden bg-zinc-800 shrink-0 border border-amber-500/40 shadow-lg">
                  {crownedGotyGame.cover_url ? (
                    <img
                      src={crownedGotyGame.cover_url}
                      alt={crownedGotyGame.title}
                      className="w-full h-full object-cover"
                    />
                  ) : (
                    <div className="w-full h-full flex items-center justify-center text-zinc-600">
                      🎮
                    </div>
                  )}
                  <span className="absolute top-1 left-1 px-1.5 py-0.5 bg-amber-400 text-black text-[9px] font-black rounded shadow">
                    1:A PLATS 👑
                  </span>
                </div>

                <div className="min-w-0 flex-1">
                  <span className="text-[10px] font-black uppercase text-amber-400 tracking-wider">
                    Årets Spel {selectedYear}
                  </span>
                  <h4 className="font-bold text-base text-white truncate">
                    {crownedGotyGame.title}
                  </h4>
                  <div className="flex items-center gap-3 mt-1 text-xs">
                    {crownedGotyGame.rating && (
                      <span className="text-amber-400 font-bold flex items-center gap-1">
                        <Star className="w-3.5 h-3.5 fill-amber-400 text-amber-400" />
                        {crownedGotyGame.rating} / 10
                      </span>
                    )}
                    <span className="text-zinc-400 truncate">
                      {crownedGotyGame.platforms?.slice(0, 2).join(', ')}
                    </span>
                  </div>
                </div>
              </div>
            ) : (
              // Väljare
              <div className="space-y-3">
                <p className="text-xs text-zinc-300">
                  Klicka på ett spel nedan för att utse din personliga vinnare bland årets titlar:
                </p>

                {candidateGames.length === 0 ? (
                  <div className="p-4 rounded-xl bg-zinc-900/60 border border-zinc-800 text-center text-xs text-zinc-400">
                    Inga genomspelade titlar hittades för {selectedYear}. Markera spel som 'Klar' i ditt bibliotek för att nominera!
                  </div>
                ) : (
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5 max-h-56 overflow-y-auto p-1">
                    {candidateGames.map((game) => (
                      <button
                        key={game.id}
                        onClick={() => handleSelectGoty(game)}
                        className="group text-left p-2 rounded-xl bg-zinc-900/80 hover:bg-amber-500/10 border border-white/5 hover:border-amber-500/40 transition flex flex-col cursor-pointer"
                      >
                        <div className="aspect-[3/4] rounded-lg overflow-hidden bg-zinc-800 mb-1.5 relative">
                          {game.cover_url ? (
                            <img
                              src={game.cover_url}
                              alt={game.title}
                              className="w-full h-full object-cover group-hover:scale-105 transition"
                            />
                          ) : (
                            <div className="w-full h-full flex items-center justify-center text-zinc-600">
                              🎮
                            </div>
                          )}
                          {game.rating && (
                            <span className="absolute top-1 right-1 px-1.5 py-0.5 rounded bg-black/80 text-white font-bold text-[9px]">
                              ★ {game.rating}
                            </span>
                          )}
                        </div>
                        <span className="text-xs font-bold text-white truncate w-full">
                          {game.title}
                        </span>
                        <span className="text-[10px] text-amber-400 font-semibold group-hover:underline">
                          Välj som GOTY 👑
                        </span>
                      </button>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>

          {/* 2. SPELÅRET I SIFFROR (KPI GRID) */}
          <div className="space-y-3">
            <h3 className="font-extrabold text-sm text-zinc-300 uppercase tracking-wider">
              Spelåret i siffror
            </h3>

            <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
              <div className="p-3.5 rounded-2xl bg-zinc-900/60 border border-zinc-800 flex flex-col justify-between">
                <span className="text-[11px] font-semibold text-zinc-400">Genomspelade</span>
                <div className="text-2xl font-black text-white mt-1">
                  {yearCompletedGames.length} <span className="text-xs font-normal text-zinc-400">spel</span>
                </div>
                <span className="text-[10px] text-emerald-400 font-medium mt-1">Klara under {selectedYear}</span>
              </div>

              <div className="p-3.5 rounded-2xl bg-zinc-900/60 border border-zinc-800 flex flex-col justify-between">
                <span className="text-[11px] font-semibold text-zinc-400">Speltid</span>
                <div className="text-2xl font-black text-white mt-1">
                  {totalYearHours > 0 ? `${totalYearHours}h` : '—'}
                </div>
                <span className="text-[10px] text-zinc-400 mt-1">Main Story & loggat</span>
              </div>

              <div className="p-3.5 rounded-2xl bg-zinc-900/60 border border-zinc-800 flex flex-col justify-between">
                <span className="text-[11px] font-semibold text-zinc-400">Snittbetyg</span>
                <div className="text-2xl font-black text-amber-400 mt-1">
                  {averageYearRating ? `${averageYearRating}` : '—'}
                </div>
                <span className="text-[10px] text-zinc-400 mt-1">Personligt snitt</span>
              </div>

              <div className="p-3.5 rounded-2xl bg-zinc-900/60 border border-zinc-800 flex flex-col justify-between">
                <span className="text-[11px] font-semibold text-zinc-400">Toppgenre</span>
                <div className="text-lg font-black text-white mt-1 truncate">
                  {topGenre || '—'}
                </div>
                <span className="text-[10px] text-zinc-400 mt-1 truncate">{topPlatform || 'Olika plattformar'}</span>
              </div>
            </div>
          </div>

          {/* 3. STORY CARD PREVIEW & DELA */}
          <div className="p-4 rounded-2xl bg-zinc-950 border border-zinc-800 flex flex-col sm:flex-row items-center justify-between gap-4">
            <div>
              <h4 className="font-bold text-sm text-white flex items-center gap-1.5">
                <Share2 className="w-4 h-4 text-amber-400" />
                <span>Dela ditt Spelår Wrapped</span>
              </h4>
              <p className="text-xs text-zinc-400 mt-0.5">
                Visa upp ditt personliga GOTY och dina siffror för vänner och i sociala medier!
              </p>
            </div>

            <div className="flex items-center gap-2 shrink-0">
              <button
                onClick={handleCopyStoryText}
                className="px-3.5 py-2 rounded-xl bg-zinc-800 hover:bg-zinc-700 text-xs font-bold text-zinc-200 transition flex items-center gap-1.5 cursor-pointer"
              >
                {copiedLink ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Share2 className="w-3.5 h-3.5" />}
                <span>{copiedLink ? 'Kopierat!' : 'Kopiera sammanfattning'}</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
