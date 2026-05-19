// Feature module extracted from monolith
function buildRow(fest) {
  const row = document.createElement('div');
  row.className = 'festival-row';

  const images = Array.isArray(fest.images) ? fest.images : [];
  const empty  = images.length === 0;
  const lineupArtists = (typeof buildEventLineupArtistsFromArchive === 'function')
    ? buildEventLineupArtistsFromArchive(fest?.info?.lineupArtists || [], fest?.info?.lineup || [])
    : [];
  const hasLineup = lineupArtists.length > 0 || (Array.isArray(fest.info.lineup) && fest.info.lineup.length > 0);
  const showOpenFolderBtn = !!fest?.dirHandle || !!fest?.backendEventId;

  // Tags
  const tags = [];
  if (fest.infoHandle) tags.push(`<span class="tag tag-json">JSON</span>`);
  if (fest.backendEventId) tags.push(`<span class="tag tag-json">DB</span>`);
  if (fest.info.canceled) tags.push(`<span class="tag tag-cancelled">CANCELLED</span>`);
  if (empty)         tags.push(`<span class="tag tag-empty">NO IMAGES</span>`);

  // Date/country for header
  const dr = formatDateRange(fest.info.startDate, fest.info.endDate);
  const nameBi = normalizeBiTextValue(
    fest.info.nameI18n ?? fest.info.name ?? fest.name ?? fest.folder,
    fest.name || fest.folder
  );
  const unifiedAddressZh = typeof formatFestivalUnifiedAddress === 'function'
    ? formatFestivalUnifiedAddress({ ...(fest.info || {}), addressLang: 'zh' })
    : String(fest.info.location || fest.location || '').trim();
  const unifiedAddressEn = typeof formatFestivalUnifiedAddress === 'function'
    ? formatFestivalUnifiedAddress({ ...(fest.info || {}), addressLang: 'en' })
    : String(fest.info.location || fest.location || '').trim();
  const hasLocZh = !!String(unifiedAddressZh || '').trim();
  const hasLocEn = !!String(unifiedAddressEn || '').trim();
  const hasLoc = hasLocZh || hasLocEn;

  // Header
  const hdr = document.createElement('div');
  hdr.className = 'fest-header';
  hdr.innerHTML = `
    <div class="fest-header-left">
      <div class="fest-title-row">
        <div class="fest-name">${renderBiTextHtml(nameBi, { fallback: fest.folder })}</div>
        ${dr ? `<div class="fest-date-badge">${escapeHtml(dr)}</div>` : '<div class="fest-date-badge" style="display:none"></div>'}
      </div>
      <div class="fest-location-stack" style="${hasLoc ? '' : 'display:none'}">
        <div class="fest-location fest-location-zh" style="${hasLocZh ? '' : 'display:none'}">${hasLocZh ? escapeHtml(unifiedAddressZh) : ''}</div>
        <div class="fest-location fest-location-en" style="${hasLocEn ? '' : 'display:none'}">${hasLocEn ? escapeHtml(unifiedAddressEn) : ''}</div>
      </div>
    </div>
    <div class="fest-header-right">
      ${tags.join('')}
      <button class="tt-trigger-btn lineup-trigger-btn" style="${hasLineup?'':'display:none'}">🎧 DJ阵容</button>
      <button class="tt-trigger-btn timetable-trigger-btn" style="${hasLineup?'':'display:none'}">🗓 TIMETABLE</button>
      ${showOpenFolderBtn ? `<button class="fest-open-btn">${fest?.backendEventId ? '打开缓存' : '打开文件夹'}</button>` : ''}
      <button class="fest-delete-btn">删除活动</button>
      <button class="fest-expand-btn" type="button" aria-expanded="false">展开详情 ▾</button>
    </div>
  `;
  row.appendChild(hdr);

  // Bind timetable button
  const lineupBtn = hdr.querySelector('.lineup-trigger-btn');
  const ttBtn = hdr.querySelector('.timetable-trigger-btn');
  if (lineupBtn) lineupBtn.onclick = (e) => { e.stopPropagation(); openEventLineupModal(fest, row); };
  if (ttBtn) ttBtn.onclick = (e) => { e.stopPropagation(); openTtModal(fest, row); };
  const openBtn = hdr.querySelector('.fest-open-btn');
  const delBtn = hdr.querySelector('.fest-delete-btn');
  const expandBtn = hdr.querySelector('.fest-expand-btn');
  delBtn.onclick = (e) => { e.stopPropagation(); deleteFestival(fest, delBtn); };

  const details = document.createElement('div');
  details.className = 'fest-details';

  const setExpanded = (expanded) => {
    row.classList.toggle('expanded', expanded);
    if (expandBtn) {
      expandBtn.setAttribute('aria-expanded', expanded ? 'true' : 'false');
      expandBtn.textContent = expanded ? '收起详情 ▴' : '展开详情 ▾';
    }
  };
  row._setExpanded = setExpanded;
  if (expandBtn) {
    expandBtn.onclick = (e) => {
      e.stopPropagation();
      setExpanded(!row.classList.contains('expanded'));
    };
  }
  setExpanded(false);

  const imageZoneCardsHtml = buildEventImageZoneCardsHtml();

  // Info panel
  const panel = document.createElement('div');
  panel.className = 'fest-info-panel';
  panel.innerHTML = `
    <div class="fest-info-view">
      <div class="event-detail-dashboard">
        <section class="info-card info-card-overview">
          <div class="info-card-title">活动概览</div>
          <div class="info-list">
            <div class="info-kv"><div class="k">状态</div><div class="v" data-view="status"></div></div>
            <div class="info-kv"><div class="k">类型</div><div class="v" data-view="eventType"></div></div>
            <div class="info-kv"><div class="k">日期</div><div class="v" data-view="dateRange"></div></div>
            <div class="info-kv"><div class="k">演出规模</div><div class="v" data-view="lineup"></div></div>
            <div class="info-kv"><div class="k">票价</div><div class="v" data-view="ticketPrice"></div></div>
            <div class="info-kv"><div class="k">币种</div><div class="v" data-view="ticketCurrency"></div></div>
            <div class="info-kv wide"><div class="k">唯一标识</div><div class="v" data-view="festivalId"></div></div>
          </div>
        </section>

        <section class="info-card info-card-location">
          <div class="info-card-title">地点信息</div>
          <div class="info-list">
            <div class="info-kv wide"><div class="k">地址（展示）</div><div class="v" data-view="location"></div></div>
            <div class="info-kv wide"><div class="k">地图定位</div><div class="v" data-view="locationPoint"></div></div>
            <div class="info-kv"><div class="k">主办方</div><div class="v" data-view="organizerName"></div></div>
          </div>
        </section>

        <section class="info-card info-card-brand">
          <div class="info-card-title">品牌关联</div>
          <div class="info-list">
            <div class="info-kv wide"><div class="k">关联 Brand</div><div class="v" data-view="wikiFestival"></div></div>
            <div class="info-kv"><div class="k">是否取消</div><div class="v" data-view="canceled"></div></div>
            <div class="info-kv wide"><div class="k">节日名称</div><div class="v" data-view="name"></div></div>
          </div>
        </section>

        <section class="info-card info-card-links">
          <div class="info-card-title">链接与票务</div>
          <div class="info-list">
            <div class="info-kv wide"><div class="k">购票链接</div><div class="v" data-view="ticketUrl"></div></div>
            <div class="info-kv wide"><div class="k">票务备注</div><div class="v" data-view="ticketNotes"></div></div>
            <div class="info-kv wide"><div class="k">官网</div><div class="v" data-view="officialWebsite"></div></div>
            <div class="info-kv wide"><div class="k">官网 / 社媒</div><div class="v" data-view="socialLinks"></div></div>
            <div class="info-kv wide"><div class="k">相关链接</div><div class="v" data-view="relatedLinks"></div></div>
          </div>
        </section>

        <section class="info-card info-card-description">
          <div class="info-card-title">描述 / 备注</div>
          <div class="info-list">
            <div class="info-kv wide"><div class="k">描述</div><div class="v" data-view="description"></div></div>
          </div>
        </section>

        <section class="info-card info-card-system">
          <div class="info-card-title">系统信息</div>
          <div class="info-list">
            <div class="info-kv wide"><div class="k">Archive ID</div><div class="v" data-view="archiveFestivalId"></div></div>
            <div class="info-kv wide"><div class="k">DB Event ID</div><div class="v" data-view="backendEventId"></div></div>
            <div class="info-kv wide"><div class="k">来源</div><div class="v" data-view="sourceInfo"></div></div>
            <div class="info-kv"><div class="k">创建时间</div><div class="v" data-view="createdAt"></div></div>
            <div class="info-kv"><div class="k">更新时间</div><div class="v" data-view="updatedAt"></div></div>
          </div>
        </section>
      </div>
    </div>
    <div class="info-actions">
      <button class="info-edit-btn">✏ 编辑信息</button>
      <button class="info-ai-btn ai-action-btn" title="从 lineup / timetable 图片中识别 DJ、日期、时间和舞台；确认后直接保存到当前活动 JSON">从图片识别时间表并保存</button>
      <button class="info-ai-poster-btn ai-action-btn" title="从海报图片中识别活动名称、日期、地点、票务等基础信息；结果会先回填到编辑区，需再手动保存">从海报识别活动信息</button>
      <button class="info-map-btn">🗺 地图定位</button>
      <span class="info-save-status"></span>
      <span class="info-json-hint">JSON: ${escapeHtml(fest.infoFilename)}</span>
    </div>
    <div class="fest-info-edit">
      <div class="event-edit-modal-head">
        <div class="event-edit-modal-title">编辑活动信息</div>
        <div class="event-edit-modal-head-actions">
          <button class="edit-btn event-edit-head-btn ai-action-btn event-edit-head-coze-btn" type="button" title="从 lineup / timetable 图片中识别 DJ、日期、时间和舞台；结果只回填到当前编辑表单，不会自动保存">识别时间表并回填表单</button>
          <button class="edit-btn event-edit-head-btn ai-action-btn event-edit-head-poster-btn" type="button" title="从海报图片中识别活动名称、日期、地点、票务等基础信息；结果只回填到当前编辑表单，不会自动保存">识别海报信息并回填表单</button>
          <button class="edit-btn save event-edit-head-btn" type="button">💾 保存并同步数据库</button>
          <button class="edit-btn cancel event-edit-head-btn" type="button">取消</button>
          <button class="event-edit-modal-close" type="button">✕ CLOSE</button>
        </div>
      </div>
      <div class="edit-grid">
        <div class="edit-field">
          <label>Festival Name (EN)</label>
          <input class="edit-input" data-field="nameEn" type="text">
        </div>
        <div class="edit-field">
          <label>Festival Name (ZH)</label>
          <input class="edit-input" data-field="nameZh" type="text">
        </div>
        <div class="edit-field event-single-translate-field">
          <button class="edit-btn translate-inline ai-action-btn" type="button" title="把当前活动名称、地点等字段翻译成中英双语；会先打开确认弹窗，不会直接保存">翻译当前活动字段</button>
        </div>
        <div class="edit-section-title full">多语言 JSON（中 / 英 / 日）</div>
        <div class="edit-field full">
          <label>多语言字段 JSON</label>
          <div class="edit-lineup-hint">复制这段 JSON 给 AI 做翻译后再粘贴回来即可。未填写的语言保持空字符串，不会自动补全。</div>
          <textarea class="edit-lineup-textarea" data-field="multiLangJson" placeholder='{"nameI18n":{"zh":"","en":"","ja":""},"cityI18n":{"zh":"","en":"","ja":""},"countryI18n":{"zh":"","en":"","ja":"","enFull":""},"detailAddressI18n":{"zh":"","en":"","ja":""},"descriptionI18n":{"zh":"","en":"","ja":""}}'></textarea>
        </div>
        <div class="edit-section-title full">共享基础层（双语）</div>
        <div class="edit-field">
          <label>City (EN)</label>
          <input class="edit-input" data-field="cityEn" type="text" placeholder="Shanghai / Phuket / Amsterdam">
        </div>
        <div class="edit-field">
          <label>城市（中文）</label>
          <input class="edit-input" data-field="cityZh" type="text" placeholder="上海 / 普吉岛 / 阿姆斯特丹">
        </div>
        <div class="edit-field">
          <label>Country (EN)</label>
          <input class="edit-input" data-field="countryEn" type="text" placeholder="China / Thailand / Netherlands">
        </div>
        <div class="edit-field">
          <label>Country (EN Full)</label>
          <input class="edit-input" data-field="countryEnFull" type="text" placeholder="People's Republic of China / Kingdom of Thailand">
        </div>
        <div class="edit-field">
          <label>国家（中文）</label>
          <input class="edit-input" data-field="countryZh" type="text" placeholder="中国 / 泰国 / 荷兰">
        </div>
        <div class="edit-section-title full">详细地址层（中英文）</div>
        <div class="edit-field full">
          <label>详细地址（中文）</label>
          <textarea class="edit-input edit-textarea event-manual-address" data-field="detailAddressZh" placeholder="普吉岛 Boat Avenue Lakefront"></textarea>
        </div>
        <div class="edit-field full">
          <label>Detailed Address (EN)</label>
          <textarea class="edit-input edit-textarea event-manual-address" data-field="detailAddressEn" placeholder="Boat Avenue Lakefront, Phuket"></textarea>
        </div>
        <div class="edit-section-title full">地图辅助层（定位点，可选地图）</div>
        <div class="edit-field full event-location-field">
          <label>定位地点（地图辅助）</label>
          <div class="event-location-provider-row">
            <span class="event-location-provider-label">地图服务</span>
            <select class="edit-input event-location-provider-select" data-field="locationProvider">
              <option value="amap">高德地图（AMap）</option>
              <option value="mapkit">Apple MapKit JS</option>
              <option value="mapbox">Mapbox</option>
              <option value="geoapify">Geoapify</option>
            </select>
          </div>
          <input class="edit-input" data-field="locationPointJson" type="hidden">
          <div class="event-location-preview empty" data-location-preview>未绑定定位地点</div>
          <div class="event-location-actions">
            <button class="edit-btn" type="button" data-action="location-composed-search">按国家/城市/场所搜索</button>
            <button class="edit-btn" type="button" data-action="location-manual-search">手动搜索地点</button>
            <button class="edit-btn" type="button" data-action="location-manual-entry">手动填写定位</button>
            <button class="edit-btn" type="button" data-action="location-reuse-from-event">复用其他 Event 地址</button>
            <button class="edit-btn" type="button" data-action="location-use-my-pos">使用我的位置</button>
            <button class="edit-btn" type="button" data-action="location-clear">清空定位</button>
          </div>
        </div>
        <div class="edit-field">
          <label>关联 Brand（搜索名称）</label>
          <input class="edit-input" data-field="wikiFestivalName" type="text" placeholder="搜索并选择现有 Brand">
          <input class="edit-input" data-field="wikiFestivalId" type="hidden">
        </div>
        <div class="edit-field">
          <label>是否取消</label>
          <select class="edit-input" data-field="canceled">
            <option value="false">未取消</option>
            <option value="true">已取消</option>
          </select>
        </div>
        <div class="edit-field">
          <label>开启状态</label>
          <select class="edit-input" data-field="status">
            <option value="upcoming">upcoming</option>
            <option value="ongoing">ongoing</option>
            <option value="ended">ended</option>
            <option value="cancelled">cancelled</option>
          </select>
        </div>
        <div class="edit-field">
          <label>活动类型</label>
          <select class="edit-input" data-field="eventType">
            <option value="festival">festival</option>
            <option value="rave">rave</option>
            <option value="concert">concert</option>
            <option value="party">party</option>
            <option value="club">club</option>
            <option value="showcase">showcase</option>
            <option value="tour">tour</option>
            <option value="other">other</option>
          </select>
        </div>
        <div class="edit-field">
          <label>Event Time Zone</label>
          <select class="edit-input" data-field="timeZone">
            <option value="Asia/Shanghai">Asia/Shanghai · 北京时间</option>
            <option value="UTC">UTC</option>
            <option value="Asia/Tokyo">Asia/Tokyo</option>
            <option value="Asia/Singapore">Asia/Singapore</option>
            <option value="Asia/Bangkok">Asia/Bangkok</option>
            <option value="Europe/Amsterdam">Europe/Amsterdam</option>
            <option value="Europe/London">Europe/London</option>
            <option value="America/Los_Angeles">America/Los_Angeles</option>
            <option value="America/New_York">America/New_York</option>
          </select>
        </div>
        <div class="edit-field">
          <label>Start Date</label>
          <input class="edit-input" data-field="startDate" type="text" placeholder="2024-10-01">
        </div>
        <div class="edit-field">
          <label>End Date</label>
          <input class="edit-input" data-field="endDate" type="text" placeholder="2024-10-03">
        </div>
        <div class="edit-field">
          <label>票价最低</label>
          <input class="edit-input" data-field="ticketPriceMin" type="text" placeholder="99.00">
        </div>
        <div class="edit-field">
          <label>票价最高</label>
          <input class="edit-input" data-field="ticketPriceMax" type="text" placeholder="399.00">
        </div>
        <div class="edit-field">
          <label>票价币种</label>
          <input class="edit-input" data-field="ticketCurrency" type="text" placeholder="CNY / USD / EUR">
        </div>
        <div class="edit-field">
          <label>购票链接</label>
          <input class="edit-input" data-field="ticketUrl" type="text" placeholder="https://tickets.example.com/...">
        </div>
      </div>
      <div class="edit-field">
        <label>票务备注</label>
        <textarea class="edit-textarea" data-field="ticketNotes" placeholder="预售时间、票档说明、实名规则等"></textarea>
      </div>
      <div class="edit-field">
        <label>官网 / 社媒链接（每行一个 URL）</label>
        <textarea class="edit-textarea" data-field="socialLinks" placeholder="https://instagram.com/..."></textarea>
      </div>
      <div class="edit-field">
        <label>Related Links（每行一个 URL）</label>
        <textarea class="edit-textarea" data-field="relatedLinks" placeholder="https://..."></textarea>
      </div>
      <div class="edit-lineup-area event-lineup-editor-area">
        <label>DJ 阵容（只保存 DJ 名单，不要求时间）</label>
        <div class="event-lineup-editor-tools">
          <input class="edit-input" data-lineup-dj-search type="text" placeholder="搜索 DJ 库，如 Martin Garrix">
          <button class="edit-btn" type="button" data-action="lineup-search-dj">搜索 DJ 库</button>
          <input class="edit-input" data-lineup-manual-name type="text" placeholder="库里没有，只填 DJ 名字">
          <button class="edit-btn" type="button" data-action="lineup-add-name">添加名字</button>
        </div>
        <div class="event-lineup-search-results" data-lineup-search-results></div>
        <div class="event-lineup-artist-list" data-lineup-artist-list></div>
        <details class="event-lineup-json-details">
          <summary>JSON 批量编辑</summary>
          <div class="edit-lineup-hint">格式：{"lineup_artists":[{"djName":"Artist Name"}]}。可视化列表会和这里同步。</div>
          <textarea class="edit-lineup-textarea" data-field="lineupArtists" placeholder='{"lineup_artists":[{"djName":"Artist Name"}]}'></textarea>
        </details>
      </div>
      <div class="edit-lineup-area">
        <label>Timetable JSON（演出时间表，可自动补阵容）</label>
        <div class="edit-lineup-hint">格式：{"lineup_info":[{"musician":"...","date":"Oct.2","time":"22:00—23:30","stage":"Main Stage"}]}。保存时间表只修改演出时间信息；DJ 阵容会保留，新增姓名可补入阵容。</div>
        <textarea class="edit-lineup-textarea" data-field="lineup" placeholder='{"lineup_info":[{"musician":"Artist Name","date":"Oct.2","time":"22:00—23:30","stage":"Main Stage"}]}'></textarea>
      </div>
      <div class="edit-image-zone-area">
        <label>🖼 图片分区上传（本地缓存 + OSS）</label>
        <div class="edit-existing-assets-area">
          <div class="edit-existing-assets-head">
            <span class="edit-existing-assets-title">已有图片管理（可切换类型）</span>
            <span class="edit-existing-assets-summary" data-existing-assets-summary>共 0 张</span>
          </div>
          <div class="edit-existing-assets-list" data-existing-assets-list></div>
        </div>
        <div class="edit-lineup-hint">分区：poster / lineup / timetable / cover / map / other。每区支持多张，自动命名为 zone、zone-2、zone-3...</div>
        <div class="edit-image-zone-grid">${imageZoneCardsHtml}</div>
      </div>
      <div class="edit-actions edit-actions-meta">
        <span class="edit-save-status"></span>
        <span class="edit-json-hint">→ ${fest.backendEventId ? `DB Event: ${escapeHtml(fest.backendEventId)}` : escapeHtml(fest.infoFilename)}</span>
      </div>
    </div>
  `;

  // Bind panel buttons
  const editBtn   = panel.querySelector('.info-edit-btn');
  const aiBtn     = panel.querySelector('.info-ai-btn');
  const posterAiBtn = panel.querySelector('.info-ai-poster-btn');
  const viewStatusEl = panel.querySelector('.info-save-status');
  const saveBtn   = panel.querySelector('.edit-btn.save');
  const editHeadCozeBtn = panel.querySelector('.event-edit-head-coze-btn');
  const editHeadPosterBtn = panel.querySelector('.event-edit-head-poster-btn');
  const translateBtn = panel.querySelector('.edit-btn.translate-inline');
  const cancelBtn = panel.querySelector('.edit-btn.cancel');
  const modalCloseBtn = panel.querySelector('.event-edit-modal-close');
  const statusEl  = panel.querySelector('.edit-save-status');

  editBtn.onclick = () => {
    setEditInputs(panel, fest.info);
    if (typeof bindEventLocationEditorActions === 'function') {
      bindEventLocationEditorActions(panel, fest);
    }
    clearExistingEventAssetDraft(panel);
    toggleInfoEdit(panel, true);
    if (typeof bindEventLineupArtistEditor === 'function') {
      bindEventLineupArtistEditor(panel, fest.info);
    }
    renderExistingEventAssetDrafts(panel, fest);
    renderEventImageZoneDrafts(panel, fest);
  };
  panel._cancelEventEdit = () => {
    toggleInfoEdit(panel, false);
    clearEventImageDraftState(panel);
    clearExistingEventAssetDraft(panel);
    renderExistingEventAssetDrafts(panel, fest);
    renderEventImageZoneDrafts(panel, fest);
    statusEl.textContent = '';
  };
  cancelBtn.onclick = panel._cancelEventEdit;
  if (modalCloseBtn) modalCloseBtn.onclick = panel._cancelEventEdit;
  if (translateBtn) {
    translateBtn.onclick = () => runSingleFestivalTranslateWithCoze(fest, panel, translateBtn, statusEl);
  }
  saveBtn.onclick = () => saveFestivalInfo(fest, panel, saveBtn, statusEl);
  if (editHeadCozeBtn) {
    editHeadCozeBtn.onclick = () => runCozeLineupRecognition(fest, panel, editHeadCozeBtn, statusEl, { applyMode: 'form' });
  }
  if (editHeadPosterBtn) {
    editHeadPosterBtn.onclick = () => runCozePosterInfoRecognition(fest, panel, editHeadPosterBtn, statusEl, { applyMode: 'form' });
  }
  aiBtn.onclick = () => runCozeLineupRecognition(fest, panel, aiBtn, viewStatusEl);
  posterAiBtn.onclick = () => runCozePosterInfoRecognition(fest, panel, posterAiBtn, viewStatusEl);
  if (openBtn) openBtn.onclick = (e) => { e.stopPropagation(); openFestivalFolder(fest, openBtn, viewStatusEl); };
  panel.addEventListener('click', (e) => {
    const toggleBtn = e.target.closest('[data-action="toggle-links"]');
    if (!toggleBtn) return;
    panel.dataset.linksExpanded = panel.dataset.linksExpanded === '1' ? '0' : '1';
    renderInfoView(panel, fest.info);
  });

  renderInfoView(panel, fest.info);
  if (typeof bindEventLocationEditorActions === 'function') {
    bindEventLocationEditorActions(panel, fest);
  }
  initEventImageUploadZones(panel, fest);
  details.appendChild(panel);

  // Images
  if (empty) {
    const no = document.createElement('div');
    no.className = 'fest-no-images';
    no.textContent = '— 该文件夹暂无图片 —';
    details.appendChild(no);
    row.appendChild(details);
    hydrateFestivalImageCacheForRow(fest, row);
    return row;
  }

  const wrap = document.createElement('div');
  wrap.className = 'img-strip-wrap';
  const imageHead = document.createElement('div');
  imageHead.className = 'img-strip-head';
  imageHead.innerHTML = `<div class="img-strip-title">活动素材</div><div class="img-strip-count">${fest.images.length} 张图片</div>`;
  const strip = document.createElement('div');
  strip.className = 'img-strip';

  const typeGroups = [];
  let lastKey = null;
  for (const img of fest.images) {
    const groupKey = normalizeEventImageZoneKey(img?.zoneKey || img?.classified?.type || 'other');
    if (groupKey !== lastKey) { typeGroups.push([]); lastKey = groupKey; }
    typeGroups[typeGroups.length-1].push(img);
  }

  typeGroups.forEach((group, gi) => {
    if (gi > 0) { const sep = document.createElement('div'); sep.className = 'strip-divider'; strip.appendChild(sep); }
    group.forEach((img, _gIdx) => {
      const cell = document.createElement('div'); cell.className = 'img-cell';
      const imgIdx = fest.images.indexOf(img);
      const initialSrc = (fest.backendEventId && rootDirHandle)
        ? EVENT_IMAGE_PLACEHOLDER_DATA_URL
        : ttToAbsoluteLocalUrl(img.url || img.remoteUrl || '');
      const el = document.createElement('img');
      el.src = initialSrc || EVENT_IMAGE_PLACEHOLDER_DATA_URL;
      el.alt = img.classified.label;
      el.loading = 'lazy';
      el.dataset.imgIdx = String(imgIdx);
      const lbl = document.createElement('div'); lbl.className = `img-label lbl-${img.classified.type}`; lbl.textContent = img.classified.label;
      cell.appendChild(el); cell.appendChild(lbl);
      cell.onclick = () => { openLightboxWithCache(fest, row, imgIdx); };
      strip.appendChild(cell);
    });
  });

  wrap.appendChild(imageHead);
  wrap.appendChild(strip);
  details.appendChild(wrap);
  row.appendChild(details);
  hydrateFestivalImageCacheForRow(fest, row);
  return row;
}
