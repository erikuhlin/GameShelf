import React from 'react';
import { PlayStatus } from '@/types/game';
import { Play, Archive, Pause, CheckCircle, XCircle, Heart } from 'lucide-react';

interface StatusBadgeProps {
  status: PlayStatus;
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

export function StatusBadge({ status, size = 'md', className = '' }: StatusBadgeProps) {
  const getStatusConfig = () => {
    switch (status) {
      case 'Spelar nu':
        return {
          bg: 'bg-emerald-950/70 border-emerald-500/40 text-emerald-300',
          icon: <Play className="w-3 h-3 fill-current" />,
        };
      case 'Backlog':
        return {
          bg: 'bg-blue-950/70 border-blue-500/40 text-blue-300',
          icon: <Archive className="w-3 h-3" />,
        };
      case 'Pausat':
        return {
          bg: 'bg-amber-950/70 border-amber-500/40 text-amber-300',
          icon: <Pause className="w-3 h-3 fill-current" />,
        };
      case 'Klar':
        return {
          bg: 'bg-teal-950/70 border-teal-500/40 text-teal-300',
          icon: <CheckCircle className="w-3 h-3" />,
        };
      case 'Avbrutet':
        return {
          bg: 'bg-zinc-800/70 border-zinc-600/40 text-zinc-400',
          icon: <XCircle className="w-3 h-3" />,
        };
      case 'Önskelista':
        return {
          bg: 'bg-purple-950/70 border-purple-500/40 text-purple-300',
          icon: <Heart className="w-3 h-3 fill-current" />,
        };
      default:
        return {
          bg: 'bg-zinc-800 border-zinc-700 text-zinc-300',
          icon: null,
        };
    }
  };

  const config = getStatusConfig();
  const sizeClasses = {
    sm: 'px-2 py-0.5 text-xs gap-1',
    md: 'px-2.5 py-1 text-xs font-medium gap-1.5',
    lg: 'px-3 py-1.5 text-sm font-medium gap-2',
  };

  return (
    <span
      className={`inline-flex items-center rounded-full border backdrop-blur-sm ${config.bg} ${sizeClasses[size]} ${className}`}
    >
      {config.icon}
      <span>{status}</span>
    </span>
  );
}
