'use client';

import React, { useState, useEffect } from 'react';
import { Hourglass, Sparkles, Calendar, Bookmark } from 'lucide-react';

interface ReleaseCountdownBannerProps {
  releaseDate?: number | null; // Unix timestamp in seconds
  releaseYear?: number | null;
  isInWishlist?: boolean;
}

export function ReleaseCountdownBanner({
  releaseDate,
  releaseYear,
  isInWishlist = false,
}: ReleaseCountdownBannerProps) {
  const [timeLeft, setTimeLeft] = useState<{
    days: number;
    hours: number;
    minutes: number;
    seconds: number;
    isPast: boolean;
    isToday: boolean;
  } | null>(null);

  useEffect(() => {
    if (!releaseDate) {
      setTimeLeft(null);
      return;
    }

    const targetMs = releaseDate * 1000;

    const calculate = () => {
      const now = Date.now();
      const diff = targetMs - now;

      if (diff <= 0) {
        // Kontrollera om det är samma kalenderdag
        const targetDateObj = new Date(targetMs);
        const nowDateObj = new Date(now);
        const sameDay =
          targetDateObj.getFullYear() === nowDateObj.getFullYear() &&
          targetDateObj.getMonth() === nowDateObj.getMonth() &&
          targetDateObj.getDate() === nowDateObj.getDate();

        setTimeLeft({
          days: 0,
          hours: 0,
          minutes: 0,
          seconds: 0,
          isPast: !sameDay,
          isToday: sameDay,
        });
        return;
      }

      const totalSeconds = Math.floor(diff / 1000);
      const days = Math.floor(totalSeconds / 86400);
      const hours = Math.floor((totalSeconds % 86400) / 3600);
      const minutes = Math.floor((totalSeconds % 3600) / 60);
      const seconds = totalSeconds % 60;

      setTimeLeft({
        days,
        hours,
        minutes,
        seconds,
        isPast: false,
        isToday: false,
      });
    };

    calculate();
    const interval = setInterval(calculate, 1000);
    return () => clearInterval(interval);
  }, [releaseDate]);

  const currentYear = new Date().getFullYear();
  const isFutureYearOnly = !releaseDate && releaseYear && releaseYear > currentYear;

  // Om spelet redan släppts i det förflutna visar vi ingen nedräkning
  if (timeLeft?.isPast && !timeLeft?.isToday) {
    return null;
  }

  // Om varken datum eller framtida år finns, visa ingenting
  if (!releaseDate && !isFutureYearOnly) {
    return null;
  }

  const formattedDate = releaseDate
    ? new Date(releaseDate * 1000).toLocaleDateString('sv-SE', {
        weekday: 'short',
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      })
    : `${releaseYear}`;

  return (
    <div className="relative overflow-hidden rounded-2xl bg-gradient-to-r from-red-950/40 via-zinc-900/90 to-zinc-950 border border-red-900/30 p-4 sm:p-5 shadow-lg">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        {/* Vänster: Badge & Ingress */}
        <div>
          <div className="flex items-center gap-2 mb-1.5">
            <span className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full bg-brand-red/20 border border-brand-red/40 text-[11px] font-black text-rose-300 uppercase tracking-wider">
              <Hourglass className="w-3 h-3 text-brand-red animate-pulse" />
              <span>Kommande släpp</span>
            </span>

            {isInWishlist && (
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-zinc-800 text-[10px] font-bold text-zinc-300 border border-zinc-700">
                <Bookmark className="w-2.5 h-2.5 text-amber-400 fill-amber-400" />
                <span>I din önskelista</span>
              </span>
            )}
          </div>

          <div className="flex items-center gap-2 text-xs sm:text-sm text-zinc-300">
            <Calendar className="w-3.5 h-3.5 text-zinc-400" />
            <span className="font-semibold text-white capitalize">{formattedDate}</span>
          </div>
        </div>

        {/* Höger: Live Nedräkning eller Årsbanner */}
        {timeLeft?.isToday ? (
          <div className="flex items-center gap-2 px-4 py-2 rounded-xl bg-brand-red/20 border border-brand-red/50 text-white font-bold text-sm sm:text-base animate-bounce">
            <Sparkles className="w-4 h-4 text-amber-300" />
            <span>Spelet släpps idag! 🎉</span>
          </div>
        ) : timeLeft && !timeLeft.isPast ? (
          <div className="flex items-center gap-1.5 sm:gap-2">
            <div className="flex flex-col items-center bg-zinc-950/90 border border-zinc-800/80 rounded-xl px-2.5 sm:px-3 py-1.5 min-w-[50px] sm:min-w-[60px] shadow-sm">
              <span className="text-base sm:text-xl font-black text-white font-mono">
                {timeLeft.days}
              </span>
              <span className="text-[9px] font-bold uppercase tracking-wider text-zinc-400">
                Dagar
              </span>
            </div>

            <span className="text-zinc-600 font-bold">:</span>

            <div className="flex flex-col items-center bg-zinc-950/90 border border-zinc-800/80 rounded-xl px-2.5 sm:px-3 py-1.5 min-w-[50px] sm:min-w-[60px] shadow-sm">
              <span className="text-base sm:text-xl font-black text-white font-mono">
                {String(timeLeft.hours).padStart(2, '0')}
              </span>
              <span className="text-[9px] font-bold uppercase tracking-wider text-zinc-400">
                Timmar
              </span>
            </div>

            <span className="text-zinc-600 font-bold">:</span>

            <div className="flex flex-col items-center bg-zinc-950/90 border border-zinc-800/80 rounded-xl px-2.5 sm:px-3 py-1.5 min-w-[50px] sm:min-w-[60px] shadow-sm">
              <span className="text-base sm:text-xl font-black text-white font-mono">
                {String(timeLeft.minutes).padStart(2, '0')}
              </span>
              <span className="text-[9px] font-bold uppercase tracking-wider text-zinc-400">
                Minuter
              </span>
            </div>

            <span className="hidden sm:inline text-zinc-600 font-bold">:</span>

            <div className="hidden sm:flex flex-col items-center bg-zinc-950/90 border border-zinc-800/80 rounded-xl px-2.5 sm:px-3 py-1.5 min-w-[60px] shadow-sm">
              <span className="text-base sm:text-xl font-black text-rose-400 font-mono">
                {String(timeLeft.seconds).padStart(2, '0')}
              </span>
              <span className="text-[9px] font-bold uppercase tracking-wider text-zinc-400">
                Sekunder
              </span>
            </div>
          </div>
        ) : isFutureYearOnly ? (
          <div className="px-4 py-2 rounded-xl bg-zinc-950/80 border border-zinc-800 text-center">
            <span className="text-xs text-zinc-400 block font-semibold">Planerat släppår</span>
            <span className="text-lg font-black text-white font-mono">{releaseYear}</span>
          </div>
        ) : null}
      </div>
    </div>
  );
}
