'use client';

import React, { useState, useEffect } from 'react';
import { Hourglass, Sparkles, Calendar } from 'lucide-react';

interface ReleaseCountdownProps {
  firstReleaseDate?: number | string | null; // Unix timestamp i sekunder eller millisekunder
  releaseYear?: number | null;
}

function parseTargetTime(val?: number | string | null): number | null {
  if (!val) return null;
  const num = typeof val === 'number' ? val : Number(val);
  if (isNaN(num) || num <= 0) return null;
  // Om värdet är i sekunder (< 10000000000), konvertera till millisekunder
  return num < 10000000000 ? num * 1000 : num;
}

function computeTimeLeft(targetTime: number) {
  const now = Date.now();
  const diff = targetTime - now;

  if (diff <= 0) {
    const targetDate = new Date(targetTime);
    const today = new Date();
    const isSameDay =
      targetDate.getFullYear() === today.getFullYear() &&
      targetDate.getMonth() === today.getMonth() &&
      targetDate.getDate() === today.getDate();

    return {
      days: 0,
      hours: 0,
      minutes: 0,
      seconds: 0,
      isPast: true,
      isToday: isSameDay,
    };
  }

  const days = Math.floor(diff / (1000 * 60 * 60 * 24));
  const hours = Math.floor((diff / (1000 * 60 * 60)) % 24);
  const minutes = Math.floor((diff / 1000 / 60) % 60);
  const seconds = Math.floor((diff / 1000) % 60);

  return {
    days,
    hours,
    minutes,
    seconds,
    isPast: false,
    isToday: false,
  };
}

export function ReleaseCountdown({ firstReleaseDate, releaseYear }: ReleaseCountdownProps) {
  const targetTime = parseTargetTime(firstReleaseDate);

  const [timeLeft, setTimeLeft] = useState<{
    days: number;
    hours: number;
    minutes: number;
    seconds: number;
    isPast: boolean;
    isToday: boolean;
  } | null>(() => (targetTime ? computeTimeLeft(targetTime) : null));

  useEffect(() => {
    if (!targetTime) {
      setTimeLeft(null);
      return;
    }

    const update = () => {
      setTimeLeft(computeTimeLeft(targetTime));
    };

    update();
    const interval = setInterval(update, 1000);
    return () => clearInterval(interval);
  }, [targetTime]);

  const currentYear = new Date().getFullYear();
  // Endast år strikt i framtiden (t.ex. 2027+) visas som framtida lanseringsår när exakt datum saknas
  const isFutureYearOnly =
    !targetTime && releaseYear && releaseYear > currentYear;

  // Om spelet redan har släppts och inte är idag, visa ingen nedräkning
  if (timeLeft?.isPast && !timeLeft.isToday) {
    return null;
  }

  // Om varken framtida datum eller år finns
  if (!timeLeft && !isFutureYearOnly) {
    return null;
  }

  const formattedDate = targetTime
    ? new Date(targetTime).toLocaleDateString('sv-SE', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
      })
    : null;

  return (
    <div className="w-full rounded-2xl bg-zinc-900/90 border border-zinc-800 p-4 sm:p-5 shadow-lg shadow-black/20 backdrop-blur-sm transition-all">
      <div className="flex items-center justify-between gap-2 mb-3">
        <div className="flex items-center gap-2">
          <div className="flex items-center justify-center w-7 h-7 rounded-full bg-red-500/15 text-red-400">
            <Hourglass className="w-4 h-4 animate-pulse" />
          </div>
          <span className="text-xs font-black tracking-wider uppercase text-red-400">
            Kommande Släpp
          </span>
        </div>

        {formattedDate && (
          <span className="text-xs font-semibold text-zinc-400">
            {formattedDate}
          </span>
        )}
      </div>

      {timeLeft?.isToday ? (
        <div className="flex items-center justify-center gap-2 py-3 bg-red-500/10 rounded-xl border border-red-500/20 text-red-300 font-bold">
          <Sparkles className="w-5 h-5 text-red-400" />
          <span>Spelet släpps idag! 🎉</span>
          <Sparkles className="w-5 h-5 text-red-400" />
        </div>
      ) : timeLeft ? (
        <div className="grid grid-cols-4 gap-2 text-center">
          <div className="flex flex-col items-center bg-zinc-950/70 border border-zinc-800 rounded-xl py-2.5 px-1">
            <span className="text-xl sm:text-2xl font-black text-white font-mono">
              {String(timeLeft.days).padStart(2, '0')}
            </span>
            <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wide">
              Dagar
            </span>
          </div>

          <div className="flex flex-col items-center bg-zinc-950/70 border border-zinc-800 rounded-xl py-2.5 px-1">
            <span className="text-xl sm:text-2xl font-black text-white font-mono">
              {String(timeLeft.hours).padStart(2, '0')}
            </span>
            <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wide">
              Timmar
            </span>
          </div>

          <div className="flex flex-col items-center bg-zinc-950/70 border border-zinc-800 rounded-xl py-2.5 px-1">
            <span className="text-xl sm:text-2xl font-black text-white font-mono">
              {String(timeLeft.minutes).padStart(2, '0')}
            </span>
            <span className="text-[10px] font-bold text-zinc-400 uppercase tracking-wide">
              Minuter
            </span>
          </div>

          <div className="flex flex-col items-center bg-zinc-950/70 border border-zinc-800 rounded-xl py-2.5 px-1">
            <span className="text-xl sm:text-2xl font-black text-red-400 font-mono">
              {String(timeLeft.seconds).padStart(2, '0')}
            </span>
            <span className="text-[10px] font-bold text-red-400/80 uppercase tracking-wide">
              Sekunder
            </span>
          </div>
        </div>
      ) : (
        <div className="flex items-center justify-between py-2.5 px-3.5 bg-zinc-950/70 rounded-xl border border-zinc-800">
          <div className="flex items-center gap-2 text-zinc-300 text-sm">
            <Calendar className="w-4 h-4 text-red-400" />
            <span>Planerat lanseringsår</span>
          </div>
          <span className="text-base font-black text-red-400 font-mono">
            {releaseYear}
          </span>
        </div>
      )}
    </div>
  );
}
