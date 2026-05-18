async function scanRoot(rootHandle) {
  for await (const [name, handle] of rootHandle.entries()) {
    if (handle.kind !== 'directory') continue;
    if (!/^\d{4}$/.test(name)) continue;
    const year = parseInt(name);
    setLoadingDetail(`扫描 ${year}...`);
    await scanYear(handle, year);
  }
}

async function scanYear(yearHandle, year) {
  for await (const [name, handle] of yearHandle.entries()) {
    if (handle.kind !== 'directory') continue;
    if (name === 'downloads') continue;
    const parsed = parseFolderName(name);
    if (!parsed) continue;

    setLoadingDetail(`${year} / ${name}`);
    if (!allData[year]) allData[year] = {};
    if (!allData[year][parsed.month]) allData[year][parsed.month] = [];

    const fest = {
      folder: name, year, month: parsed.month,
      name: parsed.festName, location: parsed.location,
      images: [],
      yearHandle,
      dirHandle: handle,
      infoHandle: null,
      infoFilename: DEFAULT_INFO_FILENAME,
      info: {
        name: parsed.festName,
        nameI18n: { en: parsed.festName, zh: parsed.festName },
        location: parsed.location,
        locationI18n: { en: parsed.location, zh: parsed.location },
        country: '',
        countryI18n: { en: '', zh: '' },
        canceled: false,
        startDate: `${year}-${String(parsed.month).padStart(2,'0')}-01`,
        endDate: `${year}-${String(parsed.month).padStart(2,'0')}-01`,
        relatedLinks: [],
        socialLinks: [],
        lineup: [],
        festivalId: buildFestivalId(`${year}-${String(parsed.month).padStart(2,'0')}-01`, parsed.festName, ''),
        source: {}
      }
    };

    for await (const [fname, fhandle] of handle.entries()) {
      if (fhandle.kind !== 'file') continue;
      if (isImage(fname)) {
        const file = await fhandle.getFile();
        const url = URL.createObjectURL(file);
        const classified = classifyImage(fname);
        fest.images.push({ file, url, filename: fname, classified });
        continue;
      }
      if (/\.json$/i.test(fname)) {
        const file = await fhandle.getFile();
        try {
          const txt = await file.text();
          const parsedInfo = JSON.parse(txt);
          if (parsedInfo && typeof parsedInfo === 'object') {
            fest.info = normalizeFestivalInfo(parsedInfo, fest.info);
            fest.infoHandle = fhandle;
            fest.infoFilename = fname;
          }
        } catch (_) {}
      }
    }

    fest.images.sort((a,b) =>
      a.classified.order !== b.classified.order
        ? a.classified.order - b.classified.order
        : a.classified.sort - b.classified.sort
    );
    allData[year][parsed.month].push(fest);
  }

  if (allData[year]) {
    for (const mo of Object.values(allData[year])) {
      mo.sort((a,b) => a.folder.localeCompare(b.folder));
    }
  }
}

function setLoadingDetail(text) {
  document.getElementById('loading-detail').textContent = text;
}

