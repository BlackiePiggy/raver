function refreshFestHeaderDisplay(rowEl, fest) {
  if (!rowEl || !fest) return;
  const titleEl = rowEl.querySelector('.fest-name');
  const locStackEl = rowEl.querySelector('.fest-location-stack');
  const locZhEl = rowEl.querySelector('.fest-location-zh');
  const locEnEl = rowEl.querySelector('.fest-location-en');
  const legacyLocEl = (!locZhEl && !locEnEl) ? rowEl.querySelector('.fest-location') : null;
  const dateEl = rowEl.querySelector('.fest-date-badge');
  const countryEl = rowEl.querySelector('.fest-country-badge');
  const statusEl = rowEl.querySelector('.fest-status-badge');
  if (titleEl) {
    const titleBi = normalizeBiTextValue(fest.info.nameI18n ?? fest.info.name ?? fest.folder, fest.folder);
    titleEl.innerHTML = renderBiTextHtml(titleBi, { fallback: fest.folder });
  }
  if (locZhEl || locEnEl || locStackEl || legacyLocEl) {
    const locationZh = typeof formatFestivalUnifiedAddress === 'function'
      ? formatFestivalUnifiedAddress({ ...(fest.info || {}), addressLang: 'zh' })
      : String(fest.info.location || '').trim();
    const locationEn = typeof formatFestivalUnifiedAddress === 'function'
      ? formatFestivalUnifiedAddress({ ...(fest.info || {}), addressLang: 'en' })
      : String(fest.info.location || '').trim();
    const hasLocZh = !!String(locationZh || '').trim();
    const hasLocEn = !!String(locationEn || '').trim();
    const hasAnyLoc = hasLocZh || hasLocEn;
    if (locZhEl) {
      locZhEl.textContent = hasLocZh ? locationZh : '';
      locZhEl.style.display = hasLocZh ? '' : 'none';
    }
    if (locEnEl) {
      locEnEl.textContent = hasLocEn ? locationEn : '';
      locEnEl.style.display = hasLocEn ? '' : 'none';
    }
    if (locStackEl) {
      locStackEl.style.display = hasAnyLoc ? '' : 'none';
    }
    if (legacyLocEl) {
      const fallbackText = typeof formatFestivalUnifiedAddress === 'function'
        ? formatFestivalUnifiedAddress(fest.info)
        : String(fest.info.location || '').trim();
      const hasFallback = !!String(fallbackText || '').trim();
      legacyLocEl.textContent = hasFallback ? fallbackText : '';
      legacyLocEl.style.display = hasFallback ? '' : 'none';
    }
  }
  if (dateEl) {
    const dr = formatDateRange(fest.info.startDate, fest.info.endDate);
    dateEl.textContent = dr; dateEl.style.display = dr ? '' : 'none';
  }
  if (countryEl) {
    countryEl.innerHTML = '';
    countryEl.style.display = 'none';
  }
  if (statusEl) {
    const canceled = !!fest.info.canceled;
    statusEl.textContent = canceled ? '已取消' : '未取消';
    statusEl.classList.toggle('cancelled', canceled);
    statusEl.classList.toggle('active', !canceled);
  }
  // Update timetable button
  const lineupBtn = rowEl.querySelector('.lineup-trigger-btn');
  if (lineupBtn) {
    const artists = buildEventLineupArtistsFromArchive(fest?.info?.lineupArtists || [], fest?.info?.lineup || []);
    const hasArtists = artists.length > 0;
    lineupBtn.style.display = hasArtists ? '' : 'none';
  }
  const ttBtn = rowEl.querySelector('.timetable-trigger-btn');
  if (ttBtn) {
    const hasLineup = Array.isArray(fest.info.lineup) && fest.info.lineup.length > 0;
    ttBtn.style.display = hasLineup ? '' : 'none';
  }
}

function renderInfoView(panelEl, info) {
  const formatMaybeDateTime = (value) => {
    const text = String(value || '').trim();
    if (!text) return '';
    const parsed = new Date(text);
    if (Number.isNaN(parsed.getTime())) return text;
    return parsed.toLocaleString();
  };
  const sv = (key, val) => {
    const el = panelEl.querySelector(`[data-view="${key}"]`);
    if (!el) return;
    if (!val) { el.innerHTML = '<span class="empty">—</span>'; return; }
    el.textContent = val;
    el.classList.remove('empty');
  };
  const nameEl = panelEl.querySelector('[data-view="name"]');
  if (nameEl) {
    nameEl.innerHTML = renderBiTextHtml(info.nameI18n ?? info.name, { compact: true, fallback: info.name || '' });
    nameEl.classList.remove('empty');
  }
  sv('festivalId', info.festivalId);
  const locationEl = panelEl.querySelector('[data-view="location"]');
  if (locationEl) {
    const locationText = typeof formatFestivalUnifiedAddress === 'function'
      ? formatFestivalUnifiedAddress(info)
      : String(info.location || '').trim();
    if (!locationText) {
      locationEl.innerHTML = '<span class="empty">—</span>';
    } else {
      locationEl.textContent = locationText;
      locationEl.classList.remove('empty');
    }
  }
  const countryEl = panelEl.querySelector('[data-view="country"]');
  if (countryEl) {
    countryEl.innerHTML = '<span class="empty">—</span>';
  }
  if (typeof renderEventLocationInfoView === 'function') {
    renderEventLocationInfoView(panelEl, info);
  }
  const brandEl = panelEl.querySelector('[data-view="wikiFestival"]');
  if (brandEl) {
    const brand = info.wikiFestival && typeof info.wikiFestival === 'object' ? info.wikiFestival : null;
    if (brand && String(brand.id || '').trim()) {
      const nameHtml = renderBiTextHtml(brand.nameI18n ?? brand.name, { compact: true, fallback: brand.name || brand.id });
      const metaCountry = normalizeCountryBiTextValue(brand.countryI18n ?? brand.country, brand.country || '');
      const metaCity = normalizeBiTextValue(brand.cityI18n ?? brand.city, brand.city || '');
      const meta = [renderBiTextHtml(metaCity, { compact: true }), renderBiTextHtml(metaCountry, { compact: true })]
        .filter(Boolean)
        .join(' · ');
      const idPart = `<span style="opacity:.65">(${escapeHtml(brand.id)})</span>`;
      brandEl.innerHTML = `${nameHtml} ${idPart}${meta ? `<div class="sub">${meta}</div>` : ''}`;
      brandEl.classList.remove('empty');
    } else if (String(info.wikiFestivalId || '').trim()) {
      brandEl.innerHTML = `<span>${escapeHtml(String(info.wikiFestivalId))}</span>`;
      brandEl.classList.remove('empty');
    } else {
      brandEl.innerHTML = '<span class="empty">—</span>';
    }
  }
  const canceledEl = panelEl.querySelector('[data-view="canceled"]');
  if (canceledEl) {
    const canceled = !!info.canceled;
    canceledEl.textContent = canceled ? '已取消' : '未取消';
    canceledEl.classList.remove('empty');
    canceledEl.style.color = canceled ? '#ff9ac2' : 'var(--accent)';
  }
  sv('dateRange', formatDateRange(info.startDate, info.endDate));
  sv('status', info.status || (info.canceled ? 'cancelled' : 'upcoming'));
  sv('eventType', info.eventType);
  const tierRows = Array.isArray(info.ticketTiers) ? info.ticketTiers : [];
  const tierPrices = tierRows
    .map((tier) => normalizeTicketPriceValue(tier?.price))
    .filter((value) => value !== null);
  let ticketPriceMin = normalizeTicketPriceValue(info.ticketPriceMin);
  let ticketPriceMax = normalizeTicketPriceValue(info.ticketPriceMax);
  if (ticketPriceMin === null && tierPrices.length) ticketPriceMin = Math.min(...tierPrices);
  if (ticketPriceMax === null && tierPrices.length) ticketPriceMax = Math.max(...tierPrices);
  let ticketCurrency = String(info.ticketCurrency || '').trim().toUpperCase();
  if (!ticketCurrency) {
    const currencyFromTier = tierRows
      .map((tier) => String(tier?.currency || '').trim().toUpperCase())
      .find(Boolean);
    ticketCurrency = currencyFromTier || '';
  }
  let ticketPriceText = '';
  const currencyPrefix = ticketCurrency ? `${ticketCurrency} ` : '';
  if (ticketPriceMin !== null && ticketPriceMax !== null) {
    if (ticketPriceMin === ticketPriceMax) {
      ticketPriceText = `${currencyPrefix}${formatTicketPriceNumber(ticketPriceMin)}`;
    } else {
      ticketPriceText = `${currencyPrefix}${formatTicketPriceNumber(ticketPriceMin)} - ${formatTicketPriceNumber(ticketPriceMax)}`;
    }
  } else if (ticketPriceMin !== null) {
    ticketPriceText = `${currencyPrefix}${formatTicketPriceNumber(ticketPriceMin)}+`;
  } else if (ticketPriceMax !== null) {
    ticketPriceText = `${currencyPrefix}${formatTicketPriceNumber(ticketPriceMax)}`;
  } else if (tierRows.length) {
    ticketPriceText = `${tierRows.length} 档票价`;
  }
  sv('ticketPrice', ticketPriceText);
  sv('ticketCurrency', ticketCurrency);
  sv('organizerName', info.organizerName);
  sv('archiveFestivalId', info.archiveFestivalId);
  sv('backendEventId', info.backendEventId);
  const sourceInfoParts = [];
  const sourceProvider = String(info?.source?.provider || '').trim();
  const sourceUrl = String(info?.source?.eventUrl || '').trim();
  if (sourceProvider) sourceInfoParts.push(sourceProvider);
  if (sourceUrl) sourceInfoParts.push(sourceUrl);
  sv('sourceInfo', sourceInfoParts.join(' · '));
  sv('createdAt', formatMaybeDateTime(info.createdAt));
  sv('updatedAt', formatMaybeDateTime(info.updatedAt));

  const officialEl = panelEl.querySelector('[data-view="officialWebsite"]');
  if (officialEl) {
    const website = String(info.officialWebsite || '').trim();
    if (!website) {
      officialEl.innerHTML = '<span class="empty">—</span>';
    } else {
      officialEl.innerHTML = `<a href="${escapeHtml(website)}" target="_blank" rel="noreferrer">${escapeHtml(website)}</a>`;
      officialEl.classList.remove('empty');
    }
  }

  const ticketUrlEl = panelEl.querySelector('[data-view="ticketUrl"]');
  if (ticketUrlEl) {
    const ticketUrl = String(info.ticketUrl || '').trim();
    if (!ticketUrl) {
      ticketUrlEl.innerHTML = '<span class="empty">—</span>';
    } else {
      ticketUrlEl.innerHTML = `<a href="${escapeHtml(ticketUrl)}" target="_blank" rel="noreferrer">${escapeHtml(ticketUrl)}</a>`;
      ticketUrlEl.classList.remove('empty');
    }
  }
  sv('ticketNotes', info.ticketNotes);

  const socialEl = panelEl.querySelector('[data-view="socialLinks"]');
  if (socialEl) {
    const socials = normalizeSocialLinks(info.socialLinks || []);
    if (!socials.length) {
      socialEl.innerHTML = '<span class="empty">—</span>';
      socialEl.classList.remove('social-icons');
    } else {
      socialEl.innerHTML = socials.map(s => {
        const icon = socialIconForType(s.type);
        const title = escapeHtml((s.label || s.type || 'link').toUpperCase());
        return `<a class="social-link-icon" href="${escapeHtml(s.url)}" target="_blank" rel="noreferrer" title="${title}">${icon}</a>`;
      }).join('');
      socialEl.classList.add('social-icons');
    }
  }

  const linksEl = panelEl.querySelector('[data-view="relatedLinks"]');
  if (linksEl) {
    const links = Array.isArray(info.relatedLinks) ? info.relatedLinks : [];
    if (!links.length) {
      panelEl.dataset.linksExpanded = '0';
      linksEl.innerHTML = '<span class="empty">—</span>';
    } else {
      const defaultLimit = 3;
      const hasMore = links.length > defaultLimit;
      const expanded = hasMore && panelEl.dataset.linksExpanded === '1';
      const visible = expanded ? links : links.slice(0, defaultLimit);
      const lines = visible.map(link => `<a href="${escapeHtml(link)}" target="_blank" rel="noreferrer">${escapeHtml(link)}</a>`);
      let html = `<div class="related-links-wrap">${lines.join('')}</div>`;
      if (hasMore) {
        const remain = links.length - defaultLimit;
        const label = expanded ? '收起链接' : `展开剩余 ${remain} 条`;
        html += `<button class="links-expand-btn" data-action="toggle-links">${label}</button>`;
      } else {
        panelEl.dataset.linksExpanded = '0';
      }
      linksEl.innerHTML = html;
    }
  }

  const lineupEl = panelEl.querySelector('[data-view="lineup"]');
  if (lineupEl) {
    const lu = Array.isArray(info.lineup) ? info.lineup : [];
    const artists = buildEventLineupArtistsFromArchive(info.lineupArtists || [], lu);
    if (!lu.length && !artists.length) {
      lineupEl.innerHTML = '<span class="empty">—</span>';
    } else {
      lineupEl.textContent = `${artists.length} 个 DJ / ${lu.length} 个演出`;
    }
  }

  const descriptionEl = panelEl.querySelector('[data-view="description"]');
  if (descriptionEl) {
    const descriptionBi = normalizeBiTextValue(info.descriptionI18n ?? info.description, info.description || '');
    const hasDescription = String(descriptionBi.en || '').trim() || String(descriptionBi.zh || '').trim();
    if (!hasDescription) {
      descriptionEl.innerHTML = '<span class="empty">—</span>';
    } else {
      descriptionEl.innerHTML = renderBiTextHtml(descriptionBi, { compact: false, fallback: info.description || '' });
      descriptionEl.classList.remove('empty');
    }
  }
}
