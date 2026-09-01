import React from 'react';
import { PlayStatus, Game } from '@/types/game';
import {
  normalizePlayStatus,
  getStatusDisplayTitle,
  getStatusColor,
  isMultiplayerOrOngoing,
} from '@/lib/statusHelper';
import { Play, Pause, CheckCircle, XCircle, Circle } from 'lucide-react';

interface StatusBadgeProps {
  status?: PlayStatus | string;
  game?: Partial<Game>;
  isMultiplayer?: boolean;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
  showBacklog?: boolean;
}

export function StatusBadge({
  status,
  game,
  isMultiplayer,
  size = 'md',
  className = '',
  showBacklog = true,
}: StatusBadgeProps) {
  const rawStatus = status ?? game?.status;
  const normalized = normalizePlayStatus(rawStatus);
  const playStatus = normalized.status;

  const multi =
    isMultiplayer !== undefined ? isMultiplayer : isMultiplayerOrOngoing(game);
  const isBacklog = game?.is_backlog ?? normalized.is_backlog;

  const title = getStatusDisplayTitle(playStatus, multi);
  const colors = getStatusColor(playStatus);

  const getIcon = () => {
    switch (playStatus) {
      case 'playing':
        return multi ? (
          <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
        ) : (
          <Play className="w-3 h-3 fill-current text-emerald-400" />
        );
      case 'notStarted':
        return <Circle className="w-3 h-3 text-zinc-400" />;
      case 'paused':
        return <Pause className="w-3 h-3 fill-current text-amber-400" />;
      case 'completed':
        return <CheckCircle className="w-3 h-3 text-teal-400" />;
      case 'abandoned':
        return <XCircle className="w-3 h-3 text-zinc-400" />;
    }
  };

  const sizeClasses = {
    sm: 'px-2 py-0.5 text-xs gap-1',
    md: 'px-2.5 py-1 text-xs font-medium gap-1.5',
    lg: 'px-3 py-1.5 text-sm font-medium gap-2',
  };

  return (
    <div className={`inline-flex items-center gap-1.5 ${className}`}>
      <span
        className={`inline-flex items-center rounded-full border backdrop-blur-sm ${colors.bg} ${colors.border} ${colors.text} ${sizeClasses[size]}`}
      >
        {getIcon()}
        <span>{title}</span>
      </span>

      {showBacklog && isBacklog && (
        <span
          className={`inline-flex items-center rounded-full border border-blue-500/40 bg-blue-950/70 text-blue-300 ${sizeClasses[size]}`}
          title="Ligger i din Backlog"
        >
          Backlog
        </span>
      )}
    </div>
  );
}
