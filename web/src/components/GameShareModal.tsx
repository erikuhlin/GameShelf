'use client';

import React, { useState, useRef } from 'react';
import { Game } from '@/types/game';
import {
  X,
  Download,
  Copy,
  Check,
  Gamepad,
  Sparkles,
  Star,
  Share2,
  Calendar,
  Layers,
  Flame,
} from 'lucide-react';
import { StatusBadge } from './StatusBadge';

interface GameShareModalProps {
  isOpen: boolean;
  onClose: () => void;
  game: Game;
  developer?: string;
  releaseDateText?: string;
}

interface ShareTheme {
  id: string;
  name: string;
  bgGradient: string;
  accentColor: string;
  borderColor: string;
  glowColor: string;
  canvasBgTop: string;
  canvasBgBottom: string;
}

const THEMES: ShareTheme[] = [
  {
    id: 'crimson',
    name: 'Crimson Glow',
    bgGradient: 'from-black via-zinc-950 to-red-950/70',
    accentColor: '#ef4444',
    borderColor: 'border-red-900/50',
    glowColor: 'rgba(239, 68, 68, 0.25)',
    canvasBgTop: '#09090b',
    canvasBgBottom: '#450a0a',
  },
  {
    id: 'dark',
    name: 'Dark Velvet',
    bgGradient: 'from-zinc-900 via-zinc-950 to-black',
    accentColor: '#e4e4e7',
    borderColor: 'border-zinc-800',
    glowColor: 'rgba(255, 255, 255, 0.1)',
    canvasBgTop: '#18181b',
    canvasBgBottom: '#09090b',
  },
  {
    id: 'navy',
    name: 'Midnight Navy',
    bgGradient: 'from-slate-900 via-slate-950 to-blue-950/70',
    accentColor: '#38bdf8',
    borderColor: 'border-sky-900/50',
    glowColor: 'rgba(56, 189, 248, 0.25)',
    canvasBgTop: '#0f172a',
    canvasBgBottom: '#082f49',
  },
  {
    id: 'emerald',
    name: 'Emerald Abyss',
    bgGradient: 'from-zinc-950 via-zinc-900 to-emerald-950/70',
    accentColor: '#10b981',
    borderColor: 'border-emerald-900/50',
    glowColor: 'rgba(16, 185, 129, 0.25)',
    canvasBgTop: '#09090b',
    canvasBgBottom: '#064e3b',
  },
  {
    id: 'gold',
    name: 'Obsidian Gold',
    bgGradient: 'from-zinc-950 via-zinc-900 to-amber-950/70',
    accentColor: '#f59e0b',
    borderColor: 'border-amber-900/50',
    glowColor: 'rgba(245, 158, 11, 0.25)',
    canvasBgTop: '#09090b',
    canvasBgBottom: '#451a03',
  },
];

export function GameShareModal({
  isOpen,
  onClose,
  game,
  developer,
  releaseDateText,
}: GameShareModalProps) {
  const [selectedTheme, setSelectedTheme] = useState<ShareTheme>(THEMES[0]);
  const [isExporting, setIsExporting] = useState(false);
  const [copiedText, setCopiedText] = useState(false);
  const cardRef = useRef<HTMLDivElement>(null);

  if (!isOpen) return null;

  const displayDev = developer || game.developers?.[0] || '';
  const displayYear = releaseDateText || (game.release_year ? String(game.release_year) : '');
  const primaryPlatform = game.platforms?.[0] || '';

  // Exportera som PNG via HTML5 Canvas
  const handleDownloadImage = async () => {
    setIsExporting(true);
    try {
      const canvas = document.createElement('canvas');
      const width = 600;
      const height = 800;
      canvas.width = width * 2; // 2x retina
      canvas.height = height * 2;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;

      ctx.scale(2, 2);

      // 1. Rita Bakgrund med gradient
      const grad = ctx.createLinearGradient(0, 0, 0, height);
      grad.addColorStop(0, selectedTheme.canvasBgTop);
      grad.addColorStop(1, selectedTheme.canvasBgBottom);
      ctx.fillStyle = grad;
      ctx.fillRect(0, 0, width, height);

      // Ram med runda hörn
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)';
      ctx.lineWidth = 2;
      ctx.strokeRect(10, 10, width - 20, height - 20);

      // 2. Topp-branding (GameShelf)
      ctx.fillStyle = '#ffffff';
      ctx.font = '900 20px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
      ctx.fillText('🎮 GameShelf', 36, 54);

      if (primaryPlatform) {
        ctx.font = '700 13px -apple-system, BlinkMacSystemFont, sans-serif';
        const platWidth = ctx.measureText(primaryPlatform).width;
        ctx.fillStyle = 'rgba(255, 255, 255, 0.15)';
        ctx.beginPath();
        ctx.roundRect(width - 36 - platWidth - 20, 36, platWidth + 20, 26, 13);
        ctx.fill();
        ctx.fillStyle = '#ffffff';
        ctx.fillText(primaryPlatform, width - 36 - platWidth - 10, 53);
      }

      // 3. Omslagsbild
      const coverWidth = 220;
      const coverHeight = 310;
      const coverX = (width - coverWidth) / 2;
      const coverY = 100;

      if (game.cover_url) {
        try {
          const img = new Image();
          img.crossOrigin = 'anonymous';
          await new Promise((resolve, reject) => {
            img.onload = resolve;
            img.onerror = resolve; // Fortsätt även om bild laddning blockas av CORS
            img.src = game.cover_url!;
          });

          ctx.save();
          ctx.beginPath();
          ctx.roundRect(coverX, coverY, coverWidth, coverHeight, 16);
          ctx.clip();
          ctx.drawImage(img, coverX, coverY, coverWidth, coverHeight);
          ctx.restore();

          // Kantlinje kring omslag
          ctx.strokeStyle = 'rgba(255, 255, 255, 0.2)';
          ctx.lineWidth = 1.5;
          ctx.beginPath();
          ctx.roundRect(coverX, coverY, coverWidth, coverHeight, 16);
          ctx.stroke();
        } catch {
          // Fallback om bild ej gick att rita
          ctx.fillStyle = '#27272a';
          ctx.beginPath();
          ctx.roundRect(coverX, coverY, coverWidth, coverHeight, 16);
          ctx.fill();
        }
      } else {
        ctx.fillStyle = '#27272a';
        ctx.beginPath();
        ctx.roundRect(coverX, coverY, coverWidth, coverHeight, 16);
        ctx.fill();
      }

      // 4. Titel & Dev
      ctx.fillStyle = '#ffffff';
      ctx.font = '900 28px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(game.title, width / 2, 460);

      const subtitle = [displayDev, displayYear].filter(Boolean).join(' • ');
      if (subtitle) {
        ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
        ctx.font = '600 15px -apple-system, BlinkMacSystemFont, sans-serif';
        ctx.fillText(subtitle, width / 2, 490);
      }

      // 5. Betyg & Status
      const boxY = 530;
      const boxWidth = (width - 72 - 20) / 2;

      // Statuskort
      ctx.fillStyle = 'rgba(0, 0, 0, 0.4)';
      ctx.beginPath();
      ctx.roundRect(36, boxY, boxWidth, 75, 14);
      ctx.fill();
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
      ctx.stroke();

      ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
      ctx.font = '700 11px -apple-system, BlinkMacSystemFont, sans-serif';
      ctx.fillText('STATUS', 36 + boxWidth / 2, boxY + 28);
      ctx.fillStyle = '#ffffff';
      ctx.font = '800 16px -apple-system, BlinkMacSystemFont, sans-serif';
      ctx.fillText(game.status, 36 + boxWidth / 2, boxY + 54);

      // Betygskort
      ctx.fillStyle = 'rgba(0, 0, 0, 0.4)';
      ctx.beginPath();
      ctx.roundRect(width / 2 + 10, boxY, boxWidth, 75, 14);
      ctx.fill();
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)';
      ctx.stroke();

      ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
      ctx.font = '700 11px -apple-system, BlinkMacSystemFont, sans-serif';
      ctx.fillText('BETYG', width / 2 + 10 + boxWidth / 2, boxY + 28);
      ctx.fillStyle = '#fbbf24';
      ctx.font = '900 18px -apple-system, BlinkMacSystemFont, sans-serif';
      const ratingText = game.rating ? `⭐ ${game.rating}/10` : (game.igdb_rating ? `⭐ ${game.igdb_rating}/10` : '–');
      ctx.fillText(ratingText, width / 2 + 10 + boxWidth / 2, boxY + 54);

      // 6. Footer Watermark
      ctx.fillStyle = 'rgba(255, 255, 255, 0.4)';
      ctx.font = '600 12px -apple-system, BlinkMacSystemFont, sans-serif';
      ctx.fillText('mygameshelf.vercel.app', width / 2, 740);

      // Trigger download
      const dataUrl = canvas.toDataURL('image/png');
      const a = document.createElement('a');
      a.href = dataUrl;
      a.download = `${game.title.replace(/[^a-zA-Z0-9_-]/g, '_')}_GameShelf.png`;
      a.click();
    } catch (err) {
      console.error('Kunde inte generera delningsbild:', err);
    } finally {
      setIsExporting(false);
    }
  };

  const handleCopyLink = () => {
    if (typeof window !== 'undefined') {
      const url = `${window.location.origin}/?game=${game.igdb_id || encodeURIComponent(game.title)}`;
      navigator.clipboard.writeText(url);
      setCopiedText(true);
      setTimeout(() => setCopiedText(false), 2000);
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4 bg-black/80 backdrop-blur-md animate-in fade-in duration-200">
      <div className="bg-[#121318] border border-zinc-800 rounded-3xl w-full max-w-lg overflow-hidden shadow-2xl flex flex-col max-h-[92vh]">
        {/* Modal Header */}
        <div className="p-4 sm:p-5 border-b border-zinc-800 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Share2 className="w-5 h-5 text-brand-red" />
            <h3 className="text-base sm:text-lg font-bold text-white">Dela spelkort</h3>
          </div>
          <button
            onClick={onClose}
            className="p-1.5 rounded-xl bg-zinc-800 text-zinc-400 hover:text-white transition"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Modal Body: Preview & Themes */}
        <div className="p-4 sm:p-6 overflow-y-auto space-y-5">
          {/* Kortförhandsvisning */}
          <div className="flex justify-center">
            <div
              ref={cardRef}
              className={`w-full max-w-[340px] rounded-3xl p-5 bg-gradient-to-b ${selectedTheme.bgGradient} border ${selectedTheme.borderColor} shadow-2xl flex flex-col items-center relative overflow-hidden transition-all duration-300`}
              style={{
                boxShadow: `0 20px 40px -15px ${selectedTheme.glowColor}`,
              }}
            >
              {/* Topp: Branding & Plattform */}
              <div className="w-full flex items-center justify-between mb-4">
                <div className="flex items-center gap-1.5 font-black text-white text-sm tracking-tight">
                  <Gamepad className="w-4 h-4 text-brand-red" />
                  <span>GameShelf</span>
                </div>
                {primaryPlatform && (
                  <span className="px-2.5 py-0.5 rounded-full text-[10px] font-bold bg-white/10 text-white border border-white/10">
                    {primaryPlatform}
                  </span>
                )}
              </div>

              {/* Omslag */}
              <div className="w-36 aspect-[3/4] rounded-2xl overflow-hidden bg-zinc-900 border border-white/20 shadow-2xl my-2 flex-shrink-0">
                {game.cover_url ? (
                  <img
                    src={game.cover_url}
                    alt={game.title}
                    className="w-full h-full object-cover"
                  />
                ) : (
                  <div className="w-full h-full flex items-center justify-center">
                    <Gamepad className="w-8 h-8 text-zinc-600" />
                  </div>
                )}
              </div>

              {/* Titel & Info */}
              <div className="text-center mt-3 mb-4 w-full">
                <h4 className="text-base sm:text-lg font-black text-white leading-tight line-clamp-2">
                  {game.title}
                </h4>
                {(displayDev || displayYear) && (
                  <p className="text-xs text-zinc-300/80 font-medium mt-1">
                    {[displayDev, displayYear].filter(Boolean).join(' • ')}
                  </p>
                )}
              </div>

              {/* Status & Betyg */}
              <div className="grid grid-cols-2 gap-2.5 w-full">
                <div className="p-2.5 rounded-xl bg-black/40 border border-white/10 text-center">
                  <span className="text-[9px] font-bold text-zinc-400 uppercase tracking-wider block">
                    Status
                  </span>
                  <span className="text-xs font-bold text-white mt-0.5 block truncate">
                    {game.status}
                  </span>
                </div>

                <div className="p-2.5 rounded-xl bg-black/40 border border-white/10 text-center">
                  <span className="text-[9px] font-bold text-zinc-400 uppercase tracking-wider block">
                    Betyg
                  </span>
                  <span className="text-xs font-extrabold text-amber-300 mt-0.5 block">
                    {game.rating ? `⭐ ${game.rating}/10` : (game.igdb_rating ? `⭐ ${game.igdb_rating}/10` : '–')}
                  </span>
                </div>
              </div>

              {/* Watermark */}
              <div className="mt-4 text-[10px] font-semibold text-zinc-400 tracking-wider">
                mygameshelf.vercel.app
              </div>
            </div>
          </div>

          {/* Tema-väljare */}
          <div className="space-y-2">
            <span className="text-xs font-bold text-zinc-400 uppercase tracking-wider block">
              Välj korttema
            </span>
            <div className="grid grid-cols-5 gap-2">
              {THEMES.map((theme) => {
                const isActive = selectedTheme.id === theme.id;
                return (
                  <button
                    key={theme.id}
                    onClick={() => setSelectedTheme(theme)}
                    className={`flex flex-col items-center gap-1.5 p-2 rounded-xl border transition ${
                      isActive
                        ? 'bg-zinc-800 border-white text-white scale-105'
                        : 'bg-zinc-900/60 border-zinc-800 text-zinc-400 hover:text-zinc-200'
                    }`}
                  >
                    <div
                      className="w-5 h-5 rounded-full shadow-md"
                      style={{ backgroundColor: theme.accentColor }}
                    />
                    <span className="text-[10px] font-bold truncate max-w-full">
                      {theme.name.split(' ')[0]}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>

        {/* Modal Footer Actions */}
        <div className="p-4 sm:p-5 border-t border-zinc-800 bg-zinc-950/60 flex items-center justify-between gap-3">
          <button
            onClick={handleCopyLink}
            className="flex items-center gap-1.5 px-4 py-2.5 rounded-xl bg-zinc-900 hover:bg-zinc-800 text-xs font-bold text-zinc-200 border border-zinc-800 transition"
          >
            {copiedText ? (
              <>
                <Check className="w-3.5 h-3.5 text-emerald-400" />
                <span>Kopierat!</span>
              </>
            ) : (
              <>
                <Copy className="w-3.5 h-3.5" />
                <span>Kopiera länk</span>
              </>
            )}
          </button>

          <button
            onClick={handleDownloadImage}
            disabled={isExporting}
            className="flex-1 flex items-center justify-center gap-2 px-5 py-2.5 rounded-xl bg-brand-red hover:bg-red-700 text-xs sm:text-sm font-bold text-white shadow-lg shadow-brand-red/20 transition disabled:opacity-50"
          >
            <Download className="w-4 h-4" />
            <span>{isExporting ? 'Skapar bild...' : 'Ladda ner bild (PNG)'}</span>
          </button>
        </div>
      </div>
    </div>
  );
}
