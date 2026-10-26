import test from 'node:test';
import assert from 'node:assert/strict';
import {
  normalizePlayStatus,
  inferPlayTypes,
  isMultiplayerOrOngoing,
  getStatusDisplayTitle,
} from './statusHelper';
import { normalizeIgdbRating, unpackGameNotes, sanitizeUserGamePayload } from './gamePayload';
import { normalizeWalkthroughTitle } from './verifiedWalkthroughs';
import { GamingGoalEngine } from './gamingGoalEngine';

test('statusHelper: normalizePlayStatus correctly parses legacy Swedish and English statuses', () => {
  assert.equal(normalizePlayStatus('Spelar nu').status, 'playing');
  assert.equal(normalizePlayStatus('playing').status, 'playing');

  assert.equal(normalizePlayStatus('Backlog').status, 'notStarted');
  assert.equal(normalizePlayStatus('Backlog').is_backlog, true);

  assert.equal(normalizePlayStatus('Klar').status, 'completed');
  assert.equal(normalizePlayStatus('completed').status, 'completed');

  assert.equal(normalizePlayStatus('Pausat').status, 'paused');
  assert.equal(normalizePlayStatus('paused').status, 'paused');

  assert.equal(normalizePlayStatus('Avbrutet').status, 'abandoned');
  assert.equal(normalizePlayStatus('abandoned').status, 'abandoned');

  assert.equal(normalizePlayStatus('Önskelista').status, 'notStarted');
  assert.equal(normalizePlayStatus('Önskelista').is_owned_override, false);
});

test('statusHelper: inferPlayTypes correctly identifies Singleplayer, Multiplayer, Co-Op and Ongoing', () => {
  // Pure singleplayer RPG
  const witcher = inferPlayTypes({
    title: 'The Witcher 3: Wild Hunt',
    genres: ['Role-playing (RPG)', 'Adventure'],
    game_modes: ['Single player'],
  });
  assert.deepEqual(witcher, ['singlePlayer']);

  // Pure multiplayer / battle royale
  const apex = inferPlayTypes({
    title: 'Apex Legends',
    genres: ['Shooter'],
    game_modes: ['Multiplayer', 'Battle Royale'],
  });
  assert.ok(apex.includes('multiplayer'));

  // Co-op game
  const itTakesTwo = inferPlayTypes({
    title: 'It Takes Two',
    genres: ['Platform', 'Adventure'],
    game_modes: ['Co-operative', 'Split screen'],
  });
  assert.ok(itTakesTwo.includes('coOp'));

  // Live service / MMO
  const wow = inferPlayTypes({
    title: 'World of Warcraft',
    genres: ['MMORPG'],
    game_modes: ['Massively Multiplayer Online (MMO)'],
  });
  assert.ok(wow.includes('ongoing'));
  assert.ok(wow.includes('multiplayer'));
});

test('statusHelper: isMultiplayerOrOngoing identifies ongoing and multiplayer games', () => {
  assert.equal(
    isMultiplayerOrOngoing({
      id: '1',
      title: 'Solo Game',
      platforms: [],
      genres: [],
      developers: [],
      status: 'playing',
      is_owned: true,
      notes: '',
      todos: [],
      play_types: ['singlePlayer'],
    }),
    false
  );

  assert.equal(
    isMultiplayerOrOngoing({
      id: '2',
      title: 'MMO',
      platforms: [],
      genres: [],
      developers: [],
      status: 'playing',
      is_owned: true,
      notes: '',
      todos: [],
      play_types: ['ongoing', 'multiplayer'],
    }),
    true
  );
});

test('supabase: normalizeIgdbRating properly scales and normalizes 0-100 and legacy half ratings', () => {
  // Undefined / empty
  assert.equal(normalizeIgdbRating(null), undefined);
  assert.equal(normalizeIgdbRating(0), undefined);

  // 0-100 scale (IGDB total_rating)
  assert.equal(normalizeIgdbRating(84.7), 8.5);
  assert.equal(normalizeIgdbRating(92.0), 9.2);

  // Legacy half-rating bug (e.g. 88 / 20 = 4.4 -> should be 8.8)
  assert.equal(normalizeIgdbRating(4.4), 8.8);
  assert.equal(normalizeIgdbRating(4.0), 8.0);

  // Already 0-10 normalized
  assert.equal(normalizeIgdbRating(8.6), 8.6);
});

test('supabase: unpackGameNotes cleanly unpacks legacy GS_META tag while preserving user notes', () => {
  const notesWithMeta = '<!--GS_META:{"story_progress":"midway","hours_played":14.5}-->\nBästa bossen är slagen!';
  const { notes, meta } = unpackGameNotes(notesWithMeta);

  assert.equal(notes, 'Bästa bossen är slagen!');
  assert.equal(meta.story_progress, 'midway');
  assert.equal(meta.hours_played, 14.5);

  const cleanNotesOnly = 'Bara vanliga anteckningar';
  const unpackedClean = unpackGameNotes(cleanNotesOnly);
  assert.equal(unpackedClean.notes, 'Bara vanliga anteckningar');
  assert.deepEqual(unpackedClean.meta, {});
});

test('verifiedWalkthroughs: normalizeWalkthroughTitle removes editions, punctuation and accents', () => {
  assert.equal(
    normalizeWalkthroughTitle('Silent Hill 2 (Remake)'),
    'silent hill 2'
  );
  assert.equal(
    normalizeWalkthroughTitle('Resident Evil 4: Gold Edition'),
    'resident evil 4'
  );
  assert.equal(
    normalizeWalkthroughTitle("Baldur's Gate III - Definitive Edition"),
    'baldurs gate iii'
  );
});

test('gamePayload: sanitizeUserGamePayload produces clean columns and cleans notes', () => {
  const payload = sanitizeUserGamePayload(
    {
      story_progress: 'Akt 2',
      hours_played: 25.5,
      is_backlog: true,
      notes: 'Grym handling hittills!',
    },
    {
      id: 'game-123',
      notes: '<!--GS_META:{"story_progress":"Akt 1"}-->\nGammal notering',
    }
  );

  assert.equal(payload.story_progress, 'Akt 2');
  assert.equal(payload.hours_played, 25.5);
  assert.equal(payload.is_backlog, true);
  assert.equal(payload.notes, 'Grym handling hittills!');
});

test('gamingGoalEngine: calculates tempo, focus games and suggested next game correctly', () => {
  const currentYear = new Date().getFullYear();

  // 1. Tempo calculation (late October: ~82% of year passed, 9/10 games is ahead of pace)
  const tempoAhead = GamingGoalEngine.calculateTempo(10, 9, currentYear);
  assert.equal(tempoAhead.isAheadOfPace, true);
  assert.equal(tempoAhead.remainingGames, 1);

  const tempoReached = GamingGoalEngine.calculateTempo(10, 10, currentYear);
  assert.equal(tempoReached.isGoalReached, true);
  assert.equal(tempoReached.remainingGames, 0);

  // 2. Suggested next game (prefers active playing over paused and backlog)
  const games: any[] = [
    { id: '1', title: 'Playing Game', status: 'playing', is_owned: true, play_types: ['singlePlayer'] },
    { id: '2', title: 'Paused Game', status: 'paused', is_owned: true, play_types: ['singlePlayer'] },
    { id: '3', title: 'Multiplayer Game', status: 'playing', is_owned: true, play_types: ['multiplayer', 'ongoing'] },
  ];

  const suggested = GamingGoalEngine.suggestedNextGame(games, []);
  assert.equal(suggested?.id, '1');

  // If playing game is already a target, prefer paused
  const suggested2 = GamingGoalEngine.suggestedNextGame(games, ['1']);
  assert.equal(suggested2?.id, '2');
});
