import { Game } from '@/types/game';
import { isMultiplayerOrOngoing } from './statusHelper';

export interface GameGoalProgressInfo {
  percentage: number;
  completedTasks: number;
  totalTasks: number;
  remainingTasks: number;
  nextTaskTitle?: string;
  displaySubtext: string;
  hasTasks: boolean;
}

export interface GameGoalTempoInfo {
  daysRemainingInYear: number;
  remainingGames: number;
  daysPerGame?: number;
  isGoalReached: boolean;
  isAheadOfPace: boolean;
  isUnrealistic: boolean;
  displayText: string;
}

export interface GameGoalBadge {
  id: string;
  icon: string;
  title: string;
  subtitle: string;
  isUnlocked: boolean;
  progressRatio: number;
}

export const GamingGoalEngine = {
  currentYear(): number {
    return new Date().getFullYear();
  },

  completedGames(games: Game[], year: number = new Date().getFullYear()): Game[] {
    return games
      .filter((g) => {
        if (!g.is_owned || g.status !== 'completed' || isMultiplayerOrOngoing(g)) {
          return false;
        }
        if (g.completed_year !== undefined && g.completed_year !== null) {
          return g.completed_year === year;
        }
        if (g.completed_date) {
          return new Date(g.completed_date).getFullYear() === year;
        }
        if (g.last_played_date) {
          return new Date(g.last_played_date).getFullYear() === year;
        }
        return false;
      })
      .sort((a, b) => {
        const da = a.completed_date || a.last_played_date || '';
        const db = b.completed_date || b.last_played_date || '';
        return db.localeCompare(da);
      });
  },

  completedCount(games: Game[], year: number = new Date().getFullYear()): number {
    return this.completedGames(games, year).length;
  },

  abandonedGames(games: Game[], year: number = new Date().getFullYear()): Game[] {
    return games
      .filter((g) => {
        if (!g.is_owned || g.status !== 'abandoned') {
          return false;
        }
        if (g.completed_year !== undefined && g.completed_year !== null) {
          return g.completed_year === year;
        }
        if (g.completed_date) {
          return new Date(g.completed_date).getFullYear() === year;
        }
        if (g.last_played_date) {
          return new Date(g.last_played_date).getFullYear() === year;
        }
        if (g.created_at) {
          return new Date(g.created_at).getFullYear() === year;
        }
        return false;
      })
      .sort((a, b) => {
        const da = a.completed_date || a.last_played_date || a.created_at || '';
        const db = b.completed_date || b.last_played_date || b.created_at || '';
        return db.localeCompare(da);
      });
  },

  abandonedCount(games: Game[], year: number = new Date().getFullYear()): number {
    return this.abandonedGames(games, year).length;
  },

  focusGames(allGames: Game[], targetIDs: string[] = []): Game[] {
    if (!targetIDs || targetIDs.length === 0) return [];
    const lookup = new Map<string, Game>();
    for (const g of allGames) {
      lookup.set(g.id.toLowerCase(), g);
      if (g.igdb_id) {
        lookup.set(String(g.igdb_id).toLowerCase(), g);
      }
    }

    const result: Game[] = [];
    const seen = new Set<string>();
    for (const rawId of targetIDs) {
      const g = lookup.get(rawId.toLowerCase());
      if (
        g &&
        g.status !== 'completed' &&
        g.status !== 'abandoned' &&
        !seen.has(g.id.toLowerCase())
      ) {
        seen.add(g.id.toLowerCase());
        result.push(g);
        if (result.length === 3) break;
      }
    }
    return result;
  },

  calculateProgress(game: Game): GameGoalProgressInfo {
    const tasks = game.todos || [];
    if (tasks.length > 0) {
      const total = tasks.length;
      const done = tasks.filter((t) => t.isDone).length;
      const remaining = Math.max(0, total - done);
      const pct = total > 0 ? Math.round((done / total) * 100) : 0;

      const sortedRemaining = tasks
        .filter((t) => !t.isDone)
        .sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
      const next = sortedRemaining[0]?.title;

      const statusLabel =
        game.status === 'playing'
          ? 'Spelar nu'
          : game.status === 'paused'
          ? 'Pausat'
          : 'Inte påbörjat';

      const displaySubtext = next
        ? `${done}/${total} uppdrag (${pct}%) · Nästa: ${next}`
        : `${done}/${total} uppdrag (${pct}%) · ${statusLabel}`;

      return {
        percentage: pct,
        completedTasks: done,
        totalTasks: total,
        remainingTasks: remaining,
        nextTaskTitle: next,
        displaySubtext,
        hasTasks: true,
      };
    }

    // Om inga uppgifter finns: uppskatta utifrån story_progress eller status
    let pct = 0;
    if (game.status === 'completed') pct = 100;
    else if (game.story_progress) {
      const sp = game.story_progress.toLowerCase();
      if (sp.includes('akt 3') || sp.includes('act 3') || sp.includes('slutet')) pct = 75;
      else if (sp.includes('akt 2') || sp.includes('act 2') || sp.includes('halvvägs')) pct = 50;
      else if (sp.includes('akt 1') || sp.includes('act 1') || sp.includes('början')) pct = 25;
      else pct = 30;
    } else if (game.status === 'playing') {
      pct = 20;
    }

    return {
      percentage: pct,
      completedTasks: 0,
      totalTasks: 0,
      remainingTasks: 0,
      nextTaskTitle: undefined,
      displaySubtext: game.story_progress
        ? `Framsteg: ${game.story_progress}`
        : game.status === 'playing'
        ? 'Spelar nu (inga uppdrag tillagda)'
        : 'Inte påbörjat',
      hasTasks: false,
    };
  },

  closestToFinish(
    focusGames: Game[]
  ): { game: Game; info: GameGoalProgressInfo } | null {
    let best: { game: Game; info: GameGoalProgressInfo } | null = null;
    let highestPct = -1;

    for (const g of focusGames) {
      const info = this.calculateProgress(g);
      // Kvalificerar om >= 50% eller högst 5 uppdrag kvar (när uppdrag finns)
      const qualifies =
        (info.hasTasks && (info.percentage >= 50 || info.remainingTasks <= 5)) ||
        (!info.hasTasks && info.percentage >= 50);

      if (qualifies && info.percentage > highestPct) {
        highestPct = info.percentage;
        best = { game: g, info };
      }
    }
    return best;
  },

  calculateTempo(
    goal: number,
    completed: number,
    targetYear: number = new Date().getFullYear()
  ): GameGoalTempoInfo {
    const now = new Date();
    const endOfYear = new Date(targetYear, 11, 31, 23, 59, 59);
    const msDiff = Math.max(0, endOfYear.getTime() - now.getTime());
    const daysRemaining = Math.max(1, Math.ceil(msDiff / (1000 * 60 * 60 * 24)));

    const remainingGames = Math.max(0, goal - completed);
    const isGoalReached = completed >= goal;

    if (isGoalReached) {
      return {
        daysRemainingInYear: daysRemaining,
        remainingGames: 0,
        daysPerGame: undefined,
        isGoalReached: true,
        isAheadOfPace: true,
        isUnrealistic: false,
        displayText: `Årsmålet är uppnått! Du har klarat ${completed} av ${goal} spel. 🎉`,
      };
    }

    const daysPerGame = remainingGames > 0 ? Math.round(daysRemaining / remainingGames) : undefined;
    const startOfYear = new Date(targetYear, 0, 1);
    const totalDaysInYear = Math.ceil(
      (endOfYear.getTime() - startOfYear.getTime()) / (1000 * 60 * 60 * 24)
    );
    const daysPassed = Math.max(1, totalDaysInYear - daysRemaining);
    const expectedCompleted = (daysPassed / totalDaysInYear) * goal;
    const isAheadOfPace = completed >= expectedCompleted;
    const isUnrealistic = daysPerGame !== undefined && daysPerGame < 5;

    let displayText = '';
    if (isAheadOfPace) {
      displayText = daysPerGame
        ? `Grymt tempo! Du ligger före plan (~${daysPerGame} dagar per spel kvar).`
        : `Grymt tempo! Du ligger före årets plan.`;
    } else if (isUnrealistic) {
      displayText = `Tufft läge: Kräver 1 spel var ${daysPerGame} dag för att nå ${goal} spel.`;
    } else {
      displayText = daysPerGame
        ? `I fas: Klara ett spel var ${daysPerGame}:e dag för att nå målet.`
        : `${remainingGames} spel kvar till målet.`;
    }

    return {
      daysRemainingInYear: daysRemaining,
      remainingGames,
      daysPerGame,
      isGoalReached: false,
      isAheadOfPace,
      isUnrealistic,
      displayText,
    };
  },

  badges(
    goal: number,
    completed: number,
    targetYear: number = new Date().getFullYear()
  ): GameGoalBadge[] {
    const ratio = goal > 0 ? completed / goal : 0;
    return [
      {
        id: 'first_blood',
        icon: '🥉',
        title: 'Första segern',
        subtitle: 'Klarat 1 spel i år',
        isUnlocked: completed >= 1,
        progressRatio: Math.min(1, completed / 1),
      },
      {
        id: 'quarter',
        icon: '🥈',
        title: 'Kvartsvägs',
        subtitle: `25% av målet (${Math.ceil(goal * 0.25)} spel)`,
        isUnlocked: ratio >= 0.25,
        progressRatio: Math.min(1, ratio / 0.25),
      },
      {
        id: 'halfway',
        icon: '🥇',
        title: 'Halvvägs',
        subtitle: `50% av målet (${Math.ceil(goal * 0.5)} spel)`,
        isUnlocked: ratio >= 0.5,
        progressRatio: Math.min(1, ratio / 0.5),
      },
      {
        id: 'completed_goal',
        icon: '🏆',
        title: 'Målchampions',
        subtitle: `100% av årets mål (${goal} spel)`,
        isUnlocked: ratio >= 1.0,
        progressRatio: Math.min(1, ratio),
      },
    ];
  },

  suggestedNextGame(
    allGames: Game[],
    targetIDs: string[] = [],
    dismissedID?: string
  ): Game | null {
    if (targetIDs.length >= 3) return null;
    const targetSet = new Set(targetIDs.map((id) => id.toLowerCase()));

    // 1. Spelar nu som inte är fokusspel och inte multiplayer
    const playing = allGames.find(
      (g) =>
        g.is_owned &&
        g.status === 'playing' &&
        !isMultiplayerOrOngoing(g) &&
        !targetSet.has(g.id.toLowerCase()) &&
        (!g.igdb_id || !targetSet.has(String(g.igdb_id).toLowerCase())) &&
        g.id !== dismissedID
    );
    if (playing) return playing;

    // 2. Pausade
    const paused = allGames.find(
      (g) =>
        g.is_owned &&
        g.status === 'paused' &&
        !isMultiplayerOrOngoing(g) &&
        !targetSet.has(g.id.toLowerCase()) &&
        (!g.igdb_id || !targetSet.has(String(g.igdb_id).toLowerCase())) &&
        g.id !== dismissedID
    );
    if (paused) return paused;

    // 3. Backlog
    const backlog = allGames.find(
      (g) =>
        g.is_owned &&
        (g.is_backlog || g.status === 'notStarted') &&
        !isMultiplayerOrOngoing(g) &&
        !targetSet.has(g.id.toLowerCase()) &&
        (!g.igdb_id || !targetSet.has(String(g.igdb_id).toLowerCase())) &&
        g.id !== dismissedID
    );
    return backlog || null;
  },
};
