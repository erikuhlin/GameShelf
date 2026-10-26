export type WalkthroughProgressionType = 'chapters' | 'acts' | 'main_quests' | 'bosses' | 'worlds' | 'none';

export interface WalkthroughItem {
  id: string;
  title: string;
  order: number;
  chapterGroup?: string;
  description?: string;
  isOptional?: boolean;
}

export interface VerifiedWalkthrough {
  igdbId: number;
  alternateIgdbIds?: number[];
  title: string;
  aliases?: string[];
  hasLinearProgression: boolean;
  progressionType: WalkthroughProgressionType;
  summary: string;
  sourceUrl: string;
  items: WalkthroughItem[];
}

export function normalizeWalkthroughTitle(title: string): string {
  return title
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/\b(remake|remastered|definitive edition|gold edition|nintendo switch 2 edition|shadow of the erdtree edition)\b/gi, '')
    .replace(/['’]/g, '')
    .replace(/[:\-–—()\[\]]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

export const VERIFIED_WALKTHROUGHS: VerifiedWalkthrough[] = [
  // ============================================================================
  // 1. KINGDOM COME: DELIVERANCE II (32 officiella huvuduppdrag 1:1)
  // ============================================================================
  {
    igdbId: 298526,
    alternateIgdbIds: [317636],
    title: 'Kingdom Come: Deliverance II',
    aliases: ['Kingdom Come Deliverance 2', 'Kingdom Come: Deliverance 2', 'Kingdom Come II'],
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Henrys resa genom Trosky- och Kuttenberg-regionerna i samtliga 32 officiella huvuduppdrag (1:1 med IGN Walkthrough).',
    sourceUrl: 'https://www.ign.com/wikis/kingdom-come-deliverance-2/Walkthrough',
    items: [
      { id: 'kcd2-1', title: 'Last Rites', order: 1, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-2', title: 'Easy Riders', order: 2, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-3', title: 'Fortuna', order: 3, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-4', title: 'Laboratores', order: 4, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-5', title: 'Wedding Crashers', order: 5, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-6', title: 'For Whom the Bell Tolls', order: 6, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-7', title: 'Back in the Saddle', order: 7, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-8', title: 'Necessary Evil', order: 8, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-9', title: 'For Victory!', order: 9, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-10', title: 'Divine Messenger', order: 10, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-11', title: 'The Finger of God', order: 11, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-12', title: 'The Storm', order: 12, chapterGroup: 'Akt 1: Trosky' },
      { id: 'kcd2-13', title: 'The Sword and the Quill', order: 13, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-14', title: 'Speak of the Devil', order: 14, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-15', title: "The Devil's Pack", order: 15, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-16', title: 'Into the Underworld', order: 16, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-17', title: 'Via Argentum', order: 17, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-18', title: 'Taking French Leave', order: 18, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-19', title: "The King's Gambit", order: 19, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-20', title: 'The Feast', order: 20, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-21', title: 'Exodus', order: 21, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-22', title: "The Lion's Den", order: 22, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-23', title: 'Dancing with the Devil', order: 23, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-24', title: 'Oratores', order: 24, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-25', title: 'The Italian Job', order: 25, chapterGroup: 'Akt 2: Kuttenberg' },
      { id: 'kcd2-26', title: 'Civitas Pragensis', order: 26, chapterGroup: 'Akt 3: Belägringen & Final' },
      { id: 'kcd2-27', title: 'So It Begins...', order: 27, chapterGroup: 'Akt 3: Belägringen & Final' },
      { id: 'kcd2-28', title: 'Besieged', order: 28, chapterGroup: 'Akt 3: Belägringen & Final' },
      { id: 'kcd2-29', title: 'Hunger and Despair', order: 29, chapterGroup: 'Akt 3: Belägringen & Final' },
      { id: 'kcd2-30', title: 'Reckoning', order: 30, chapterGroup: 'Akt 3: Belägringen & Final' },
      { id: 'kcd2-31', title: 'Last Will', order: 31, chapterGroup: 'Akt 3: Belägringen & Final' },
      { id: 'kcd2-32', title: 'Judgement Day', order: 32, chapterGroup: 'Akt 3: Belägringen & Final' },
    ],
  },

  // ============================================================================
  // 2. KINGDOM COME: DELIVERANCE (29 officiella huvuduppdrag 1:1)
  // ============================================================================
  {
    igdbId: 4843,
    title: 'Kingdom Come: Deliverance',
    aliases: ['Kingdom Come Deliverance'],
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Smeden Henrys resa genom det medeltida Böhmen i samtliga 29 officiella huvuduppdrag från Skalitz till Epilogue.',
    sourceUrl: 'https://www.ign.com/wikis/kingdom-come-deliverance/Walkthrough',
    items: [
      { id: 'kcd1-1', title: 'Unexpected Visitors', order: 1, chapterGroup: 'Prolog: Skalitz & Talmberg' },
      { id: 'kcd1-2', title: 'Run!', order: 2, chapterGroup: 'Prolog: Skalitz & Talmberg' },
      { id: 'kcd1-3', title: 'Homecoming', order: 3, chapterGroup: 'Prolog: Skalitz & Talmberg' },
      { id: 'kcd1-4', title: 'Awakening', order: 4, chapterGroup: 'Prolog: Skalitz & Talmberg' },
      { id: 'kcd1-5', title: 'Train Hard, Fight Easy', order: 5, chapterGroup: 'Akt 1: Rattay & Neuhof' },
      { id: 'kcd1-6', title: 'Keeping the Peace', order: 6, chapterGroup: 'Akt 1: Rattay & Neuhof' },
      { id: 'kcd1-7', title: 'The Prey', order: 7, chapterGroup: 'Akt 1: Rattay & Neuhof' },
      { id: 'kcd1-8', title: 'The Hunt Begins', order: 8, chapterGroup: 'Akt 1: Rattay & Neuhof' },
      { id: 'kcd1-9', title: 'Ginger in a Pickle', order: 9, chapterGroup: 'Akt 1: Rattay & Neuhof' },
      { id: 'kcd1-10', title: 'Mysterious Ways', order: 10, chapterGroup: 'Akt 1: Rattay & Neuhof' },
      { id: 'kcd1-11', title: 'On the Scent', order: 11, chapterGroup: 'Akt 1: Rattay & Neuhof' },
      { id: 'kcd1-12', title: 'My Friend Timmy', order: 12, chapterGroup: 'Akt 1: Rattay & Neuhof' },
      { id: 'kcd1-13', title: 'Nest of Vipers', order: 13, chapterGroup: 'Akt 1: Rattay & Neuhof' },
      { id: 'kcd1-14', title: 'Baptism of Fire', order: 14, chapterGroup: 'Akt 1: Rattay & Neuhof' },
      { id: 'kcd1-15', title: 'Questions and Answers', order: 15, chapterGroup: 'Akt 2: Sasau & Klostret' },
      { id: 'kcd1-16', title: 'All that Glisters', order: 16, chapterGroup: 'Akt 2: Sasau & Klostret' },
      { id: 'kcd1-17', title: "If You Can't Beat 'em", order: 17, chapterGroup: 'Akt 2: Sasau & Klostret' },
      { id: 'kcd1-18', title: 'Poverty, Chastity and Pestilence', order: 18, chapterGroup: 'Akt 2: Sasau & Klostret' },
      { id: 'kcd1-19', title: 'A Needle in a Haystack', order: 19, chapterGroup: 'Akt 2: Sasau & Klostret' },
      { id: 'kcd1-20', title: 'The Die is Cast', order: 20, chapterGroup: 'Akt 2: Sasau & Klostret' },
      { id: 'kcd1-21', title: 'Payback', order: 21, chapterGroup: 'Akt 2: Sasau & Klostret' },
      { id: 'kcd1-22', title: 'Out of the Frying Pan', order: 22, chapterGroup: 'Akt 3: Talmberg & Final' },
      { id: 'kcd1-23', title: 'Night Raid', order: 23, chapterGroup: 'Akt 3: Talmberg & Final' },
      { id: 'kcd1-24', title: 'Siege', order: 24, chapterGroup: 'Akt 3: Talmberg & Final' },
      { id: 'kcd1-25', title: 'Cold Steel, Hot Blood', order: 25, chapterGroup: 'Akt 3: Talmberg & Final' },
      { id: 'kcd1-26', title: 'Family Values', order: 26, chapterGroup: 'Akt 3: Talmberg & Final' },
      { id: 'kcd1-27', title: 'An Oath is an Oath', order: 27, chapterGroup: 'Akt 3: Talmberg & Final' },
      { id: 'kcd1-28', title: 'Vengeance', order: 28, chapterGroup: 'Akt 3: Talmberg & Final' },
      { id: 'kcd1-29', title: 'Epilogue', order: 29, chapterGroup: 'Akt 3: Talmberg & Final' },
    ],
  },

  // ============================================================================
  // 3. S.T.A.L.K.E.R. 2: HEART OF CHORNOBYL (35 huvuduppdrag 1:1)
  // ============================================================================
  {
    igdbId: 101440,
    title: 'S.T.A.L.K.E.R. 2: Heart of Chornobyl',
    aliases: ['STALKER 2: Heart of Chornobyl', 'STALKER 2', 'S.T.A.L.K.E.R. 2'],
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Skiffs resa genom Zonen i samtliga 35 officiella huvuduppdrag från Lesser Zone till Chornobyl-finalen.',
    sourceUrl: 'https://www.ign.com/wikis/stalker-2-heart-of-chornobyl/Walkthrough',
    items: [
      { id: 's2-1', title: 'There and Back Again', order: 1, chapterGroup: 'Akt 1: Lesser Zone' },
      { id: 's2-2', title: 'A Tough Awakening', order: 2, chapterGroup: 'Akt 1: Lesser Zone' },
      { id: 's2-3', title: 'Behind Seven Seals', order: 3, chapterGroup: 'Akt 1: Lesser Zone' },
      { id: 's2-4', title: 'A Needle in a Haystack', order: 4, chapterGroup: 'Akt 1: Lesser Zone' },
      { id: 's2-5', title: 'Answers Come at a Price', order: 5, chapterGroup: 'Akt 1: Lesser Zone' },
      { id: 's2-6', title: 'The Price Goes Up', order: 6, chapterGroup: 'Akt 2: Garbage & Wild Island' },
      { id: 's2-7', title: 'Deal with the Devil', order: 7, chapterGroup: 'Akt 2: Garbage & Wild Island' },
      { id: 's2-8', title: 'King of the Hill', order: 8, chapterGroup: 'Akt 2: Garbage & Wild Island' },
      { id: 's2-9', title: 'Back to the Slag Heap', order: 9, chapterGroup: 'Akt 2: Garbage & Wild Island' },
      { id: 's2-10', title: 'Hot on the Trail', order: 10, chapterGroup: 'Akt 2: Garbage & Wild Island' },
      { id: 's2-11', title: 'Chasing Ghosts', order: 11, chapterGroup: 'Akt 2: Garbage & Wild Island' },
      { id: 's2-12', title: 'Dead Frequency', order: 12, chapterGroup: 'Akt 3: Zaton, Swamps & SIRCAA' },
      { id: 's2-13', title: 'Like a Moth to the Flame', order: 13, chapterGroup: 'Akt 3: Zaton, Swamps & SIRCAA' },
      { id: 's2-14', title: 'In Search of a Guide', order: 14, chapterGroup: 'Akt 3: Zaton, Swamps & SIRCAA' },
      { id: 's2-15', title: 'Ad Astra Per Aspera', order: 15, chapterGroup: 'Akt 3: Zaton, Swamps & SIRCAA' },
      { id: 's2-16', title: 'Extreme Simplicity', order: 16, chapterGroup: 'Akt 3: Zaton, Swamps & SIRCAA' },
      { id: 's2-17', title: 'A Long Overdue Visit', order: 17, chapterGroup: 'Akt 3: Zaton, Swamps & SIRCAA' },
      { id: 's2-18', title: 'The Forge of Progress', order: 18, chapterGroup: 'Akt 3: Zaton, Swamps & SIRCAA' },
      { id: 's2-19', title: 'Wishful Thinking', order: 19, chapterGroup: 'Akt 3: Zaton, Swamps & SIRCAA' },
      { id: 's2-20', title: 'To the Last Drop of Blood / Law and Order', order: 20, chapterGroup: 'Akt 4: Duga & Malachite' },
      { id: 's2-21', title: 'Just Like the Good Old Days', order: 21, chapterGroup: 'Akt 4: Duga & Malachite' },
      { id: 's2-22', title: "The Hornet's Nest", order: 22, chapterGroup: 'Akt 4: Duga & Malachite' },
      { id: 's2-23', title: 'An Invisible Threat', order: 23, chapterGroup: 'Akt 4: Duga & Malachite' },
      { id: 's2-24', title: 'Dawn of a New Day', order: 24, chapterGroup: 'Akt 4: Duga & Malachite' },
      { id: 's2-25', title: 'The Assault on the Duga', order: 25, chapterGroup: 'Akt 4: Duga & Malachite' },
      { id: 's2-26', title: 'A Minor Incident', order: 26, chapterGroup: 'Akt 4: Duga & Malachite' },
      { id: 's2-27', title: 'In Search of Past Glory', order: 27, chapterGroup: 'Akt 4: Duga & Malachite' },
      { id: 's2-28', title: 'Happiness for Everyone / Once More Unto the Breach', order: 28, chapterGroup: 'Akt 5: Red Forest & Pripyat' },
      { id: 's2-29', title: 'Visions of Truth', order: 29, chapterGroup: 'Akt 5: Red Forest & Pripyat' },
      { id: 's2-30', title: 'Dark Times', order: 30, chapterGroup: 'Akt 5: Red Forest & Pripyat' },
      { id: 's2-31', title: 'An Act of Mercy', order: 31, chapterGroup: 'Akt 5: Red Forest & Pripyat' },
      { id: 's2-32', title: 'Legends of the Zone', order: 32, chapterGroup: 'Akt 5: Red Forest & Pripyat' },
      { id: 's2-33', title: 'The Road to the Foundation', order: 33, chapterGroup: 'Final: Foundation & Generators' },
      { id: 's2-34', title: 'Down Below', order: 34, chapterGroup: 'Final: Foundation & Generators' },
      { id: 's2-35', title: 'The Last Wish / Let No One Leave Unsatisfied', order: 35, chapterGroup: 'Final: Foundation & Generators' },
    ],
  },

  // ============================================================================
  // 4. DISCO ELYSIUM (17 huvuduppgifter i mordutredningen 1:1)
  // ============================================================================
  {
    igdbId: 26472,
    title: 'Disco Elysium',
    aliases: ['Disco Elysium: The Final Cut'],
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Mordutredningen i Martinaise uppdelad i samtliga 17 centrala utredningssteg från uppvaknandet på Whirling-in-Rags till ön.',
    sourceUrl: 'https://www.ign.com/wikis/disco-elysium/Walkthrough',
    items: [
      { id: 'de-1', title: 'Waking Up & Finding Your Clothes', order: 1, chapterGroup: 'Del 1: Brottsplatsen & Obduktionen' },
      { id: 'de-2', title: 'Meet Lieutenant Kim Kitsuragi in the Lobby', order: 2, chapterGroup: 'Del 1: Brottsplatsen & Obduktionen' },
      { id: 'de-3', title: 'Inspect the Hanging Body in the Courtyard', order: 3, chapterGroup: 'Del 1: Brottsplatsen & Obduktionen' },
      { id: 'de-4', title: 'Get the Body Down from the Tree', order: 4, chapterGroup: 'Del 1: Brottsplatsen & Obduktionen' },
      { id: 'de-5', title: 'Perform Field Autopsy with Kim', order: 5, chapterGroup: 'Del 1: Brottsplatsen & Obduktionen' },
      { id: 'de-6', title: "Send the Victim's Body to Processing", order: 6, chapterGroup: 'Del 1: Brottsplatsen & Obduktionen' },
      { id: 'de-7', title: 'Interview the Cafeteria Manager (Garte)', order: 7, chapterGroup: 'Del 2: Förhör i Martinaise' },
      { id: 'de-8', title: 'Interview Klaasje, the Upstairs Smoker', order: 8, chapterGroup: 'Del 2: Förhör i Martinaise' },
      { id: 'de-9', title: 'Speak with Joyce Messier (Wild Pines Rep)', order: 9, chapterGroup: 'Del 2: Förhör i Martinaise' },
      { id: 'de-10', title: 'Enter the Harbor & Question Union Boss Evrart Claire', order: 10, chapterGroup: 'Del 2: Förhör i Martinaise' },
      { id: 'de-11', title: 'Question Titus Hardie and the Hardie Boys', order: 11, chapterGroup: 'Del 2: Förhör i Martinaise' },
      { id: 'de-12', title: "Unlock the Water Lock & Explore the Fishing Village", order: 12, chapterGroup: 'Del 3: Kustlinjen, Ruby & Tribunalen' },
      { id: 'de-13', title: 'Inspect Klaasje’s Window & Reconstruct the Shot Trajectory', order: 13, chapterGroup: 'Del 3: Kustlinjen, Ruby & Tribunalen' },
      { id: 'de-14', title: 'Track Down Ruby in the Abandoned Feld Building', order: 14, chapterGroup: 'Del 3: Kustlinjen, Ruby & Tribunalen' },
      { id: 'de-15', title: 'The Mercenary Tribunal at the Whirling-in-Rags', order: 15, chapterGroup: 'Del 3: Kustlinjen, Ruby & Tribunalen' },
      { id: 'de-16', title: 'Go to the Sea Fortress Island & Confront the Deserter', order: 16, chapterGroup: 'Del 4: Ön & Upplösningen' },
      { id: 'de-17', title: 'The Return: Final Debriefing with Precinct 41', order: 17, chapterGroup: 'Del 4: Ön & Upplösningen' },
    ],
  },

  // ============================================================================
  // 5. CYBERPUNK 2077 (28 officiella Main Jobs 1:1)
  // ============================================================================
  {
    igdbId: 1877,
    title: 'Cyberpunk 2077',
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'V:s resa i Night City genom samtliga 28 officiella huvuduppdrag (Main Jobs) från Lifepath-prologen till efterspelet.',
    sourceUrl: 'https://www.ign.com/wikis/cyberpunk-2077/Walkthrough',
    items: [
      { id: 'cp-1', title: 'Lifepath Prologue (The Nomad / The Streetkid / The Corpo-Rat)', order: 1, chapterGroup: 'Prolog' },
      { id: 'cp-2', title: 'Practice Makes Perfect', order: 2, chapterGroup: 'Prolog' },
      { id: 'cp-3', title: 'The Rescue', order: 3, chapterGroup: 'Prolog' },
      { id: 'cp-4', title: 'The Ripperdoc', order: 4, chapterGroup: 'Akt 1' },
      { id: 'cp-5', title: 'The Ride', order: 5, chapterGroup: 'Akt 1' },
      { id: 'cp-6', title: 'The Information', order: 6, chapterGroup: 'Akt 1' },
      { id: 'cp-7', title: 'The Pickup', order: 7, chapterGroup: 'Akt 1' },
      { id: 'cp-8', title: 'The Heist', order: 8, chapterGroup: 'Akt 1' },
      { id: 'cp-9', title: 'Love Like Fire', order: 9, chapterGroup: 'Akt 1' },
      { id: 'cp-10', title: 'Playing for Time', order: 10, chapterGroup: 'Akt 2' },
      { id: 'cp-11', title: 'Automatic Love', order: 11, chapterGroup: 'Akt 2 (Evelyn & Judy)' },
      { id: 'cp-12', title: 'The Space in Between', order: 12, chapterGroup: 'Akt 2 (Evelyn & Judy)' },
      { id: 'cp-13', title: 'Disasterpiece', order: 13, chapterGroup: 'Akt 2 (Evelyn & Judy)' },
      { id: 'cp-14', title: 'Double Life', order: 14, chapterGroup: 'Akt 2 (Evelyn & Judy)' },
      { id: 'cp-15', title: "M'ap Tann Pèlen", order: 15, chapterGroup: 'Akt 2 (Voodoo Boys)' },
      { id: 'cp-16', title: 'I Walk the Line', order: 16, chapterGroup: 'Akt 2 (Voodoo Boys)' },
      { id: 'cp-17', title: 'Never Fade Away', order: 17, chapterGroup: 'Akt 2 (Voodoo Boys)' },
      { id: 'cp-18', title: 'Transmission', order: 18, chapterGroup: 'Akt 2 (Voodoo Boys)' },
      { id: 'cp-19', title: 'Ghost Town', order: 19, chapterGroup: 'Akt 2 (Panam & Hellman)' },
      { id: 'cp-20', title: 'Lightning Breaks', order: 20, chapterGroup: 'Akt 2 (Panam & Hellman)' },
      { id: 'cp-21', title: 'Life During Wartime', order: 21, chapterGroup: 'Akt 2 (Panam & Hellman)' },
      { id: 'cp-22', title: 'Down on the Street', order: 22, chapterGroup: 'Akt 2 (Takemura)' },
      { id: 'cp-23', title: 'Gimme Danger', order: 23, chapterGroup: 'Akt 2 (Takemura)' },
      { id: 'cp-24', title: 'Play It Safe', order: 24, chapterGroup: 'Akt 2 (Takemura)' },
      { id: 'cp-25', title: 'Search and Destroy', order: 25, chapterGroup: 'Akt 2 (Takemura)' },
      { id: 'cp-26', title: 'Tapeworm', order: 26, chapterGroup: 'Akt 2' },
      { id: 'cp-27', title: 'Nocturne Op55N1 (Point of No Return)', order: 27, chapterGroup: 'Akt 3 & Final' },
      { id: 'cp-28', title: 'Final Run & Epilogue (Mikoshi)', order: 28, chapterGroup: 'Akt 3 & Final' },
    ],
  },

  // ============================================================================
  // 6. SILENT HILL 2 (13 officiella Walkthrough-zoner 1:1)
  // ============================================================================
  {
    igdbId: 222341,
    title: 'Silent Hill 2',
    aliases: ['Silent Hill 2 Remake', 'Silent Hill 2 (Remake)'],
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'James Sunderlands färd genom Silent Hill i samtliga 13 officiella walkthrough-områden från East South Vale till Lakeview Hotel.',
    sourceUrl: 'https://www.ign.com/wikis/silent-hill-2-remake/Walkthrough',
    items: [
      { id: 'sh2-1', title: 'East South Vale', order: 1, chapterGroup: 'Akt 1: South Vale & Apartments' },
      { id: 'sh2-2', title: 'Wood Side Apartments', order: 2, chapterGroup: 'Akt 1: South Vale & Apartments' },
      { id: 'sh2-3', title: 'Blue Creek Apartments', order: 3, chapterGroup: 'Akt 1: South Vale & Apartments' },
      { id: 'sh2-4', title: 'West South Vale & Rosewater Park', order: 4, chapterGroup: 'Akt 1: South Vale & Apartments' },
      { id: 'sh2-5', title: 'Brookhaven Hospital', order: 5, chapterGroup: 'Akt 2: Brookhaven Hospital' },
      { id: 'sh2-6', title: 'Brookhaven Hospital (Otherworld)', order: 6, chapterGroup: 'Akt 2: Brookhaven Hospital' },
      { id: 'sh2-7', title: 'South Vale (Otherworld)', order: 7, chapterGroup: 'Akt 2: Brookhaven Hospital' },
      { id: 'sh2-8', title: 'Silent Hill Historical Society', order: 8, chapterGroup: 'Akt 3: Prison & Labyrinth' },
      { id: 'sh2-9', title: 'Toluca Prison', order: 9, chapterGroup: 'Akt 3: Prison & Labyrinth' },
      { id: 'sh2-10', title: 'Labyrinth', order: 10, chapterGroup: 'Akt 3: Prison & Labyrinth' },
      { id: 'sh2-11', title: 'Toluca Lake', order: 11, chapterGroup: 'Akt 4: Lakeview Hotel & Final' },
      { id: 'sh2-12', title: 'Lakeview Hotel', order: 12, chapterGroup: 'Akt 4: Lakeview Hotel & Final' },
      { id: 'sh2-13', title: 'Lakeview Hotel (Otherworld) & Final Boss', order: 13, chapterGroup: 'Akt 4: Lakeview Hotel & Final' },
    ],
  },

  // ============================================================================
  // 7. ALAN WAKE II (18 officiella kapitel: Return 1-9 & Initiation 1-9)
  // ============================================================================
  {
    igdbId: 185246,
    title: 'Alan Wake II',
    aliases: ['Alan Wake 2'],
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Saga Andersons och Alan Wakes sammanflätade kapitel (Return 1–9 och Initiation 1–9) i IGN:s rekommenderade spelordning.',
    sourceUrl: 'https://www.ign.com/wikis/alan-wake-2/Walkthrough',
    items: [
      { id: 'aw2-1', title: 'Return 1: Invitation', order: 1, chapterGroup: 'Akt 1: Cauldron Lake & Dark Place' },
      { id: 'aw2-2', title: 'Return 2: The Heart', order: 2, chapterGroup: 'Akt 1: Cauldron Lake & Dark Place' },
      { id: 'aw2-3', title: 'Initiation 1: Late Night', order: 3, chapterGroup: 'Akt 1: Cauldron Lake & Dark Place' },
      { id: 'aw2-4', title: 'Initiation 2: Casey', order: 4, chapterGroup: 'Akt 1: Cauldron Lake & Dark Place' },
      { id: 'aw2-5', title: 'Initiation 3: Haunting', order: 5, chapterGroup: 'Akt 1: Cauldron Lake & Dark Place' },
      { id: 'aw2-6', title: 'Return 3: Local Girl', order: 6, chapterGroup: 'Akt 2: Watery & Oceanview Hotel' },
      { id: 'aw2-7', title: 'Initiation 4: We Sing', order: 7, chapterGroup: 'Akt 2: Watery & Oceanview Hotel' },
      { id: 'aw2-8', title: 'Initiation 5: Room 665', order: 8, chapterGroup: 'Akt 2: Watery & Oceanview Hotel' },
      { id: 'aw2-9', title: 'Initiation 6: Return', order: 9, chapterGroup: 'Akt 2: Watery & Oceanview Hotel' },
      { id: 'aw2-10', title: 'Return 4: No Chance', order: 10, chapterGroup: 'Akt 2: Watery & Oceanview Hotel' },
      { id: 'aw2-11', title: 'Return 5: Old Gods', order: 11, chapterGroup: 'Akt 2: Watery & Oceanview Hotel' },
      { id: 'aw2-12', title: 'Initiation 7: Masks', order: 12, chapterGroup: 'Akt 3: Bright Falls & Slutet' },
      { id: 'aw2-13', title: "Initiation 8: Zane's Film", order: 13, chapterGroup: 'Akt 3: Bright Falls & Slutet' },
      { id: 'aw2-14', title: 'Return 6: Scratch', order: 14, chapterGroup: 'Akt 3: Bright Falls & Slutet' },
      { id: 'aw2-15', title: 'Return 7: Summoning', order: 15, chapterGroup: 'Akt 3: Bright Falls & Slutet' },
      { id: 'aw2-16', title: 'Initiation 9: Gone', order: 16, chapterGroup: 'Akt 3: Bright Falls & Slutet' },
      { id: 'aw2-17', title: 'Return 8: Deerfest', order: 17, chapterGroup: 'Akt 3: Bright Falls & Slutet' },
      { id: 'aw2-18', title: 'Return 9: Come Home', order: 18, chapterGroup: 'Akt 3: Bright Falls & Slutet' },
    ],
  },

  // ============================================================================
  // 8. GOD OF WAR RAGNARÖK (18 officiella huvuduppdrag "The Path" 1:1)
  // ============================================================================
  {
    igdbId: 112875,
    title: 'God of War Ragnarök',
    aliases: ['God of War Ragnarok'],
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Kratos och Atreus resa genom de nio världarna i samtliga 18 officiella huvuduppdrag (The Path).',
    sourceUrl: 'https://www.ign.com/wikis/god-of-war-ragnarok/Walkthrough',
    items: [
      { id: 'gowr-1', title: 'Surviving Fimbulwinter', order: 1, chapterGroup: 'Akt 1: Fimbulwinter & Svartalfheim' },
      { id: 'gowr-2', title: 'The Quest for Tyr', order: 2, chapterGroup: 'Akt 1: Fimbulwinter & Svartalfheim' },
      { id: 'gowr-3', title: 'Old Friends', order: 3, chapterGroup: 'Akt 1: Fimbulwinter & Svartalfheim' },
      { id: 'gowr-4', title: "Groa's Secret", order: 4, chapterGroup: 'Akt 1: Fimbulwinter & Svartalfheim' },
      { id: 'gowr-5', title: 'The Lost Sanctuary', order: 5, chapterGroup: 'Akt 1: Fimbulwinter & Svartalfheim' },
      { id: 'gowr-6', title: 'The Reckoning', order: 6, chapterGroup: 'Akt 1: Fimbulwinter & Svartalfheim' },
      { id: 'gowr-7', title: 'The Runaway', order: 7, chapterGroup: 'Akt 2: Asgard, spjutet & Hel' },
      { id: 'gowr-8', title: 'Into the Fire', order: 8, chapterGroup: 'Akt 2: Asgard, spjutet & Hel' },
      { id: 'gowr-9', title: 'The Word of Fate', order: 9, chapterGroup: 'Akt 2: Asgard, spjutet & Hel' },
      { id: 'gowr-10', title: 'Forging Destiny', order: 10, chapterGroup: 'Akt 2: Asgard, spjutet & Hel' },
      { id: 'gowr-11', title: 'Unleashing Hel', order: 11, chapterGroup: 'Akt 2: Asgard, spjutet & Hel' },
      { id: 'gowr-12', title: 'Reunion', order: 12, chapterGroup: 'Akt 2: Asgard, spjutet & Hel' },
      { id: 'gowr-13', title: 'Creatures of Prophecy', order: 13, chapterGroup: 'Akt 3: Vanaheim & Ragnarök' },
      { id: 'gowr-14', title: 'Unlocking the Mask', order: 14, chapterGroup: 'Akt 3: Vanaheim & Ragnarök' },
      { id: 'gowr-15', title: 'Hunting for Solace', order: 15, chapterGroup: 'Akt 3: Vanaheim & Ragnarök' },
      { id: 'gowr-16', title: 'The Summoning', order: 16, chapterGroup: 'Akt 3: Vanaheim & Ragnarök' },
      { id: 'gowr-17', title: 'The Realms at War', order: 17, chapterGroup: 'Akt 3: Vanaheim & Ragnarök' },
      { id: 'gowr-18', title: 'Beyond Ragnarök (Epilogue)', order: 18, chapterGroup: 'Akt 3: Vanaheim & Ragnarök', isOptional: true },
    ],
  },

  // ============================================================================
  // 9. GOD OF WAR (2018) (17 officiella huvuduppdrag "The Journey" 1:1)
  // ============================================================================
  {
    igdbId: 19560,
    title: 'God of War',
    aliases: ['God of War (2018)'],
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Kratos och Atreus vandring till den högsta toppen genom samtliga 17 officiella huvuduppdrag (The Journey).',
    sourceUrl: 'https://www.ign.com/wikis/god-of-war-2018/Walkthrough',
    items: [
      { id: 'gow-1', title: 'The Marked Trees', order: 1, chapterGroup: 'Akt 1: Midgard & Alfheim' },
      { id: 'gow-2', title: 'Path to the Mountain', order: 2, chapterGroup: 'Akt 1: Midgard & Alfheim' },
      { id: 'gow-3', title: 'A Realm Beyond', order: 3, chapterGroup: 'Akt 1: Midgard & Alfheim' },
      { id: 'gow-4', title: 'The Light of Alfheim', order: 4, chapterGroup: 'Akt 1: Midgard & Alfheim' },
      { id: 'gow-5', title: 'Inside the Mountain', order: 5, chapterGroup: 'Akt 1: Midgard & Alfheim' },
      { id: 'gow-6', title: 'A New Destination', order: 6, chapterGroup: 'Akt 2: Mejseln, Helheim & Runan' },
      { id: 'gow-7', title: 'The Magic Chisel', order: 7, chapterGroup: 'Akt 2: Mejseln, Helheim & Runan' },
      { id: 'gow-8', title: 'Behind the Lock', order: 8, chapterGroup: 'Akt 2: Mejseln, Helheim & Runan' },
      { id: 'gow-9', title: 'The Sickness', order: 9, chapterGroup: 'Akt 2: Mejseln, Helheim & Runan' },
      { id: 'gow-10', title: 'The Black Rune', order: 10, chapterGroup: 'Akt 2: Mejseln, Helheim & Runan' },
      { id: 'gow-11', title: 'Return to the Summit', order: 11, chapterGroup: 'Akt 2: Mejseln, Helheim & Runan' },
      { id: 'gow-12', title: 'Escape from Helheim', order: 12, chapterGroup: 'Akt 3: Vägen till Jötunheim' },
      { id: 'gow-13', title: 'A Path to Jotunheim', order: 13, chapterGroup: 'Akt 3: Vägen till Jötunheim' },
      { id: 'gow-14', title: 'Between the Realms', order: 14, chapterGroup: 'Akt 3: Vägen till Jötunheim' },
      { id: 'gow-15', title: 'Jotunheim in Reach', order: 15, chapterGroup: 'Akt 3: Vägen till Jötunheim' },
      { id: 'gow-16', title: "Mother's Ashes", order: 16, chapterGroup: 'Akt 3: Vägen till Jötunheim' },
      { id: 'gow-17', title: 'The Journey Home', order: 17, chapterGroup: 'Akt 3: Vägen till Jötunheim' },
    ],
  },

  // ============================================================================
  // 10. THE WITCHER 3: WILD HUNT (47 officiella huvuduppdrag 1:1)
  // ============================================================================
  {
    igdbId: 1942,
    title: 'The Witcher 3: Wild Hunt',
    aliases: ['The Witcher 3'],
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Geralts sökande efter Ciri genom samtliga 47 officiella huvuduppdrag i Velen, Novigrad, Skellige och Kaer Morhen.',
    sourceUrl: 'https://www.ign.com/wikis/the-witcher-3-wild-hunt/Walkthrough',
    items: [
      { id: 'w3-1', title: 'Kaer Morhen', order: 1, chapterGroup: 'Prolog: White Orchard' },
      { id: 'w3-2', title: 'Lilac and Gooseberries', order: 2, chapterGroup: 'Prolog: White Orchard' },
      { id: 'w3-3', title: 'The Beast of White Orchard', order: 3, chapterGroup: 'Prolog: White Orchard' },
      { id: 'w3-4', title: 'Incident at White Orchard', order: 4, chapterGroup: 'Prolog: White Orchard' },
      { id: 'w3-5', title: 'Imperial Audience', order: 5, chapterGroup: 'Prolog: White Orchard' },
      { id: 'w3-6', title: 'The Nilfgaardian Connection', order: 6, chapterGroup: 'Akt 1: Velen' },
      { id: 'w3-7', title: 'Bloody Baron', order: 7, chapterGroup: 'Akt 1: Velen' },
      { id: 'w3-8', title: "Ciri's Story: The King of the Wolves", order: 8, chapterGroup: 'Akt 1: Velen' },
      { id: 'w3-9', title: 'Family Matters', order: 9, chapterGroup: 'Akt 1: Velen' },
      { id: 'w3-10', title: 'A Princess in Distress', order: 10, chapterGroup: 'Akt 1: Velen' },
      { id: 'w3-11', title: "Ciri's Story: The Race", order: 11, chapterGroup: 'Akt 1: Velen' },
      { id: 'w3-12', title: 'Hunting a Witch', order: 12, chapterGroup: 'Akt 1: Velen' },
      { id: 'w3-13', title: 'Wandering in the Dark', order: 13, chapterGroup: 'Akt 1: Velen' },
      { id: 'w3-14', title: 'Ladies of the Wood', order: 14, chapterGroup: 'Akt 1: Velen' },
      { id: 'w3-15', title: "Ciri's Story: Fleeing the Bog", order: 15, chapterGroup: 'Akt 1: Velen' },
      { id: 'w3-16', title: 'Pyres of Novigrad', order: 16, chapterGroup: 'Akt 1: Novigrad' },
      { id: 'w3-17', title: 'Novigrad Dreaming', order: 17, chapterGroup: 'Akt 1: Novigrad' },
      { id: 'w3-18', title: 'Broken Flowers', order: 18, chapterGroup: 'Akt 1: Novigrad' },
      { id: 'w3-19', title: 'Get Junior', order: 19, chapterGroup: 'Akt 1: Novigrad' },
      { id: 'w3-20', title: "Ciri's Story: Visiting Junior", order: 20, chapterGroup: 'Akt 1: Novigrad' },
      { id: 'w3-21', title: "Count Reuven's Treasure", order: 21, chapterGroup: 'Akt 1: Novigrad' },
      { id: 'w3-22', title: "Ciri's Story: Out of the Shadows", order: 22, chapterGroup: 'Akt 1: Novigrad' },
      { id: 'w3-23', title: "The Play's the Thing", order: 23, chapterGroup: 'Akt 1: Novigrad' },
      { id: 'w3-24', title: 'A Poet Under Pressure', order: 24, chapterGroup: 'Akt 1: Novigrad' },
      { id: 'w3-25', title: "Ciri's Story: Breakneck Speed", order: 25, chapterGroup: 'Akt 1: Novigrad' },
      { id: 'w3-26', title: 'Destination: Skellige', order: 26, chapterGroup: 'Akt 1: Skellige' },
      { id: 'w3-27', title: 'The King is Dead – Long Live the King', order: 27, chapterGroup: 'Akt 1: Skellige' },
      { id: 'w3-28', title: 'Echoes of the Past', order: 28, chapterGroup: 'Akt 1: Skellige' },
      { id: 'w3-29', title: 'Missing Persons', order: 29, chapterGroup: 'Akt 1: Skellige' },
      { id: 'w3-30', title: 'Nameless', order: 30, chapterGroup: 'Akt 1: Skellige' },
      { id: 'w3-31', title: 'The Calm Before the Storm', order: 31, chapterGroup: 'Akt 1: Skellige' },
      { id: 'w3-32', title: 'Ugly Baby', order: 32, chapterGroup: 'Akt 2: Kaer Morhen & Isle of Mists' },
      { id: 'w3-33', title: 'Disturbance', order: 33, chapterGroup: 'Akt 2: Kaer Morhen & Isle of Mists' },
      { id: 'w3-34', title: 'To Bait a Forktail...', order: 34, chapterGroup: 'Akt 2: Kaer Morhen & Isle of Mists' },
      { id: 'w3-35', title: 'The Final Trial', order: 35, chapterGroup: 'Akt 2: Kaer Morhen & Isle of Mists' },
      { id: 'w3-36', title: 'Va Fail, Elaine', order: 36, chapterGroup: 'Akt 2: Kaer Morhen & Isle of Mists' },
      { id: 'w3-37', title: 'Brothers in Arms', order: 37, chapterGroup: 'Akt 2: Kaer Morhen & Isle of Mists' },
      { id: 'w3-38', title: 'The Isle of Mists', order: 38, chapterGroup: 'Akt 2: Kaer Morhen & Isle of Mists' },
      { id: 'w3-39', title: 'The Battle of Kaer Morhen', order: 39, chapterGroup: 'Akt 2: Kaer Morhen & Isle of Mists' },
      { id: 'w3-40', title: 'Blood on the Battlefield', order: 40, chapterGroup: 'Akt 2: Kaer Morhen & Isle of Mists' },
      { id: 'w3-41', title: 'Bald Mountain', order: 41, chapterGroup: 'Akt 3: Final Preparations & Slutstriden' },
      { id: 'w3-42', title: 'Blindingly Obvious', order: 42, chapterGroup: 'Akt 3: Final Preparations & Slutstriden' },
      { id: 'w3-43', title: 'The Great Escape', order: 43, chapterGroup: 'Akt 3: Final Preparations & Slutstriden' },
      { id: 'w3-44', title: 'Payback', order: 44, chapterGroup: 'Akt 3: Final Preparations & Slutstriden' },
      { id: 'w3-45', title: 'Through Time and Space', order: 45, chapterGroup: 'Akt 3: Final Preparations & Slutstriden' },
      { id: 'w3-46', title: 'Battle Preparations', order: 46, chapterGroup: 'Akt 3: Final Preparations & Slutstriden' },
      { id: 'w3-47', title: 'The Sunstone', order: 47, chapterGroup: 'Akt 3: Final Preparations & Slutstriden' },
      { id: 'w3-48', title: 'On Thin Ice', order: 48, chapterGroup: 'Akt 3: Final Preparations & Slutstriden' },
      { id: 'w3-49', title: 'Tedd Deireadh, The Final Age', order: 49, chapterGroup: 'Akt 3: Final Preparations & Slutstriden' },
      { id: 'w3-50', title: 'Something Ends, Something Begins (Epilogue)', order: 50, chapterGroup: 'Akt 3: Final Preparations & Slutstriden' },
    ],
  },

  // ============================================================================
  // 11. BALDUR'S GATE III (19 huvuddelmål genom Akt 1, 2 och 3)
  // ============================================================================
  {
    igdbId: 119171,
    title: "Baldur's Gate III",
    aliases: ["Baldur's Gate 3", 'Baldurs Gate 3'],
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Huvudkampanjen i Baldur’s Gate III uppdelad i samtliga 19 centrala storyuppdrag genom Prolog, Akt 1, Akt 2 och Akt 3.',
    sourceUrl: 'https://www.ign.com/wikis/baldurs-gate-3/Walkthrough',
    items: [
      { id: 'bg3-1', title: 'Escape the Nautiloid', order: 1, chapterGroup: 'Prolog' },
      { id: 'bg3-2', title: 'Find a Cure & Explore the Ravaged Beach', order: 2, chapterGroup: 'Akt 1: Vildmarken & Underdark' },
      { id: 'bg3-3', title: 'Save the Refugees at the Emerald Grove', order: 3, chapterGroup: 'Akt 1: Vildmarken & Underdark' },
      { id: 'bg3-4', title: 'Rescue the Druid Halsin & Defeat the Goblin Leaders', order: 4, chapterGroup: 'Akt 1: Vildmarken & Underdark' },
      { id: 'bg3-5', title: 'Travel Through the Underdark', order: 5, chapterGroup: 'Akt 1: Vildmarken & Underdark' },
      { id: 'bg3-6', title: 'Grymforge & Reach Moonrise via Elevator', order: 6, chapterGroup: 'Akt 1: Vildmarken & Underdark' },
      { id: 'bg3-7', title: 'Rosymorn Monastery & The Mountain Pass', order: 7, chapterGroup: 'Akt 1: Vildmarken & Underdark' },
      { id: 'bg3-8', title: "Infiltrate the Githyanki Crèche (Crèche Y'llek)", order: 8, chapterGroup: 'Akt 1: Vildmarken & Underdark' },
      { id: 'bg3-9', title: 'Seek Protection from the Shadow Curse (Last Light Inn)', order: 9, chapterGroup: 'Akt 2: Shadow-Cursed Lands' },
      { id: 'bg3-10', title: 'Infiltrate Moonrise Towers', order: 10, chapterGroup: 'Akt 2: Shadow-Cursed Lands' },
      { id: 'bg3-11', title: 'Find the Nightsong in the Gauntlet of Shar', order: 11, chapterGroup: 'Akt 2: Shadow-Cursed Lands' },
      { id: 'bg3-12', title: 'Assault on Moonrise Towers', order: 12, chapterGroup: 'Akt 2: Shadow-Cursed Lands' },
      { id: 'bg3-13', title: 'Defeat Ketheric Thorm & The Apostle of Myrkul', order: 13, chapterGroup: 'Akt 2: Shadow-Cursed Lands' },
      { id: 'bg3-14', title: "Rivington & Wyrm's Crossing", order: 14, chapterGroup: 'Akt 3: Baldur’s Gate & Final' },
      { id: 'bg3-15', title: 'Investigate the Murders in the Lower City', order: 15, chapterGroup: 'Akt 3: Baldur’s Gate & Final' },
      { id: 'bg3-16', title: 'Deal with the Devil (House of Hope)', order: 16, chapterGroup: 'Akt 3: Baldur’s Gate & Final', isOptional: true },
      { id: 'bg3-17', title: "Get Gortash's Netherstone (Wyrm's Rock Fortress)", order: 17, chapterGroup: 'Akt 3: Baldur’s Gate & Final' },
      { id: 'bg3-18', title: "Get Orin's Netherstone (Temple of Bhaal)", order: 18, chapterGroup: 'Akt 3: Baldur’s Gate & Final' },
      { id: 'bg3-19', title: 'Confront the Elder Brain (The High Hall & Netherbrain)', order: 19, chapterGroup: 'Akt 3: Baldur’s Gate & Final' },
    ],
  },

  // ============================================================================
  // 12. ELDEN RING (18 huvudbossar & Legacy Dungeons 1:1)
  // ============================================================================
  {
    igdbId: 119133,
    alternateIgdbIds: [287975],
    title: 'Elden Ring',
    aliases: ['Elden Ring: Shadow of the Erdtree Edition'],
    hasLinearProgression: true,
    progressionType: 'bosses',
    summary: 'Framsteg genom Lands Between via de 18 huvudsakliga storybossarna från Margit i Stormveil till Elden Beast.',
    sourceUrl: 'https://www.ign.com/wikis/elden-ring/Walkthrough',
    items: [
      { id: 'er-1', title: 'Margit, the Fell Omen', order: 1, chapterGroup: 'Akt 1: Limgrave & Liurnia' },
      { id: 'er-2', title: 'Godrick the Grafted (Stormveil Castle)', order: 2, chapterGroup: 'Akt 1: Limgrave & Liurnia' },
      { id: 'er-3', title: 'Red Wolf of Radagon (Raya Lucaria)', order: 3, chapterGroup: 'Akt 1: Limgrave & Liurnia' },
      { id: 'er-4', title: 'Rennala, Queen of the Full Moon (Raya Lucaria)', order: 4, chapterGroup: 'Akt 1: Limgrave & Liurnia' },
      { id: 'er-5', title: 'Royal Knight Loretta (Caria Manor)', order: 5, chapterGroup: 'Akt 1: Limgrave & Liurnia', isOptional: true },
      { id: 'er-6', title: 'Starscourge Radahn (Redmane Castle)', order: 6, chapterGroup: 'Akt 2: Caelid, Altus & Leyndell' },
      { id: 'er-7', title: 'Rykard, Lord of Blasphemy (Volcano Manor)', order: 7, chapterGroup: 'Akt 2: Caelid, Altus & Leyndell', isOptional: true },
      { id: 'er-8', title: 'Draconic Tree Sentinel (Capital Outskirts)', order: 8, chapterGroup: 'Akt 2: Caelid, Altus & Leyndell' },
      { id: 'er-9', title: 'Godfrey, First Elden Lord – Golden Shade (Leyndell)', order: 9, chapterGroup: 'Akt 2: Caelid, Altus & Leyndell' },
      { id: 'er-10', title: 'Morgott, the Omen King (Leyndell)', order: 10, chapterGroup: 'Akt 2: Caelid, Altus & Leyndell' },
      { id: 'er-11', title: 'Fire Giant (Mountaintops of the Giants)', order: 11, chapterGroup: 'Akt 3: Mountaintops & Farum Azula' },
      { id: 'er-12', title: 'Godskin Duo (Crumbling Farum Azula)', order: 12, chapterGroup: 'Akt 3: Mountaintops & Farum Azula' },
      { id: 'er-13', title: 'Maliketh, the Black Blade (Crumbling Farum Azula)', order: 13, chapterGroup: 'Akt 3: Mountaintops & Farum Azula' },
      { id: 'er-14', title: 'Mohg, Lord of Blood (Mohgwyn Palace)', order: 14, chapterGroup: 'Akt 3: Mountaintops & Farum Azula', isOptional: true },
      { id: 'er-15', title: "Malenia, Blade of Miquella (Miquella's Haligtree)", order: 15, chapterGroup: 'Akt 3: Mountaintops & Farum Azula', isOptional: true },
      { id: 'er-16', title: 'Sir Gideon Ofnir, the All-Knowing (Ashen Capital)', order: 16, chapterGroup: 'Final: Leyndell, Ashen Capital' },
      { id: 'er-17', title: 'Godfrey, First Elden Lord / Hoarah Loux', order: 17, chapterGroup: 'Final: Leyndell, Ashen Capital' },
      { id: 'er-18', title: 'Radagon of the Golden Order & Elden Beast', order: 18, chapterGroup: 'Final: Leyndell, Ashen Capital' },
    ],
  },

  // ============================================================================
  // 13. THE LEGEND OF ZELDA: TEARS OF THE KINGDOM (18 Main Quests 1:1)
  // ============================================================================
  {
    igdbId: 119388,
    alternateIgdbIds: [338073],
    title: 'The Legend of Zelda: Tears of the Kingdom',
    aliases: ['Zelda: Tears of the Kingdom', 'Tears of the Kingdom'],
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Links resa genom Hyrule, himlen och The Depths i samtliga 18 officiella huvuduppdrag från Adventure Log.',
    sourceUrl: 'https://www.ign.com/wikis/the-legend-of-zelda-tears-of-the-kingdom/Walkthrough',
    items: [
      { id: 'totk-1', title: 'Prologue: Beneath Hyrule Castle', order: 1, chapterGroup: 'Prolog: Great Sky Island' },
      { id: 'totk-2', title: 'The Closed Door (Ukouh, In-isa, Gutanbac & Nachoyah Shrines)', order: 2, chapterGroup: 'Prolog: Great Sky Island' },
      { id: 'totk-3', title: 'To the Kingdom of Hyrule', order: 3, chapterGroup: 'Prolog: Great Sky Island' },
      { id: 'totk-4', title: 'Crisis at Hyrule Castle (First Visit & Paraglider)', order: 4, chapterGroup: 'Akt 1: Lookout Landing & The Depths' },
      { id: 'totk-5', title: 'Camera Work in the Depths', order: 5, chapterGroup: 'Akt 1: Lookout Landing & The Depths' },
      { id: 'totk-6', title: 'Impa and the Geoglyphs', order: 6, chapterGroup: 'Akt 1: Lookout Landing & The Depths' },
      { id: 'totk-7', title: 'A Mystery in the Depths (Autobuild)', order: 7, chapterGroup: 'Akt 1: Lookout Landing & The Depths' },
      { id: 'totk-8', title: 'Tulin of Rito Village & The Wind Temple', order: 8, chapterGroup: 'Akt 2: Regional Phenomena (De fyra templen)' },
      { id: 'totk-9', title: 'Yunobo of Goron City & The Fire Temple', order: 9, chapterGroup: 'Akt 2: Regional Phenomena (De fyra templen)' },
      { id: 'totk-10', title: 'Sidon of the Zora & The Water Temple', order: 10, chapterGroup: 'Akt 2: Regional Phenomena (De fyra templen)' },
      { id: 'totk-11', title: 'Riju of Gerudo Town & The Lightning Temple', order: 11, chapterGroup: 'Akt 2: Regional Phenomena (De fyra templen)' },
      { id: 'totk-12', title: 'Crisis at Hyrule Castle (Phantom Ganon)', order: 12, chapterGroup: 'Akt 3: Den femte vise & Master Sword' },
      { id: 'totk-13', title: 'Secret of the Ring Ruins (Kakariko Village)', order: 13, chapterGroup: 'Akt 3: Den femte vise & Master Sword' },
      { id: 'totk-14', title: 'Guidance from Ages Past & The Spirit Temple (Mineru)', order: 14, chapterGroup: 'Akt 3: Den femte vise & Master Sword' },
      { id: 'totk-15', title: "The Dragon's Tears (All 11 Geoglyphs)", order: 15, chapterGroup: 'Akt 3: Den femte vise & Master Sword' },
      { id: 'totk-16', title: "Trail of the Master Sword & Recovering the Hero's Sword", order: 16, chapterGroup: 'Akt 3: Den femte vise & Master Sword' },
      { id: 'totk-17', title: 'Find Princess Zelda', order: 17, chapterGroup: 'Final: Gloom’s Approach' },
      { id: 'totk-18', title: 'Destroy Ganondorf', order: 18, chapterGroup: 'Final: Gloom’s Approach' },
    ],
  },

  // ============================================================================
  // 14. THE LEGEND OF ZELDA: BREATH OF THE WILD (15 Main Quests 1:1)
  // ============================================================================
  {
    igdbId: 7346,
    title: 'The Legend of Zelda: Breath of the Wild',
    aliases: ['Zelda: Breath of the Wild', 'Breath of the Wild'],
    hasLinearProgression: true,
    progressionType: 'main_quests',
    summary: 'Samtliga 15 officiella huvuduppdrag i Adventure Log från Great Plateau till Calamity Ganon.',
    sourceUrl: 'https://www.ign.com/wikis/the-legend-of-zelda-breath-of-the-wild/Walkthrough',
    items: [
      { id: 'botw-1', title: 'Follow the Sheikah Slate', order: 1, chapterGroup: 'Prolog: The Great Plateau' },
      { id: 'botw-2', title: 'The Isolated Plateau', order: 2, chapterGroup: 'Prolog: The Great Plateau' },
      { id: 'botw-3', title: 'Seek Out Impa (Kakariko Village)', order: 3, chapterGroup: 'Akt 1: Kakariko & Hateno' },
      { id: 'botw-4', title: 'Locked Mementos (Hateno Ancient Tech Lab)', order: 4, chapterGroup: 'Akt 1: Kakariko & Hateno' },
      { id: 'botw-5', title: 'Find the Fairy Fountain', order: 5, chapterGroup: 'Akt 1: Kakariko & Hateno' },
      { id: 'botw-6', title: 'Reach Zora’s Domain', order: 6, chapterGroup: 'Akt 2: De fyra Divine Beasts' },
      { id: 'botw-7', title: 'Divine Beast Vah Ruta (Waterblight Ganon)', order: 7, chapterGroup: 'Akt 2: De fyra Divine Beasts' },
      { id: 'botw-8', title: 'Divine Beast Vah Rudania (Fireblight Ganon)', order: 8, chapterGroup: 'Akt 2: De fyra Divine Beasts' },
      { id: 'botw-9', title: 'Divine Beast Vah Medoh (Windblight Ganon)', order: 9, chapterGroup: 'Akt 2: De fyra Divine Beasts' },
      { id: 'botw-10', title: 'Forbidden City Entry (Gerudo Town)', order: 10, chapterGroup: 'Akt 2: De fyra Divine Beasts' },
      { id: 'botw-11', title: 'Divine Beast Vah Naboris (Thunderblight Ganon)', order: 11, chapterGroup: 'Akt 2: De fyra Divine Beasts' },
      { id: 'botw-12', title: 'Free the Divine Beasts', order: 12, chapterGroup: 'Akt 2: De fyra Divine Beasts' },
      { id: 'botw-13', title: 'Captured Memories (All 12 Memories)', order: 13, chapterGroup: 'Akt 3: Master Sword & Minnen' },
      { id: 'botw-14', title: "The Hero's Sword (The Master Sword in Korok Forest)", order: 14, chapterGroup: 'Akt 3: Master Sword & Minnen' },
      { id: 'botw-15', title: 'Destroy Ganon (Hyrule Castle)', order: 15, chapterGroup: 'Final: Hyrule Castle' },
    ],
  },

  // ============================================================================
  // 15. METAL GEAR SOLID DELTA: SNAKE EATER (18 områden & bossar 1:1)
  // ============================================================================
  {
    igdbId: 250634,
    title: 'Metal Gear Solid Delta: Snake Eater',
    aliases: ['Metal Gear Solid 3: Snake Eater', 'MGS Delta: Snake Eater'],
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Naked Snakes uppdrag i Tselinoyarsk genom samtliga 6 akter, områden och Cobra Unit-bossar enligt IGN:s walkthrough.',
    sourceUrl: 'https://www.ign.com/wikis/metal-gear-solid-delta-snake-eater/Walkthrough',
    items: [
      { id: 'mgs3-1', title: 'Dremuchij – HALO Jump & Retrieving Backpack', order: 1, chapterGroup: 'Del 1: Virtuous Mission' },
      { id: 'mgs3-2', title: 'Dolinovodno & Rassvet – Rescuing Sokolov', order: 2, chapterGroup: 'Del 1: Virtuous Mission' },
      { id: 'mgs3-3', title: 'Dolinovodno Bridge – Confrontation with The Boss', order: 3, chapterGroup: 'Del 1: Virtuous Mission' },
      { id: 'mgs3-4', title: 'Dremuchij & Rassvet – Meeting EVA & Ocelot Unit', order: 4, chapterGroup: 'Del 2: Operation Snake Eater' },
      { id: 'mgs3-5', title: 'Bolshaya Past Crevice – Duel with Major Ocelot', order: 5, chapterGroup: 'Del 2: Operation Snake Eater' },
      { id: 'mgs3-6', title: 'Chyornaya Peschera Cave – Defeat The Pain', order: 6, chapterGroup: 'Del 2: Operation Snake Eater' },
      { id: 'mgs3-7', title: 'Ponizovje & Graniny Gorki Lab – Meeting Aleksandr Granin', order: 7, chapterGroup: 'Del 3: Cobra Unit' },
      { id: 'mgs3-8', title: 'Graniny Gorki South – Defeat The Fear', order: 8, chapterGroup: 'Del 3: Cobra Unit' },
      { id: 'mgs3-9', title: 'Sokrovenno Forest – Sniper Duel with The End', order: 9, chapterGroup: 'Del 3: Cobra Unit' },
      { id: 'mgs3-10', title: 'Krasnogorje & Underground Tunnel – Defeat The Fury', order: 10, chapterGroup: 'Del 3: Cobra Unit' },
      { id: 'mgs3-11', title: 'Groznyj Grad East Wing – Disguise as Major Raikov', order: 11, chapterGroup: 'Del 4: Infiltrating Groznyj Grad' },
      { id: 'mgs3-12', title: 'Groznyj Grad Torture Room, Prison Escape & Sewers', order: 12, chapterGroup: 'Del 4: Infiltrating Groznyj Grad' },
      { id: 'mgs3-13', title: 'Tikhogornyj River – Walk Through The Sorrow', order: 13, chapterGroup: 'Del 4: Infiltrating Groznyj Grad' },
      { id: 'mgs3-14', title: 'Groznyj Grad Weapons Lab – Plant C3 & Fight Colonel Volgin', order: 14, chapterGroup: 'Del 5: Destroying the Shagohod' },
      { id: 'mgs3-15', title: 'Runway & Rail Bridge – Destroy the Shagohod & Volgin', order: 15, chapterGroup: 'Del 5: Destroying the Shagohod' },
      { id: 'mgs3-16', title: 'Lazorevo & Zaozyorje – Escorting EVA Through the Forest', order: 16, chapterGroup: 'Del 6: Escaping and Finale' },
      { id: 'mgs3-17', title: 'Rokovoj Bereg – Final Showdown with The Boss', order: 17, chapterGroup: 'Del 6: Escaping and Finale' },
      { id: 'mgs3-18', title: 'WIG Flight Duel with Ocelot & Epilogue', order: 18, chapterGroup: 'Del 6: Escaping and Finale' },
    ],
  },

  // ============================================================================
  // 16. UNCHARTED 4: A THIEF'S END (24 officiella kapitel 1:1)
  // ============================================================================
  {
    igdbId: 7331,
    title: "Uncharted 4: A Thief's End",
    aliases: ['Uncharted 4'],
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Nathan och Sam Drakes jakt på Henry Averys piratskatt genom samtliga 24 officiella kapitel från Prologue till Epilogue.',
    sourceUrl: 'https://www.ign.com/wikis/uncharted-4-a-thiefs-end/Walkthrough',
    items: [
      { id: 'u4-0', title: 'Prologue', order: 1, chapterGroup: 'Akt 1: Uppväxt, Fängelse & Auktionen' },
      { id: 'u4-1', title: 'Chapter 1: The Lure of Adventure', order: 2, chapterGroup: 'Akt 1: Uppväxt, Fängelse & Auktionen' },
      { id: 'u4-2', title: 'Chapter 2: Infernal Place', order: 3, chapterGroup: 'Akt 1: Uppväxt, Fängelse & Auktionen' },
      { id: 'u4-3', title: 'Chapter 3: The Malaysia Job', order: 4, chapterGroup: 'Akt 1: Uppväxt, Fängelse & Auktionen' },
      { id: 'u4-4', title: 'Chapter 4: A Normal Life', order: 5, chapterGroup: 'Akt 1: Uppväxt, Fängelse & Auktionen' },
      { id: 'u4-5', title: 'Chapter 5: Hector Alcazar', order: 6, chapterGroup: 'Akt 1: Uppväxt, Fängelse & Auktionen' },
      { id: 'u4-6', title: 'Chapter 6: Once a Thief', order: 7, chapterGroup: 'Akt 1: Uppväxt, Fängelse & Auktionen' },
      { id: 'u4-7', title: 'Chapter 7: Lights Out', order: 8, chapterGroup: 'Akt 1: Uppväxt, Fängelse & Auktionen' },
      { id: 'u4-8', title: 'Chapter 8: The Grave of Henry Avery', order: 9, chapterGroup: 'Akt 2: Skottland & Madagaskar' },
      { id: 'u4-9', title: 'Chapter 9: Those Who Prove Worthy', order: 10, chapterGroup: 'Akt 2: Skottland & Madagaskar' },
      { id: 'u4-10', title: 'Chapter 10: The Twelve Towers', order: 11, chapterGroup: 'Akt 2: Skottland & Madagaskar' },
      { id: 'u4-11', title: 'Chapter 11: Hidden in Plain Sight', order: 12, chapterGroup: 'Akt 2: Skottland & Madagaskar' },
      { id: 'u4-12', title: 'Chapter 12: At Sea', order: 13, chapterGroup: 'Akt 2: Skottland & Madagaskar' },
      { id: 'u4-13', title: 'Chapter 13: Marooned', order: 14, chapterGroup: 'Akt 3: Libertalia & New Devon' },
      { id: 'u4-14', title: 'Chapter 14: Join Me in Paradise', order: 15, chapterGroup: 'Akt 3: Libertalia & New Devon' },
      { id: 'u4-15', title: 'Chapter 15: The Thieves of Libertalia', order: 16, chapterGroup: 'Akt 3: Libertalia & New Devon' },
      { id: 'u4-16', title: 'Chapter 16: The Brothers Drake', order: 17, chapterGroup: 'Akt 3: Libertalia & New Devon' },
      { id: 'u4-17', title: 'Chapter 17: For Better or Worse', order: 18, chapterGroup: 'Akt 3: Libertalia & New Devon' },
      { id: 'u4-18', title: 'Chapter 18: New Devon', order: 19, chapterGroup: 'Akt 3: Libertalia & New Devon' },
      { id: 'u4-19', title: "Chapter 19: Avery's Descent", order: 20, chapterGroup: 'Akt 4: Averys Skepp & Epilog' },
      { id: 'u4-20', title: 'Chapter 20: No Escape', order: 21, chapterGroup: 'Akt 4: Averys Skepp & Epilog' },
      { id: 'u4-21', title: "Chapter 21: Brother's Keeper", order: 22, chapterGroup: 'Akt 4: Averys Skepp & Epilog' },
      { id: 'u4-22', title: "Chapter 22: A Thief's End", order: 23, chapterGroup: 'Akt 4: Averys Skepp & Epilog' },
      { id: 'u4-23', title: 'Epilogue', order: 24, chapterGroup: 'Akt 4: Averys Skepp & Epilog' },
    ],
  },

  // ============================================================================
  // 17. THE LAST OF US PART I (12 officiella kapitel 1:1 på engelska)
  // ============================================================================
  {
    igdbId: 204350,
    alternateIgdbIds: [1009],
    title: 'The Last of Us Part I',
    aliases: ['The Last of Us', 'The Last of Us Remastered'],
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Joel och Ellies resa genom ett postapokalyptiskt USA i samtliga 12 officiella kapitel genom de fyra årstiderna.',
    sourceUrl: 'https://www.ign.com/wikis/the-last-of-us-part-1/Walkthrough',
    items: [
      { id: 'tlou1-1', title: 'Prologue: Hometown', order: 1, chapterGroup: 'Summer' },
      { id: 'tlou1-2', title: 'Chapter 1: The Quarantine Zone', order: 2, chapterGroup: 'Summer' },
      { id: 'tlou1-3', title: 'Chapter 2: The Outskirts', order: 3, chapterGroup: 'Summer' },
      { id: 'tlou1-4', title: "Chapter 3: Bill's Town", order: 4, chapterGroup: 'Summer' },
      { id: 'tlou1-5', title: 'Chapter 4: Pittsburgh', order: 5, chapterGroup: 'Summer' },
      { id: 'tlou1-6', title: 'Chapter 5: The Suburbs', order: 6, chapterGroup: 'Summer' },
      { id: 'tlou1-7', title: "Chapter 6: Tommy's Dam", order: 7, chapterGroup: 'Fall' },
      { id: 'tlou1-8', title: 'Chapter 7: The University', order: 8, chapterGroup: 'Fall' },
      { id: 'tlou1-9', title: 'Chapter 8: Lakeside Resort', order: 9, chapterGroup: 'Winter' },
      { id: 'tlou1-10', title: 'Chapter 9: Bus Depot', order: 10, chapterGroup: 'Spring' },
      { id: 'tlou1-11', title: 'Chapter 10: The Firefly Lab', order: 11, chapterGroup: 'Spring' },
      { id: 'tlou1-12', title: 'Chapter 11: Jackson (Epilogue)', order: 12, chapterGroup: 'Spring' },
    ],
  },

  // ============================================================================
  // 18. THE LAST OF US PART II (46 officiella delkapitel i 11 akter 1:1)
  // ============================================================================
  {
    igdbId: 26192,
    title: 'The Last of Us Part II',
    aliases: ['The Last of Us Part 2', 'The Last of Us Part II Remastered'],
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Ellies och Abbys berättelse genom samtliga 46 officiella kapitel från Jackson och Seattle till Santa Barbara.',
    sourceUrl: 'https://www.ign.com/wikis/the-last-of-us-part-2/Walkthrough',
    items: [
      { id: 'tlou2-1', title: 'Prologue', order: 1, chapterGroup: 'Akt 1: Jackson' },
      { id: 'tlou2-2', title: 'Waking Up', order: 2, chapterGroup: 'Akt 1: Jackson' },
      { id: 'tlou2-3', title: 'The Overlook', order: 3, chapterGroup: 'Akt 1: Jackson' },
      { id: 'tlou2-4', title: 'Patrol', order: 4, chapterGroup: 'Akt 1: Jackson' },
      { id: 'tlou2-5', title: 'The Horde', order: 5, chapterGroup: 'Akt 1: Jackson' },
      { id: 'tlou2-6', title: 'The Chalet', order: 6, chapterGroup: 'Akt 1: Jackson' },
      { id: 'tlou2-7', title: 'Packing Up', order: 7, chapterGroup: 'Akt 1: Jackson' },
      { id: 'tlou2-8', title: 'The Gate', order: 8, chapterGroup: 'Akt 2: Seattle Day 1 (Ellie)' },
      { id: 'tlou2-9', title: 'Downtown', order: 9, chapterGroup: 'Akt 2: Seattle Day 1 (Ellie)' },
      { id: 'tlou2-10', title: 'Eastbrook Elementary', order: 10, chapterGroup: 'Akt 2: Seattle Day 1 (Ellie)' },
      { id: 'tlou2-11', title: 'Capitol Hill', order: 11, chapterGroup: 'Akt 2: Seattle Day 1 (Ellie)' },
      { id: 'tlou2-12', title: 'Channel 13', order: 12, chapterGroup: 'Akt 2: Seattle Day 1 (Ellie)' },
      { id: 'tlou2-13', title: 'The Tunnels', order: 13, chapterGroup: 'Akt 2: Seattle Day 1 (Ellie)' },
      { id: 'tlou2-14', title: 'The Theater', order: 14, chapterGroup: 'Akt 2: Seattle Day 1 (Ellie)' },
      { id: 'tlou2-15', title: 'The Birthday Gift', order: 15, chapterGroup: 'Akt 2: Seattle Day 1 (Ellie)' },
      { id: 'tlou2-16', title: 'Hillcrest', order: 16, chapterGroup: 'Akt 3: Seattle Day 2 (Ellie)' },
      { id: 'tlou2-17', title: 'Finding Strings', order: 17, chapterGroup: 'Akt 3: Seattle Day 2 (Ellie)' },
      { id: 'tlou2-18', title: 'The Seraphites', order: 18, chapterGroup: 'Akt 3: Seattle Day 2 (Ellie)' },
      { id: 'tlou2-19', title: "St. Mary's Hospital", order: 19, chapterGroup: 'Akt 3: Seattle Day 2 (Ellie)' },
      { id: 'tlou2-20', title: 'Road to the Aquarium', order: 20, chapterGroup: 'Akt 4: Seattle Day 3 (Ellie) & The Park' },
      { id: 'tlou2-21', title: 'The Flooded City', order: 21, chapterGroup: 'Akt 4: Seattle Day 3 (Ellie) & The Park' },
      { id: 'tlou2-22', title: 'Infiltration', order: 22, chapterGroup: 'Akt 4: Seattle Day 3 (Ellie) & The Park' },
      { id: 'tlou2-23', title: 'Tracking Lesson (The Park)', order: 23, chapterGroup: 'Akt 4: Seattle Day 3 (Ellie) & The Park' },
      { id: 'tlou2-24', title: 'The Stadium', order: 24, chapterGroup: 'Akt 5: Seattle Day 1 (Abby)' },
      { id: 'tlou2-25', title: 'On Foot', order: 25, chapterGroup: 'Akt 5: Seattle Day 1 (Abby)' },
      { id: 'tlou2-26', title: 'The Forward Base', order: 26, chapterGroup: 'Akt 5: Seattle Day 1 (Abby)' },
      { id: 'tlou2-27', title: 'The Aquarium', order: 27, chapterGroup: 'Akt 5: Seattle Day 1 (Abby)' },
      { id: 'tlou2-28', title: 'Hostile Territory', order: 28, chapterGroup: 'Akt 5: Seattle Day 1 (Abby)' },
      { id: 'tlou2-29', title: 'Winter Visit', order: 29, chapterGroup: 'Akt 5: Seattle Day 1 (Abby)' },
      { id: 'tlou2-30', title: 'The Forest', order: 30, chapterGroup: 'Akt 5: Seattle Day 1 (Abby)' },
      { id: 'tlou2-31', title: 'The Coast', order: 31, chapterGroup: 'Akt 5: Seattle Day 1 (Abby)' },
      { id: 'tlou2-32', title: 'Return to the Coast', order: 32, chapterGroup: 'Akt 5: Seattle Day 1 (Abby)' },
      { id: 'tlou2-33', title: 'The Shortcut', order: 33, chapterGroup: 'Akt 6: Seattle Day 2 (Abby)' },
      { id: 'tlou2-34', title: 'The Descent', order: 34, chapterGroup: 'Akt 6: Seattle Day 2 (Abby)' },
      { id: 'tlou2-35', title: 'Ground Zero', order: 35, chapterGroup: 'Akt 6: Seattle Day 2 (Abby)' },
      { id: 'tlou2-36', title: 'Return to the Aquarium', order: 36, chapterGroup: 'Akt 6: Seattle Day 2 (Abby)' },
      { id: 'tlou2-37', title: 'The Marina', order: 37, chapterGroup: 'Akt 7: Seattle Day 3 (Abby)' },
      { id: 'tlou2-38', title: 'The Island', order: 38, chapterGroup: 'Akt 7: Seattle Day 3 (Abby)' },
      { id: 'tlou2-39', title: 'The Escape', order: 39, chapterGroup: 'Akt 7: Seattle Day 3 (Abby)' },
      { id: 'tlou2-40', title: 'The Confrontation', order: 40, chapterGroup: 'Akt 7: Seattle Day 3 (Abby)' },
      { id: 'tlou2-41', title: 'The Farm', order: 41, chapterGroup: 'Akt 8: The Farm & Santa Barbara' },
      { id: 'tlou2-42', title: '2425 Constance', order: 42, chapterGroup: 'Akt 8: The Farm & Santa Barbara' },
      { id: 'tlou2-43', title: 'Pushing Inland', order: 43, chapterGroup: 'Akt 8: The Farm & Santa Barbara' },
      { id: 'tlou2-44', title: 'The Resort', order: 44, chapterGroup: 'Akt 8: The Farm & Santa Barbara' },
      { id: 'tlou2-45', title: 'The Beach', order: 45, chapterGroup: 'Akt 8: The Farm & Santa Barbara' },
      { id: 'tlou2-46', title: 'The Farm – Epilogue', order: 46, chapterGroup: 'Akt 8: The Farm & Santa Barbara' },
    ],
  },

  // ============================================================================
  // 19. RED DEAD REDEMPTION 2 (36 huvuduppdrag 1:1 genom Kapitel 1–6 & Epilog 1–2)
  // ============================================================================
  {
    igdbId: 25076,
    title: 'Red Dead Redemption 2',
    aliases: ['RDR2', 'Red Dead Redemption II'],
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Arthur Morgans och Van der Linde-ligans resa genom samtliga 6 kapitel och 2 epilogdelar.',
    sourceUrl: 'https://www.ign.com/wikis/red-dead-redemption-2/Walkthrough',
    items: [
      { id: 'rdr2-1', title: 'Outlaws from the West', order: 1, chapterGroup: 'Chapter 1: Colter' },
      { id: 'rdr2-2', title: 'Enter, Pursued by a Memory', order: 2, chapterGroup: 'Chapter 1: Colter' },
      { id: 'rdr2-3', title: 'Old Friends', order: 3, chapterGroup: 'Chapter 1: Colter' },
      { id: 'rdr2-4', title: 'The Aftermath of Genesis', order: 4, chapterGroup: 'Chapter 1: Colter' },
      { id: 'rdr2-5', title: 'Who the Hell is Leviticus Cornwall', order: 5, chapterGroup: 'Chapter 1: Colter' },
      { id: 'rdr2-6', title: 'Eastward Bound', order: 6, chapterGroup: 'Chapter 1: Colter' },
      { id: 'rdr2-7', title: 'Polite Society, Valentine Style', order: 7, chapterGroup: 'Chapter 2: Horseshoe Overlook' },
      { id: 'rdr2-8', title: 'Americans at Rest', order: 8, chapterGroup: 'Chapter 2: Horseshoe Overlook' },
      { id: 'rdr2-9', title: 'A Quiet Time', order: 9, chapterGroup: 'Chapter 2: Horseshoe Overlook' },
      { id: 'rdr2-10', title: 'Blessed are the Meek?', order: 10, chapterGroup: 'Chapter 2: Horseshoe Overlook' },
      { id: 'rdr2-11', title: 'Pouring Forth Oil', order: 11, chapterGroup: 'Chapter 2: Horseshoe Overlook' },
      { id: 'rdr2-12', title: 'A Fisher of Men', order: 12, chapterGroup: 'Chapter 2: Horseshoe Overlook' },
      { id: 'rdr2-13', title: 'The Sheep and the Goats', order: 13, chapterGroup: 'Chapter 2: Horseshoe Overlook' },
      { id: 'rdr2-14', title: 'A Strange Kindness', order: 14, chapterGroup: 'Chapter 2: Horseshoe Overlook' },
      { id: 'rdr2-15', title: 'The New South', order: 15, chapterGroup: 'Chapter 3: Clemens Point' },
      { id: 'rdr2-16', title: 'American Distillation', order: 16, chapterGroup: 'Chapter 3: Clemens Point' },
      { id: 'rdr2-17', title: 'Sodom? Back to Gomorrah', order: 17, chapterGroup: 'Chapter 3: Clemens Point' },
      { id: 'rdr2-18', title: 'Blessed are the Peacemakers', order: 18, chapterGroup: 'Chapter 3: Clemens Point' },
      { id: 'rdr2-19', title: 'A Short Walk in a Pretty Town', order: 19, chapterGroup: 'Chapter 3: Clemens Point' },
      { id: 'rdr2-20', title: 'Blood Feuds, Ancient and Modern', order: 20, chapterGroup: 'Chapter 3: Clemens Point' },
      { id: 'rdr2-21', title: 'The Battle of Shady Belle', order: 21, chapterGroup: 'Chapter 3: Clemens Point' },
      { id: 'rdr2-22', title: 'The Joys of Civilization', order: 22, chapterGroup: 'Chapter 4: Saint Denis' },
      { id: 'rdr2-23', title: 'Angelo Bronte, a Man of Honor', order: 23, chapterGroup: 'Chapter 4: Saint Denis' },
      { id: 'rdr2-24', title: 'The Gilded Cage', order: 24, chapterGroup: 'Chapter 4: Saint Denis' },
      { id: 'rdr2-25', title: 'Horsemen, Apocalypses', order: 25, chapterGroup: 'Chapter 4: Saint Denis' },
      { id: 'rdr2-26', title: 'Urban Pleasures', order: 26, chapterGroup: 'Chapter 4: Saint Denis' },
      { id: 'rdr2-27', title: 'Revenge is a Dish Best Eaten', order: 27, chapterGroup: 'Chapter 4: Saint Denis' },
      { id: 'rdr2-28', title: 'Banking, the Old American Art', order: 28, chapterGroup: 'Chapter 4: Saint Denis' },
      { id: 'rdr2-29', title: 'Welcome to the New World', order: 29, chapterGroup: 'Chapter 5: Guarma' },
      { id: 'rdr2-30', title: 'Hell Hath No Fury', order: 30, chapterGroup: 'Chapter 5: Guarma' },
      { id: 'rdr2-31', title: 'Paradise Mercifully Departed', order: 31, chapterGroup: 'Chapter 5: Guarma' },
      { id: 'rdr2-32', title: 'Dear Uncle Tacitus & Fleeting Joy', order: 32, chapterGroup: 'Chapter 5: Guarma' },
      { id: 'rdr2-33', title: "That's Murfree Country", order: 33, chapterGroup: 'Chapter 5: Guarma' },
      { id: 'rdr2-34', title: 'Icarus and Friends', order: 34, chapterGroup: 'Chapter 6: Beaver Hollow' },
      { id: 'rdr2-35', title: 'Visiting Hours', order: 35, chapterGroup: 'Chapter 6: Beaver Hollow' },
      { id: 'rdr2-36', title: 'Just a Social Call', order: 36, chapterGroup: 'Chapter 6: Beaver Hollow' },
      { id: 'rdr2-37', title: 'The Bridge to Nowhere', order: 37, chapterGroup: 'Chapter 6: Beaver Hollow' },
      { id: 'rdr2-38', title: 'My Last Boy', order: 38, chapterGroup: 'Chapter 6: Beaver Hollow' },
      { id: 'rdr2-39', title: 'Our Best Selves', order: 39, chapterGroup: 'Chapter 6: Beaver Hollow' },
      { id: 'rdr2-40', title: 'Red Dead Redemption', order: 40, chapterGroup: 'Chapter 6: Beaver Hollow' },
      { id: 'rdr2-41', title: 'The Wheel', order: 41, chapterGroup: 'Epilogue Part 1: Pronghorn Ranch' },
      { id: 'rdr2-42', title: 'Jim Milton Rides, Again?', order: 42, chapterGroup: 'Epilogue Part 1: Pronghorn Ranch' },
      { id: 'rdr2-43', title: 'Motherhood', order: 43, chapterGroup: 'Epilogue Part 1: Pronghorn Ranch' },
      { id: 'rdr2-44', title: 'Bare Knuckle Friendships', order: 44, chapterGroup: 'Epilogue Part 2: Beecher’s Hope' },
      { id: 'rdr2-45', title: 'A New Jerusalem', order: 45, chapterGroup: 'Epilogue Part 2: Beecher’s Hope' },
      { id: 'rdr2-46', title: 'American Venom', order: 46, chapterGroup: 'Epilogue Part 2: Beecher’s Hope' },
    ],
  },

  // ============================================================================
  // 20. RESIDENT EVIL 4 (16 officiella kapitel 1:1)
  // ============================================================================
  {
    igdbId: 196356,
    alternateIgdbIds: [960],
    title: 'Resident Evil 4',
    aliases: ['Resident Evil 4 Remake', 'Resident Evil 4 (Remake)'],
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Leons uppdrag att rädda Ashley Graham genom samtliga 16 officiella kapitel i Byn, Slottet och Ön.',
    sourceUrl: 'https://www.ign.com/wikis/resident-evil-4-remake/Walkthrough',
    items: [
      { id: 're4-1', title: "Chapter 1: The Village & Hunter's Lodge", order: 1, chapterGroup: 'The Village' },
      { id: 're4-2', title: 'Chapter 2: The Abandoned Factory & Valley', order: 2, chapterGroup: 'The Village' },
      { id: 're4-3', title: 'Chapter 3: The Lakeside & Del Lago', order: 3, chapterGroup: 'The Village' },
      { id: 're4-4', title: 'Chapter 4: Lake Exploration, Church & El Gigante', order: 4, chapterGroup: 'The Village' },
      { id: 're4-5', title: 'Chapter 5: Church Rescue & Villa Cabin Siege', order: 5, chapterGroup: 'The Village' },
      { id: 're4-6', title: 'Chapter 6: Checkpoint, Slaughterhouse & Bitores Méndez', order: 6, chapterGroup: 'The Village' },
      { id: 're4-7', title: 'Chapter 7: Castle Gates, Dungeons & Garrador', order: 7, chapterGroup: 'The Castle' },
      { id: 're4-8', title: 'Chapter 8: Castle Battlements & Water Hall', order: 8, chapterGroup: 'The Castle' },
      { id: 're4-9', title: 'Chapter 9: Courtyard Maze, Grand Hall & Armaduras', order: 9, chapterGroup: 'The Castle' },
      { id: 're4-10', title: 'Chapter 10: Depths, Antechamber & Verdugo', order: 10, chapterGroup: 'The Castle' },
      { id: 're4-11', title: 'Chapter 11: The Mines, Minecart Ride & Krauser Knife Fight', order: 11, chapterGroup: 'The Castle' },
      { id: 're4-12', title: 'Chapter 12: Clock Tower & Ramón Salazar', order: 12, chapterGroup: 'The Castle' },
      { id: 're4-13', title: 'Chapter 13: Island Wharf, Dissection Lab & Regeneradors', order: 13, chapterGroup: 'The Island' },
      { id: 're4-14', title: 'Chapter 14: Cargo Depot, Wrecking Ball & Jack Krauser Boss', order: 14, chapterGroup: 'The Island' },
      { id: 're4-15', title: 'Chapter 15: Stronghold, Cliffside Ruins & Sanctuary', order: 15, chapterGroup: 'The Island' },
      { id: 're4-16', title: 'Chapter 16: Osmund Saddler & Jet Ski Escape', order: 16, chapterGroup: 'The Island' },
    ],
  },

  // ============================================================================
  // 21. RESIDENT EVIL 2 (12 områden 1:1)
  // ============================================================================
  {
    igdbId: 19686,
    title: 'Resident Evil 2',
    aliases: ['Resident Evil 2 Remake', 'Resident Evil 2 (Remake)'],
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'Leon och Claires flykt genom R.P.D., underjorden, kloakerna och Umbrella NEST.',
    sourceUrl: 'https://www.ign.com/wikis/resident-evil-2/Walkthrough',
    items: [
      { id: 're2-1', title: 'Gas Station & Streets of Raccoon City', order: 1, chapterGroup: 'Police Station (Part 1)' },
      { id: 're2-2', title: 'Police Station 1F – East Wing & Marvin', order: 2, chapterGroup: 'Police Station (Part 1)' },
      { id: 're2-3', title: 'Police Station West Wing, Dark Room & S.T.A.R.S. Office', order: 3, chapterGroup: 'Police Station (Part 1)' },
      { id: 're2-4', title: 'Three Medallions & Secret Underground Passage', order: 4, chapterGroup: 'Police Station (Part 1)' },
      { id: 're2-5', title: 'Underground Facility & First Birkin Encounter (G-1)', order: 5, chapterGroup: 'Police Station (Part 2)' },
      { id: 're2-6', title: 'Parking Garage, Kennels & Morgue / Jail', order: 6, chapterGroup: 'Police Station (Part 2)' },
      { id: 're2-7', title: 'The Tyrant (Mr. X), Clock Tower & Escape from R.P.D.', order: 7, chapterGroup: 'Police Station (Part 2)' },
      { id: 're2-8', title: 'The Sewers – Upper & Lower Waterways (Chess Plugs)', order: 8, chapterGroup: 'The Sewers' },
      { id: 're2-9', title: 'Main Power Room & Second Birkin Encounter (G-2)', order: 9, chapterGroup: 'The Sewers' },
      { id: 're2-10', title: 'NEST Laboratory – East Area & Greenhouse (Plant 43)', order: 10, chapterGroup: 'NEST Laboratory' },
      { id: 're2-11', title: 'NEST Laboratory – West Area & Third Birkin Encounter (G-3)', order: 11, chapterGroup: 'NEST Laboratory' },
      { id: 're2-12', title: 'Self-Destruct Escape: Super Tyrant / G-4 & Train Finale', order: 12, chapterGroup: 'NEST Laboratory' },
    ],
  },

  // ============================================================================
  // 22. SUPER MARIO ODYSSEY (17 riken 1:1)
  // ============================================================================
  {
    igdbId: 26758,
    title: 'Super Mario Odyssey',
    hasLinearProgression: true,
    progressionType: 'worlds',
    summary: 'Marios och Cappys resa genom samtliga 17 riken (Kingdoms) från Cap Kingdom till Darker Side.',
    sourceUrl: 'https://www.ign.com/wikis/super-mario-odyssey/Walkthrough',
    items: [
      { id: 'smo-1', title: 'Cap Kingdom (Bonneton)', order: 1, chapterGroup: 'Huvudstory' },
      { id: 'smo-2', title: 'Cascade Kingdom (Fossil Falls)', order: 2, chapterGroup: 'Huvudstory' },
      { id: 'smo-3', title: 'Sand Kingdom (Tostarena)', order: 3, chapterGroup: 'Huvudstory' },
      { id: 'smo-4', title: 'Lake Kingdom (Lake Lamode)', order: 4, chapterGroup: 'Huvudstory' },
      { id: 'smo-5', title: 'Wooded Kingdom (Steam Gardens)', order: 5, chapterGroup: 'Huvudstory' },
      { id: 'smo-6', title: 'Cloud Kingdom (Nimbus Arena)', order: 6, chapterGroup: 'Huvudstory' },
      { id: 'smo-7', title: 'Lost Kingdom (Forgotten Isle)', order: 7, chapterGroup: 'Huvudstory' },
      { id: 'smo-8', title: 'Metro Kingdom (New Donk City)', order: 8, chapterGroup: 'Huvudstory' },
      { id: 'smo-9', title: 'Snow Kingdom (Shiveria)', order: 9, chapterGroup: 'Huvudstory' },
      { id: 'smo-10', title: 'Seaside Kingdom (Bubblaine)', order: 10, chapterGroup: 'Huvudstory' },
      { id: 'smo-11', title: 'Luncheon Kingdom (Mount Volbono)', order: 11, chapterGroup: 'Huvudstory' },
      { id: 'smo-12', title: 'Ruined Kingdom (Crumbleden)', order: 12, chapterGroup: 'Huvudstory' },
      { id: 'smo-13', title: "Bowser's Kingdom (Bowser's Castle)", order: 13, chapterGroup: 'Huvudstory' },
      { id: 'smo-14', title: 'Moon Kingdom (Honeylune Ridge)', order: 14, chapterGroup: 'Huvudstory' },
      { id: 'smo-15', title: "Mushroom Kingdom (Peach's Castle)", order: 15, chapterGroup: 'Post-game', isOptional: true },
      { id: 'smo-16', title: 'Dark Side (Rabbit Ridge)', order: 16, chapterGroup: 'Post-game', isOptional: true },
      { id: 'smo-17', title: 'Darker Side (Culmina Crater)', order: 17, chapterGroup: 'Post-game', isOptional: true },
    ],
  },

  // ============================================================================
  // 23. 007 FIRST LIGHT (12 kapitel 1:1)
  // ============================================================================
  {
    igdbId: 141114,
    title: '007 First Light',
    hasLinearProgression: true,
    progressionType: 'chapters',
    summary: 'James Bonds ursprung som agent genom prolog och samtliga 10 kapitel.',
    sourceUrl: 'https://www.ign.com/wikis/007-first-light/Walkthrough',
    items: [
      { id: '007-0', title: 'Prologue: Against All Odds (Iceland)', order: 1, chapterGroup: 'Prolog & MI6' },
      { id: '007-1', title: "In His Majesty's Secret Service (MI6)", order: 2, chapterGroup: 'Prolog & MI6' },
      { id: '007-2', title: "Chapter 1: The Needle's Eye (Malta)", order: 3, chapterGroup: 'Akt 1: Rekrytering' },
      { id: '007-3', title: 'Chapter 2: The Heart of the Matter (MI6)', order: 4, chapterGroup: 'Akt 1: Rekrytering' },
      { id: '007-4', title: 'Chapter 3: A New Home', order: 5, chapterGroup: 'Akt 1: Rekrytering' },
      { id: '007-5', title: 'Chapter 4: A Night Out (London)', order: 6, chapterGroup: 'Akt 2: Fältuppdrag' },
      { id: '007-6', title: 'Chapter 5: A Matter of Considerable Delicacy', order: 7, chapterGroup: 'Akt 2: Fältuppdrag' },
      { id: '007-7', title: 'Chapter 6: All the Time in the World (Slovakia)', order: 8, chapterGroup: 'Akt 2: Fältuppdrag' },
      { id: '007-8', title: 'Chapter 7: Out of the Ashes (Mauritania)', order: 9, chapterGroup: 'Akt 2: Fältuppdrag' },
      { id: '007-9', title: 'Chapter 8: Uninvited (London)', order: 10, chapterGroup: 'Akt 3: Slutuppgörelsen' },
      { id: '007-10', title: 'Chapter 9: Knightfall', order: 11, chapterGroup: 'Akt 3: Slutuppgörelsen' },
      { id: '007-11', title: 'Chapter 10: For England', order: 12, chapterGroup: 'Akt 3: Slutuppgörelsen' },
    ],
  },
];

export function findVerifiedWalkthrough(queryTitle?: string, igdbId?: number): VerifiedWalkthrough | null {
  if (igdbId) {
    const byId = VERIFIED_WALKTHROUGHS.find(
      (w) => w.igdbId === igdbId || (w.alternateIgdbIds && w.alternateIgdbIds.includes(igdbId))
    );
    if (byId) return byId;
  }

  if (!queryTitle) return null;
  const norm = normalizeWalkthroughTitle(queryTitle);
  if (!norm) return null;

  for (const w of VERIFIED_WALKTHROUGHS) {
    if (normalizeWalkthroughTitle(w.title) === norm) return w;
    if (w.aliases?.some((a) => normalizeWalkthroughTitle(a) === norm)) return w;
  }

  return null;
}
