-- InsertGenres: 12 new genre nodes for unmatched-label coverage
-- Includes full detail fields: description, example, spotify/wikipedia URLs, keyArtists, origin, era, bpm

INSERT INTO "genres" (
  "id", "name", "slug", "path", "parent_id", "sort_order",
  "description", "example", "spotify_track_url", "wikipedia_url",
  "key_artists", "origin", "era", "bpm",
  "created_at", "updated_at"
)
VALUES
  -- 1. Melodic House
  (
    'house/melodic-house', 'Melodic House', 'house-melodic-house',
    'Electronic Music/house/house-melodic-house', 'house', 20,
    'Melodic House is a subgenre of house music that emphasizes lush melodies, atmospheric pads, and emotive chord progressions over a steady four-on-the-floor rhythm. It bridges the gap between deep house and progressive house, often featuring long builds, subtle drops, and a warm, hypnotic feel suited for both clubs and open-air events.',
    'Lane 8 - Brightest Lights (feat. POLICA)',
    'https://open.spotify.com/track/0V2M3SKHgrPkJMYMnVxrrv',
    NULL,
    ARRAY['Lane 8', 'Ben Böhmer', 'Yotto'],
    'Northern Europe', '2010s', '118-125',
    NOW(), NOW()
  ),

  -- 2. Future House
  (
    'house/electro-house/future-house', 'Future House', 'house-electro-house-future-house',
    'Electronic Music/house/house-electro-house/house-electro-house-future-house', 'house/electro-house', 10,
    'Future House is a subgenre of house music that emerged in the mid-2010s, characterized by its metallic, pitched-down vocal chops, wobbly bass synths, and bright, polished production. Pioneered by artists like Oliver Heldens and Tchami, it blends elements of deep house and UK garage with EDM energy, creating a sound that is both club-ready and radio-friendly.',
    'Oliver Heldens - Gecko (Overdrive) [feat. Becky Hill]',
    'https://open.spotify.com/track/3eplkMSRMGKHritPmigHvo',
    'https://en.wikipedia.org/wiki/Future_house',
    ARRAY['Oliver Heldens', 'Tchami', 'Don Diablo'],
    'Netherlands', '2010s', '124-130',
    NOW(), NOW()
  ),

  -- 3. Bass House
  (
    'house/bass-house', 'Bass House', 'house-bass-house',
    'Electronic Music/house/house-bass-house', 'house', 21,
    'Bass House is an energetic subgenre of house music that combines the four-on-the-floor groove of house with heavy, distorted basslines influenced by dubstep and UK bass music. Characterized by its wobbly, growling bass synths, punchy drums, and festival-ready energy, it emerged in the mid-2010s as a crossover between bass music and house.',
    'Jauz - Feel The Volume',
    'https://open.spotify.com/track/7iELEcNf1VuAVVpuyvIeWk',
    NULL,
    ARRAY['Jauz', 'Habstrakt', 'AC Slater'],
    'United Kingdom / United States', '2010s', '125-132',
    NOW(), NOW()
  ),

  -- 4. Organic House
  (
    'house/deep-house/organic-house', 'Organic House', 'house-deep-house-organic-house',
    'Electronic Music/house/house-deep-house/house-deep-house-organic-house', 'house/deep-house', 10,
    'Organic House is a subgenre of deep house that incorporates natural, acoustic, and world-music elements into electronic production. It features warm pads, tribal percussion, ethnic instruments, and nature-inspired textures layered over gentle, groovy rhythms. The genre creates an earthy, meditative atmosphere suited for sunset sessions and outdoor gatherings.',
    'Bedouin - Set The Controls For The Heart Of The Sun',
    'https://open.spotify.com/track/1dNnMJIT69PAB8fVMPQiSu',
    NULL,
    ARRAY['Viken Arman', 'Audiofly', 'Bedouin'],
    'Global / Middle East & Mediterranean', '2010s', '115-122',
    NOW(), NOW()
  ),

  -- 5. G-House
  (
    'house/tech-house/g-house', 'G-House', 'house-tech-house-g-house',
    'Electronic Music/house/house-tech-house/house-tech-house-g-house', 'house/tech-house', 10,
    'G-House (Gangsta House or Ghetto House) is a subgenre of house music that blends deep, bass-heavy house beats with hip-hop vocals, gangsta rap aesthetics, and dark, minimalistic production. Originating from the underground scenes of Lyon and Chicago, it features pitched-down vocal samples, heavy sub-bass, and gritty, street-influenced textures.',
    'Malaa - Notorious',
    'https://open.spotify.com/track/4VNDOgXkBzLIyDOhPasGkP',
    NULL,
    ARRAY['Malaa', 'DJ Snake', 'Tchami'],
    'France / Lyon', '2010s', '123-130',
    NOW(), NOW()
  ),

  -- 6. UK House
  (
    'house/uk-house', 'UK House', 'house-uk-house',
    'Electronic Music/house/house-uk-house', 'house', 22,
    'UK House encompasses a range of house music styles originating from the United Kingdom, blending elements of UK garage, funky house, and deep house with distinctly British sensibilities. It often features shuffling rhythms, chopped vocal samples, and a polished yet gritty production aesthetic that reflects the UK''s diverse club culture.',
    'Disclosure - Latch (feat. Sam Smith)',
    'https://open.spotify.com/track/4VrWlk8IQxevMvERoX08iC',
    NULL,
    ARRAY['Disclosure', 'Chris Lorenzo', 'James Hype'],
    'United Kingdom', '2010s', '120-130',
    NOW(), NOW()
  ),

  -- 7. Hard Dance
  (
    'techno/hard-techno/hard-dance', 'Hard Dance', 'techno-hard-techno-hard-dance',
    'Electronic Music/techno/techno-hard-techno/techno-hard-techno-hard-dance', 'techno/hard-techno', 10,
    'Hard Dance is a broad umbrella term for high-energy electronic dance music styles that blend elements of hard techno, hardstyle, and trance with fast tempos (typically 150+ BPM) and aggressive, pounding kicks. It encompasses various energetic subgenres designed for peak-time festival and rave environments.',
    'Brennan Heart & Jonathan Mendelsohn - Imaginary',
    'https://open.spotify.com/track/2bPGTMB5sFfFYQ2YvSmup0',
    NULL,
    ARRAY['Showtek', 'Brennan Heart', 'W&W'],
    'Netherlands', '2000s', '150-160',
    NOW(), NOW()
  ),

  -- 8. Progressive Techno
  (
    'techno/progressive-techno', 'Progressive Techno', 'techno-progressive-techno',
    'Electronic Music/techno/techno-progressive-techno', 'techno', 15,
    'Progressive Techno blends the structural approach of progressive house — long builds, layered arrangements, and gradual evolution — with the darker, more industrial textures of techno. It features hypnotic loops, subtle melodic elements, and a driving yet contemplative energy, typically operating between 120–130 BPM.',
    'Stephan Bodzin - Singularity',
    'https://open.spotify.com/track/3F5ytV1Tj387VZu2dKjsKs',
    NULL,
    ARRAY['Stephan Bodzin', 'Maceo Plex', 'Dosem'],
    'Germany / Berlin', '2010s', '120-130',
    NOW(), NOW()
  ),

  -- 9. Melodic Bass
  (
    'bass-music/future-bass/melodic-bass', 'Melodic Bass', 'bass-music-future-bass-melodic-bass',
    'Electronic Music/bass-music/bass-music-future-bass/bass-music-future-bass-melodic-bass', 'bass-music/future-bass', 5,
    'Melodic Bass is a subgenre of bass music that combines heavy, cinematic bass drops with emotional melodies, soaring synths, and often ethereal vocals. It draws from future bass, dubstep, and trance, creating an uplifting yet powerful sound that has become a staple of festival culture, particularly in the North American EDM scene.',
    'ILLENIUM - Crawl Outta Love (feat. Annika Wells)',
    NULL,
    NULL,
    ARRAY['Illenium', 'Said The Sky', 'Seven Lions'],
    'United States / Colorado', '2010s', '130-150',
    NOW(), NOW()
  ),

  -- 10. Indie Dance
  (
    'pop-and-rock-fusion/electronic-rock/indie-dance', 'Indie Dance', 'pop-and-rock-fusion-electronic-rock-indie-dance',
    'Electronic Music/pop-and-rock-fusion/pop-and-rock-fusion-electronic-rock/pop-and-rock-fusion-electronic-rock-indie-dance', 'pop-and-rock-fusion/electronic-rock', 10,
    'Indie Dance is a genre that blends the aesthetic sensibilities and instrumentation of indie rock with electronic dance music production. It features organic guitar textures, live-sounding drums, and warm analog synths over danceable grooves, creating a sound that bridges alternative clubs and electronic dancefloors. The genre emerged from the post-punk and new wave revival of the 2000s.',
    'Hercules and Love Affair - Blind (feat. Antony Hegarty)',
    NULL,
    NULL,
    ARRAY['Hercules and Love Affair', 'Hot Chip', 'LCD Soundsystem'],
    'New York / London', '2000s', '110-125',
    NOW(), NOW()
  ),

  -- 11. Neo Rave
  (
    'breakbeat/neo-rave', 'Neo Rave', 'breakbeat-neo-rave',
    'Electronic Music/breakbeat/breakbeat-neo-rave', 'breakbeat', 15,
    'Neo Rave is a contemporary electronic music movement that revives and reinterprets the sounds, aesthetics, and energy of 1990s rave culture. It combines elements of acid techno, breakbeat, gabber, and trance with modern production techniques, often featuring distorted synths, pounding kicks, and an unapologetically high-energy, punk-influenced attitude. The genre has seen a resurgence in underground European club culture since the late 2010s.',
    'Brutalismus 3000 - Ultraviolett',
    'https://open.spotify.com/track/2r5YGoJSTU1Int8IsIZcCO',
    NULL,
    ARRAY['Brutalismus 3000', 'Schrotthagen', 'T78'],
    'Berlin, Germany', '2020s', '145-160',
    NOW(), NOW()
  ),

  -- 12. Future Rave
  (
    'trance/future-rave', 'Future Rave', 'trance-future-rave',
    'Electronic Music/trance/trance-future-rave', 'trance', 15,
    'Future Rave is a subgenre of electronic dance music that blends elements of big room house, trance, and techno with rave-inspired synths and driving basslines. Popularized by David Guetta and MORTEN, it features euphoric melodies, distorted lead synths, and high-energy drops designed for festival main stages. The genre draws on nostalgic rave aesthetics while incorporating modern production techniques.',
    'David Guetta & MORTEN - Kill Me Slow',
    NULL,
    NULL,
    ARRAY['David Guetta', 'MORTEN', 'Maddix'],
    'France / Denmark', '2020s', '126-132',
    NOW(), NOW()
  )
ON CONFLICT ("id") DO NOTHING;
