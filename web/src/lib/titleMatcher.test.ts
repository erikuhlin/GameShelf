import test from 'node:test';
import assert from 'node:assert/strict';
import { isTitleMatch, tokenizeForMatching } from './titleMatcher';

test('titleMatcher: Grand Theft Auto VI must NOT match Vice City or GTA V', () => {
  // Buggen som användaren upptäckte:
  assert.equal(isTitleMatch('Grand Theft Auto VI', 'Grand Theft Auto: Vice City – The Definitive Edition'), false);
  assert.equal(isTitleMatch('Grand Theft Auto VI', 'Grand Theft Auto: Vice City'), false);
  assert.equal(isTitleMatch('Grand Theft Auto VI', 'Grand Theft Auto V'), false);
  assert.equal(isTitleMatch('Grand Theft Auto VI', 'Grand Theft Auto: San Andreas'), false);
  assert.equal(isTitleMatch('Grand Theft Auto VI', 'Grand Theft Auto IV'), false);
  assert.equal(isTitleMatch('Grand Theft Auto VI', 'Grand Theft Auto'), false);

  // Ska dock matcha legitima varianter av GTA 6
  assert.equal(isTitleMatch('Grand Theft Auto VI', 'Grand Theft Auto 6'), true);
  assert.equal(isTitleMatch('Grand Theft Auto VI', 'Grand Theft Auto VI'), true);
  assert.equal(isTitleMatch('Grand Theft Auto 6', 'Grand Theft Auto VI'), true);
});

test('titleMatcher: Handles sequence numbers and sequels correctly', () => {
  assert.equal(isTitleMatch('Fallout 3', 'Fallout 4'), false);
  assert.equal(isTitleMatch('Dark Souls II', 'Dark Souls III'), false);
  assert.equal(isTitleMatch('BioShock', 'BioShock 2'), false);
  assert.equal(isTitleMatch('Half-Life', 'Half-Life 2'), false);
});

test('titleMatcher: Matches legitimate editions and accents', () => {
  assert.equal(
    isTitleMatch('The Witcher 3: Wild Hunt', 'The Witcher 3: Wild Hunt - Game of the Year Edition'),
    true
  );
  assert.equal(
    isTitleMatch('The Witcher 3: Wild Hunt', 'The Witcher 3: Wild Hunt – Complete Edition'),
    true
  );
  assert.equal(
    isTitleMatch('Grand Theft Auto: Vice City', 'Grand Theft Auto: Vice City – The Definitive Edition'),
    true
  );
  assert.equal(
    isTitleMatch('God of War Ragnarök', 'God of War Ragnarok'),
    true
  );
});

test('titleMatcher: Rejects soundtracks and DLC when searching base game', () => {
  assert.equal(isTitleMatch('Elden Ring', 'ELDEN RING Original Soundtrack'), false);
  assert.equal(isTitleMatch('Cyberpunk 2077', 'Cyberpunk 2077: Phantom Liberty (DLC)'), false);
});
