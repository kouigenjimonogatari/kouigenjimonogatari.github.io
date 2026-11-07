<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0" version="2.0">
    <xsl:output method="html" encoding="UTF-8" />

    <!-- 表示の言語。ja なら NN.html、en なら NN-en.html として書き出す（scripts/prebuild.py）。
         以前は 1 つの頁を ?lang=en で切り替えていたが、URL のクエリに頼らないよう
         （Endings Principles 4.4）、言語ごとに静的な頁にした。 -->
    <xsl:param name="lang" select="'ja'"/>
    <xsl:variable name="en" select="$lang = 'en'"/>
    <xsl:variable name="vol" select="replace(tokenize(base-uri(/), '/')[last()], '\.xml$', '')"/>

    <xsl:template match="/tei:TEI">
        <html lang="{$lang}">
            <head>
                <meta charset="UTF-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
                <title>
                    <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title"/>
                </title>
                <link rel="alternate" hreflang="ja" href="https://kouigenjimonogatari.github.io/html/{$vol}.html"/>
                <link rel="alternate" hreflang="en" href="https://kouigenjimonogatari.github.io/html/{$vol}-en.html"/>
                <script type="text/javascript" src="../lib/mirador-4.3.0/mirador.min.js"></script>
                <style>
                    :root {
                        --color-primary: #2c3e50;
                        --color-accent: #8b4513;
                        --color-text: #333;
                        --color-bg: #fafafa;
                        --color-border: #e0d8cf;
                        --color-persName: #1565c0;
                        --color-placeName: #e65100;
                        --font-body: "Noto Serif JP", "Hiragino Mincho ProN", "Yu Mincho", "YuMincho", serif;
                        --font-ui: "Noto Sans JP", "Hiragino Sans", "Hiragino Kaku Gothic ProN", "Yu Gothic", "YuGothic", sans-serif;
                    }

                    *, *::before, *::after {
                        box-sizing: border-box;
                        margin: 0;
                        padding: 0;
                    }

                    html, body {
                        height: 100%;
                        font-family: var(--font-ui);
                        color: var(--color-text);
                        background: var(--color-bg);
                        display: flex;
                        flex-direction: column;
                    }

                    /* Header */
                    .site-header {
                        height: 56px;
                        background: var(--color-primary);
                        color: #fff;
                        display: flex;
                        align-items: center;
                        justify-content: space-between;
                        padding: 0 1.25rem;
                        flex-shrink: 0;
                        box-shadow: 0 2px 8px rgba(0,0,0,0.15);
                    }

                    .header-left {
                        display: flex;
                        align-items: center;
                        gap: 1rem;
                    }

                    .home-link {
                        color: rgba(255,255,255,0.8);
                        text-decoration: none;
                        display: flex;
                        align-items: center;
                        transition: color 0.2s;
                    }

                    .home-link:hover {
                        color: #fff;
                    }

                    .site-title {
                        font-family: var(--font-body);
                        font-size: 1.25rem;
                        font-weight: 600;
                        letter-spacing: 0.05em;
                    }

                    .header-actions {
                        display: flex;
                        gap: 0.5rem;
                    }

                    a.btn { text-decoration: none; }
                    .btn {
                        font-family: var(--font-ui);
                        font-size: 0.8125rem;
                        font-weight: 500;
                        padding: 0.4rem 1rem;
                        border: 1px solid rgba(255,255,255,0.3);
                        border-radius: 4px;
                        background: transparent;
                        color: #fff;
                        cursor: pointer;
                        transition: all 0.2s;
                    }

                    .btn:hover {
                        background: rgba(255,255,255,0.15);
                        border-color: rgba(255,255,255,0.5);
                    }

                    /* Main layout */
                    .main-content {
                        flex: 1;
                        display: flex;
                        min-height: 0;
                    }

                    .text-pane {
                        width: 50%;
                        border-right: 1px solid var(--color-border);
                        display: flex;
                        flex-direction: column;
                    }

                    .text-scroll {
                        flex: 1;
                        padding: 1.5rem;
                        writing-mode: vertical-rl;
                        text-orientation: upright;
                        overflow-y: auto;
                        font-family: var(--font-body);
                        font-size: 1rem;
                        line-height: 2;
                        letter-spacing: 0.05em;
                    }

                    .viewer-pane {
                        width: 50%;
                        display: flex;
                    }

                    #viewer {
                        width: 100%;
                        position: relative;
                    }

                    /* Page links */
                    .page-link {
                        color: var(--color-accent);
                        cursor: pointer;
                        text-decoration: none;
                        text-orientation: sideways;
                        display: inline;
                        font-family: var(--font-ui);
                        font-size: 0.75rem;
                        font-weight: 500;
                        padding: 0.15em 0.3em;
                        border-radius: 3px;
                        transition: all 0.2s;
                    }

                    .page-link:hover {
                        background: rgba(139, 69, 19, 0.1);
                        text-decoration: underline;
                    }

                    /* Annotations */
                    .tei-persName {
                        color: var(--color-persName);
                    }

                    .tei-placeName {
                        color: var(--color-placeName);
                    }

                    /* Waka (verse) */
                    .tei-lg {
                        display: inline;
                    }

                    .tei-l {
                        display: inline;
                    }

                    /* Waka highlight toggle */
                    .waka-hl .tei-lg {
                        background-color: rgba(139, 69, 19, 0.08);
                        border-block-end: 1px solid rgba(139, 69, 19, 0.3);
                    }

                    /* RDF link */
                    .rdf-link {
                        display: none;
                        font-size: 0.65rem;
                        text-orientation: sideways;
                        color: var(--color-accent);
                        opacity: 0.5;
                        text-decoration: none;
                        margin-inline-start: 0.2em;
                    }
                    .rdf-link:hover {
                        opacity: 1;
                    }
                    .show-rdf .rdf-link {
                        display: inline;
                    }

                    /* Page link visibility */
                    .hide-pagebreak .page-link {
                        display: none;
                    }

                    /* Settings modal items */
                    .setting-item {
                        display: flex;
                        align-items: center;
                        justify-content: space-between;
                        padding: 0.6rem 0;
                        border-bottom: 1px solid #f0f0f0;
                    }
                    .setting-item:last-child {
                        border-bottom: none;
                    }
                    .setting-label {
                        font-size: 0.9rem;
                        color: #333;
                    }
                    .setting-desc {
                        font-size: 0.75rem;
                        color: #999;
                        margin-top: 0.15rem;
                    }
                    .toggle-switch {
                        position: relative;
                        width: 44px;
                        height: 24px;
                        flex-shrink: 0;
                    }
                    .toggle-switch input {
                        opacity: 0;
                        width: 0;
                        height: 0;
                    }
                    .toggle-slider {
                        position: absolute;
                        cursor: pointer;
                        inset: 0;
                        background-color: #ccc;
                        border-radius: 24px;
                        transition: 0.3s;
                    }
                    .toggle-slider::before {
                        content: "";
                        position: absolute;
                        height: 18px;
                        width: 18px;
                        left: 3px;
                        bottom: 3px;
                        background-color: #fff;
                        border-radius: 50%;
                        transition: 0.3s;
                    }
                    .toggle-switch input:checked + .toggle-slider {
                        background-color: var(--color-accent);
                    }
                    .toggle-switch input:checked + .toggle-slider::before {
                        transform: translateX(20px);
                    }

                    /* Highlight */
                    .highlight {
                        background-color: #fff3cd;
                        border-block-end: 2px solid var(--color-accent);
                        font-weight: bold;
                    }

                    /* Modal */
                    .modal-overlay {
                        display: none;
                        position: fixed;
                        z-index: 1000;
                        left: 0;
                        top: 0;
                        width: 100%;
                        height: 100%;
                        background-color: rgba(0, 0, 0, 0.5);
                    }

                    .modal-overlay.active {
                        display: flex;
                        align-items: center;
                        justify-content: center;
                    }

                    .modal-box {
                        background-color: #fff;
                        padding: 2rem;
                        border-radius: 8px;
                        max-width: 600px;
                        width: 90%;
                        max-height: 80vh;
                        overflow-y: auto;
                        position: relative;
                        box-shadow: 0 20px 60px rgba(0,0,0,0.2);
                    }

                    .modal-header {
                        display: flex;
                        justify-content: space-between;
                        align-items: center;
                        margin-bottom: 1.25rem;
                        padding-bottom: 0.75rem;
                        border-bottom: 1px solid var(--color-border);
                    }

                    .modal-header h2 {
                        font-family: var(--font-body);
                        font-size: 1.2rem;
                        font-weight: 600;
                        color: var(--color-primary);
                    }

                    .modal-close {
                        background: none;
                        border: none;
                        font-size: 1.5rem;
                        color: #999;
                        cursor: pointer;
                        padding: 0.25rem;
                        line-height: 1;
                    }

                    .modal-close:hover {
                        color: var(--color-text);
                    }

                    .modal-body {
                        font-size: 0.875rem;
                        color: #555;
                        line-height: 1.7;
                    }

                    .modal-body p {
                        margin-bottom: 0.4rem;
                    }

                    .modal-body strong {
                        color: var(--color-primary);
                    }

                    .modal-body ul {
                        margin: 0.25rem 0 0.5rem 1.5rem;
                        list-style: disc;
                    }

                    .modal-body a {
                        color: var(--color-accent);
                        text-decoration: underline;
                    }

                    .modal-section {
                        margin-bottom: 1rem;
                    }

                    /* Footer */
                    .site-footer {
                        height: 40px;
                        background: var(--color-primary);
                        color: rgba(255,255,255,0.6);
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        font-size: 0.75rem;
                        flex-shrink: 0;
                    }
                </style>
            </head>
            <body>
                <!-- Header -->
                <header class="site-header">
                    <div class="header-left">
                        <a href="{if ($en) then '../index-en.html' else '../index.html'}" class="home-link" aria-label="{if ($en) then 'Home' else 'トップ'}">
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                            </svg>
                        </a>
                        <h1 class="site-title">
                            <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title"/>
                        </h1>
                    </div>
                    <div class="header-actions">
                        <button id="showSettingsBtn" class="btn"><xsl:value-of select="if ($en) then 'Settings' else '表示設定'"/></button>
                        <button id="showMetadataBtn" class="btn"><xsl:value-of select="if ($en) then 'Metadata' else 'メタデータ'"/></button>
                        <button id="downloadXmlBtn" class="btn">TEI/XML</button>
                        <xsl:choose>
                            <xsl:when test="$en"><a class="btn" href="{$vol}.html" hreflang="ja" lang="ja">日本語</a></xsl:when>
                            <xsl:otherwise><a class="btn" href="{$vol}-en.html" hreflang="en" lang="en">English</a></xsl:otherwise>
                        </xsl:choose>
                    </div>
                </header>

                <!-- Metadata Modal -->
                <div id="metadataModal" class="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="metadataModalTitle">
                    <div class="modal-box">
                        <div class="modal-header">
                            <h2 id="metadataModalTitle"><xsl:value-of select="if ($en) then 'Metadata' else 'メタデータ'"/></h2>
                            <button id="closeModalBtn" class="modal-close" aria-label="Close">&#xd7;</button>
                        </div>
                        <div class="modal-body">
                            <div class="modal-section">
                                <p><strong><xsl:value-of select="if ($en) then 'Author:' else '著者:'"/></strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author"/></p>
                                <p><strong><xsl:value-of select="if ($en) then 'Publisher:' else '出版社:'"/></strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:bibl/tei:publisher"/></p>
                            </div>
                            <div class="modal-section">
                                <p><strong><xsl:value-of select="if ($en) then 'Distributor:' else '配布:'"/></strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:distributor"/></p>
                                <p><strong><xsl:value-of select="if ($en) then 'Publication Date:' else '公開日:'"/></strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:date"/></p>
                            </div>
                            <div class="modal-section">
                                <p><strong><xsl:value-of select="if ($en) then 'Contributors:' else '責任者:'"/></strong></p>
                                <ul>
                                    <xsl:for-each select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:respStmt">
                                        <li><xsl:value-of select="tei:resp"/> - <xsl:value-of select="tei:name"/></li>
                                    </xsl:for-each>
                                </ul>
                            </div>
                            <div class="modal-section">
                                <p><strong><xsl:value-of select="if ($en) then 'License:' else 'ライセンス:'"/></strong>
                                    <a href="{tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:availability/tei:p/tei:ref/@target}" target="_blank">
                                        <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:availability/tei:p/tei:ref"/>
                                    </a>
                                </p>
                            </div>
                            <xsl:if test="tei:teiHeader/tei:encodingDesc/tei:p">
                                <div class="modal-section">
                                    <p><strong><xsl:value-of select="if ($en) then 'Encoding:' else 'エンコーディング:'"/></strong></p>
                                    <p><xsl:value-of select="tei:teiHeader/tei:encodingDesc/tei:p"/></p>
                                </div>
                            </xsl:if>
                            <xsl:if test="tei:teiHeader/tei:revisionDesc">
                                <div class="modal-section">
                                    <p><strong><xsl:value-of select="if ($en) then 'Revision History:' else '改訂履歴:'"/></strong></p>
                                    <ul>
                                        <xsl:for-each select="tei:teiHeader/tei:revisionDesc/tei:change">
                                            <li><xsl:value-of select="@when"/> - <xsl:value-of select="."/></li>
                                        </xsl:for-each>
                                    </ul>
                                </div>
                            </xsl:if>
                        </div>
                    </div>
                </div>

                <!-- Settings Modal -->
                <div id="settingsModal" class="modal-overlay" role="dialog" aria-modal="true" aria-labelledby="settingsModalTitle">
                    <div class="modal-box" style="max-width:420px">
                        <div class="modal-header">
                            <h2 id="settingsModalTitle"><xsl:value-of select="if ($en) then 'Display Settings' else '表示設定'"/></h2>
                            <button id="closeSettingsBtn" class="modal-close" aria-label="Close">&#xd7;</button>
                        </div>
                        <div class="modal-body">
                            <div class="setting-item">
                                <div>
                                    <div class="setting-label"><xsl:value-of select="if ($en) then 'Waka Highlight' else '和歌ハイライト'"/></div>
                                    <div class="setting-desc"><xsl:value-of select="if ($en) then 'Highlight waka (tanka) poems with a background color' else '和歌（短歌）を背景色で強調表示します'"/></div>
                                </div>
                                <label class="toggle-switch">
                                    <input type="checkbox" id="toggleWaka" />
                                    <span class="toggle-slider"></span>
                                </label>
                            </div>
                            <div class="setting-item">
                                <div>
                                    <div class="setting-label"><xsl:value-of select="if ($en) then 'Page Breaks' else 'ページ区切り'"/></div>
                                    <div class="setting-desc"><xsl:value-of select="if ($en) then 'Show page number links from the original text' else '原本のページ番号リンクを表示します'"/></div>
                                </div>
                                <label class="toggle-switch">
                                    <input type="checkbox" id="togglePagebreak" checked="checked" />
                                    <span class="toggle-slider"></span>
                                </label>
                            </div>
                            <div class="setting-item">
                                <div>
                                    <div class="setting-label"><xsl:value-of select="if ($en) then 'RDF Links' else 'RDFリンク'"/></div>
                                    <div class="setting-desc"><xsl:value-of select="if ($en) then 'Show Linked Data URI links for each line' else '各行のLinked Data URIへのリンクを表示します'"/></div>
                                </div>
                                <label class="toggle-switch">
                                    <input type="checkbox" id="toggleRdf" />
                                    <span class="toggle-slider"></span>
                                </label>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Main Content -->
                <main class="main-content">
                    <!-- Left: TEI Text -->
                    <div class="text-pane">
                        <div class="text-scroll horizontal-scroll">
                            <xsl:apply-templates select="tei:text/tei:body" />
                        </div>
                    </div>

                    <!-- Right: Mirador Viewer -->
                    <div class="viewer-pane">
                        <div id="viewer"></div>

                        <script>
                            const manifestUrl = "<xsl:value-of select="//tei:facsimile/@sameAs"></xsl:value-of>";

                            const pageToCanvasMap = {
                                <xsl:for-each select="//tei:pb">
                                    <xsl:variable name="zoneId" select="substring-after(@corresp, '#')" />
                                    <xsl:variable name="canvasUrl" select="//tei:zone[@xml:id=$zoneId]/ancestor::tei:surface/@sameAs" />
                                    "<xsl:value-of select="@n"/>": "<xsl:value-of select="$canvasUrl"/>"<xsl:if test="position() != last()">,</xsl:if>
                                </xsl:for-each>
                            };

                            const canvasToPageMap = {};
                            // 1 枚の画像に見開きの 2 頁が入っているので、画像からは前の頁を引く
                            for (const [page, canvas] of Object.entries(pageToCanvasMap)) {
                                if (!(canvas in canvasToPageMap)) canvasToPageMap[canvas] = page;
                            }

                            // 頁の位置は URL の # で表す（#p5 = 原本の 5 頁、#waka-001 = その和歌）。
                            // 以前の ?canvas= ?n= ?waka= ?corresp= ?lang=en の URL も、開いたときに # の形へ読み替える。
                            const isEn = <xsl:value-of select="if ($en) then 'true' else 'false'"/>;
                            const legacy = new URLSearchParams(window.location.search);
                            if (legacy.get('lang') === 'en' &amp;&amp; !isEn) {
                                legacy.delete('lang');
                                const rest = legacy.toString();
                                window.location.replace('<xsl:value-of select="$vol"/>-en.html' + (rest ? '?' + rest : '') + window.location.hash);
                            }
                            let hash = decodeURIComponent(window.location.hash.slice(1));
                            if (!hash) {
                                if (legacy.get('n')) {
                                    hash = 'p' + legacy.get('n');
                                } else if (legacy.get('canvas') &amp;&amp; canvasToPageMap[legacy.get('canvas')]) {
                                    hash = 'p' + canvasToPageMap[legacy.get('canvas')];
                                } else if (legacy.get('waka')) {
                                    hash = legacy.get('waka');
                                } else if (legacy.get('corresp')) {
                                    const seg = document.querySelector(`span[data-corresp="${legacy.get('corresp')}"]`);
                                    const lg = seg &amp;&amp; seg.closest('.tei-lg[id]');
                                    if (lg) hash = lg.id;
                                }
                            }
                            if (window.location.search) {
                                window.history.replaceState({}, '', window.location.pathname + (hash ? '#' + hash : ''));
                            }

                            function canvasForHash(h) {
                                const m = /^p(.+)$/.exec(h);
                                if (m &amp;&amp; pageToCanvasMap[m[1]]) return pageToCanvasMap[m[1]];
                                const el = h &amp;&amp; document.getElementById(h);
                                const seg = el &amp;&amp; el.querySelector('span[data-canvas]');
                                return seg ? seg.getAttribute('data-canvas') : null;
                            }

                            let initialCanvasId = canvasForHash(hash) || pageToCanvasMap[Object.keys(pageToCanvasMap)[0]];
                            const viewingDirection = 'right-to-left';

                            const miradorConfig = {
                                id: "viewer",
                                windows: [{
                                    id: 'known-window-id',
                                    loadedManifest: manifestUrl,
                                    viewingDirection: viewingDirection,
                                }],
                                window: {
                                    allowClose: false,
                                    allowMaximize: false,
                                    allowFullscreen: false,
                                    hideWindowTitle: true,
                                },
                                workspaceControlPanel: {
                                    enabled: false,
                                },
                            };

                            if (initialCanvasId) {
                                miradorConfig.windows[0].canvasId = initialCanvasId;
                            } else {
                                miradorConfig.windows[0].canvasIndex = 0;
                            }

                            const miradorInstance = Mirador.viewer(miradorConfig);

                            let previousCanvasId = initialCanvasId;
                            // 和歌への # で開いたときは、頁をめくるまで # を和歌のままにしておく
                            let keepHash = !/^p/.test(hash) &amp;&amp; !!hash;

                            function scrollToPbTag(canvasId) {
                                const pbTag = document.querySelector(`span[data-canvas-id='${canvasId}']`);
                                if (pbTag) {
                                    pbTag.scrollIntoView({ behavior: "smooth", block: "start" });
                                }
                            }

                            miradorInstance.store.subscribe(() => {
                                const state = miradorInstance.store.getState();
                                const currentWindow = state.windows['known-window-id'];
                                if (currentWindow.canvasId !== previousCanvasId) {
                                    previousCanvasId = currentWindow.canvasId;
                                    if (keepHash) { keepHash = false; return; }
                                    scrollToPbTag(currentWindow.canvasId);
                                    const cur = /^#p(.+)$/.exec(window.location.hash);
                                    if (cur &amp;&amp; pageToCanvasMap[cur[1]] === currentWindow.canvasId) return;
                                    const page = canvasToPageMap[currentWindow.canvasId];
                                    if (page) window.history.replaceState({}, '', '#p' + page);
                                }
                            });

                            window.addEventListener('hashchange', function() {
                                const h = decodeURIComponent(window.location.hash.slice(1));
                                const el = h &amp;&amp; document.getElementById(h);
                                if (el &amp;&amp; el.classList.contains('tei-lg')) {
                                    keepHash = true;
                                    scrollToAndHighlight(el);
                                } else {
                                    const c = canvasForHash(h);
                                    if (c) goToPage(c, /^p/.test(h) ? h.slice(1) : null);
                                }
                            });

                            function goToPage(canvasId, page) {
                                if (page) window.history.replaceState({}, '', '#p' + page);
                                try {
                                    const action = {
                                        type: 'mirador/SET_CANVAS',
                                        windowId: 'known-window-id',
                                        canvasId: canvasId,
                                        visibleCanvases: [canvasId]
                                    };
                                    miradorInstance.store.dispatch(action);
                                } catch (error) {
                                    console.error('Error navigating to canvas:', error);
                                }
                            }

                            const scrollArea = document.querySelector('.horizontal-scroll');
                            if (scrollArea) {
                                scrollArea.addEventListener('wheel', function(e) {
                                    e.preventDefault();
                                    this.scrollLeft += e.deltaY;
                                });
                            }

                            function scrollToAndHighlight(targetElement) {
                                targetElement.classList.add('highlight');
                                const scrollContainer = document.querySelector('.horizontal-scroll');
                                if (scrollContainer) {
                                    setTimeout(() => {
                                        const targetRect = targetElement.getBoundingClientRect();
                                        const containerRect = scrollContainer.getBoundingClientRect();
                                        const currentScroll = scrollContainer.scrollLeft;
                                        const targetRelativeLeft = targetRect.left - containerRect.left;
                                        const scrollPosition = currentScroll + targetRelativeLeft - (scrollContainer.clientWidth / 2) + (targetRect.width / 2);
                                        scrollContainer.scrollTo({ left: scrollPosition, behavior: 'smooth' });
                                    }, 300);
                                }
                                // Navigate Mirador to the matching canvas
                                const seg = targetElement.closest('span[data-canvas]');
                                if (seg) {
                                    const canvas = seg.getAttribute('data-canvas');
                                    if (canvas) {
                                        miradorInstance.store.dispatch({
                                            type: 'mirador/SET_CANVAS',
                                            windowId: 'known-window-id',
                                            canvasId: canvas,
                                            visibleCanvases: [canvas]
                                        });
                                    }
                                }
                            }

                            const hashEl = hash &amp;&amp; document.getElementById(hash);
                            const highlightTarget = hashEl &amp;&amp; hashEl.classList.contains('tei-lg') ? '#' + CSS.escape(hash) : null;

                            if (highlightTarget) {
                                let attempts = 0;
                                const maxAttempts = 20;

                                const tryHighlight = () => {
                                    const targetElement = document.querySelector(highlightTarget);
                                    if (targetElement) {
                                        scrollToAndHighlight(targetElement);
                                        return true;
                                    }
                                    return false;
                                };

                                const retryInterval = setInterval(() => {
                                    attempts++;
                                    if (tryHighlight() || attempts >= maxAttempts) {
                                        clearInterval(retryInterval);
                                    }
                                }, 200);
                            }

                            // --- Settings modal ---
                            const textScroll = document.querySelector('.text-scroll');

                            document.getElementById('showSettingsBtn').addEventListener('click', function() {
                                document.getElementById('settingsModal').classList.add('active');
                            });
                            document.getElementById('closeSettingsBtn').addEventListener('click', function() {
                                document.getElementById('settingsModal').classList.remove('active');
                            });
                            document.getElementById('settingsModal').addEventListener('click', function(e) {
                                if (e.target === this) this.classList.remove('active');
                            });

                            // Toggle: waka highlight
                            document.getElementById('toggleWaka').addEventListener('change', function() {
                                textScroll.classList.toggle('waka-hl', this.checked);
                                const tocPanel = document.getElementById('wakaToc');
                                if (tocPanel) tocPanel.style.display = this.checked ? 'block' : 'none';
                            });

                            // Toggle: page breaks
                            document.getElementById('togglePagebreak').addEventListener('change', function() {
                                textScroll.classList.toggle('hide-pagebreak', !this.checked);
                            });

                            // Toggle: RDF links
                            document.getElementById('toggleRdf').addEventListener('change', function() {
                                textScroll.classList.toggle('show-rdf', this.checked);
                            });

                            // Build waka TOC panel
                            const wakaList = document.querySelectorAll('.tei-lg[id]');
                            if (wakaList.length > 0) {
                                const tocPanel = document.createElement('div');
                                tocPanel.id = 'wakaToc';
                                tocPanel.style.cssText = 'display:none; position:fixed; top:50px; right:16px; z-index:500; background:#fff; border:1px solid #ccc; border-radius:8px; box-shadow:0 4px 16px rgba(0,0,0,0.15); max-height:70vh; overflow-y:auto; width:260px; font-size:0.85rem;';
                                let tocHtml = '<div style="padding:0.75rem 1rem; border-bottom:1px solid #eee; font-weight:600; display:flex; justify-content:space-between; align-items:center;">'
                                    + '<span>' + (isEn ? 'Waka List (' + wakaList.length + ' poems)' : '和歌一覧（' + wakaList.length + '首）') + '</span>'
                                    + '<button id="closeWakaToc" style="border:none; background:none; cursor:pointer; font-size:1.2rem; color:#999;">\u00d7</button>'
                                    + '</div><div style="padding:0.5rem 0;">';
                                wakaList.forEach(lg => {
                                    const text = lg.textContent.trim();
                                    const preview = text.length > 20 ? text.substring(0, 20) + '\u2026' : text;
                                    tocHtml += '<a href="#" data-waka-id="' + lg.id + '" style="display:block; padding:0.35rem 1rem; color:#333; text-decoration:none; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">' + preview + '</a>';
                                });
                                tocHtml += '</div>';
                                tocPanel.innerHTML = tocHtml;
                                document.body.appendChild(tocPanel);

                                tocPanel.addEventListener('click', function(e) {
                                    const link = e.target.closest('a[data-waka-id]');
                                    if (link) {
                                        e.preventDefault();
                                        document.querySelectorAll('.tei-lg.highlight').forEach(el => el.classList.remove('highlight'));
                                        const target = document.getElementById(link.dataset.wakaId);
                                        if (target) scrollToAndHighlight(target);
                                    }
                                });
                                document.getElementById('closeWakaToc').addEventListener('click', function() {
                                    tocPanel.style.display = 'none';
                                    document.getElementById('toggleWaka').checked = false;
                                    textScroll.classList.remove('waka-hl');
                                });
                            }

                            document.getElementById('showMetadataBtn').addEventListener('click', function() {
                                document.getElementById('metadataModal').classList.add('active');
                            });
                            document.getElementById('closeModalBtn').addEventListener('click', function() {
                                document.getElementById('metadataModal').classList.remove('active');
                            });
                            document.getElementById('metadataModal').addEventListener('click', function(e) {
                                if (e.target === this) this.classList.remove('active');
                            });

                            document.getElementById('downloadXmlBtn').addEventListener('click', function() {
                                const xmlUrl = '../tei/<xsl:value-of select="$vol"/>.xml';
                                fetch(xmlUrl)
                                    .then(response => response.text())
                                    .then(xmlContent => {
                                        const cleanedXml = xmlContent.replace(/&lt;\?xml-stylesheet[^?]*\?&gt;\s*/g, '');
                                        const blob = new Blob([cleanedXml], { type: 'application/xml' });
                                        window.location.href = URL.createObjectURL(blob);
                                    })
                                    .catch(error => {
                                        console.error(isEn ? 'XML file fetch error:' : 'XMLファイル取得エラー:', error);
                                        alert(isEn ? 'Failed to fetch the XML file.' : 'XMLファイルの取得に失敗しました。');
                                    });
                            });

                        </script>
                    </div>
                </main>

                <!-- Footer -->
                <footer class="site-footer">
                    <p>Powered by TEI, Mirador, and XSLT</p>
                </footer>
            </body>
        </html>
    </xsl:template>

    <!-- body -->
    <xsl:template match="tei:body">
        <div>
            <xsl:apply-templates select="*|text()" />
        </div>
    </xsl:template>

    <!-- lb (line break) -->
    <xsl:template match="tei:lb">
        <br/>
    </xsl:template>

    <!-- pb (page break) -->
    <xsl:template match="tei:pb">
        <xsl:variable name="zoneId" select="substring-after(@corresp, '#')" />
        <xsl:variable name="canvasUrl" select="//tei:zone[@xml:id=$zoneId]/ancestor::tei:surface/@sameAs" />
        <span class="page-link" id="p{@n}" data-canvas-id="{ $canvasUrl }">
            <xsl:attribute name="onclick">
                <xsl:text>goToPage('</xsl:text>
                <xsl:value-of select="$canvasUrl"/>
                <xsl:text>', '</xsl:text>
                <xsl:value-of select="@n"/>
                <xsl:text>')</xsl:text>
            </xsl:attribute>
            [Page <xsl:value-of select="@n" />]
        </span>
    </xsl:template>

    <!-- seg -->
    <xsl:template match="tei:seg">
        <span>
            <xsl:if test="@corresp">
                <xsl:attribute name="data-corresp">
                    <xsl:value-of select="@corresp"/>
                </xsl:attribute>
                <xsl:variable name="precedingPb" select="preceding::tei:pb[1]"/>
                <xsl:if test="$precedingPb">
                    <xsl:variable name="zoneId" select="substring-after($precedingPb/@corresp, '#')"/>
                    <xsl:variable name="zone" select="//tei:zone[@xml:id=$zoneId]"/>
                    <xsl:if test="$zone">
                        <xsl:attribute name="data-zone-id">
                            <xsl:value-of select="$zoneId"/>
                        </xsl:attribute>
                        <xsl:attribute name="data-canvas">
                            <xsl:value-of select="$zone/ancestor::tei:surface/@sameAs"/>
                        </xsl:attribute>
                        <xsl:attribute name="data-coords">
                            <xsl:value-of select="concat($zone/@ulx, ',', $zone/@uly, ',', $zone/@lrx, ',', $zone/@lry)"/>
                        </xsl:attribute>
                    </xsl:if>
                </xsl:if>
            </xsl:if>
            <xsl:apply-templates select="node()" />
            <xsl:if test="@corresp">
                <a class="rdf-link" href="{@corresp}" target="_blank" title="{@corresp}">&#x1f517;</a>
            </xsl:if>
        </span>
    </xsl:template>

    <!-- lg (verse group) -->
    <xsl:template match="tei:lg">
        <span class="tei-lg">
            <xsl:if test="@xml:id">
                <xsl:attribute name="id"><xsl:value-of select="@xml:id"/></xsl:attribute>
            </xsl:if>
            <xsl:apply-templates select="node()" />
        </span>
    </xsl:template>

    <!-- l (verse line) -->
    <xsl:template match="tei:l">
        <span class="tei-l">
            <xsl:apply-templates select="node()" />
        </span>
    </xsl:template>

    <!-- persName -->
    <xsl:template match="tei:persName">
        <span class="tei-persName">
            <xsl:apply-templates select="node()" />
        </span>
    </xsl:template>

    <!-- placeName -->
    <xsl:template match="tei:placeName">
        <span class="tei-placeName">
            <xsl:apply-templates select="node()" />
        </span>
    </xsl:template>

    <!-- Fallback for other TEI elements -->
    <xsl:template match="tei:*">
        <xsl:apply-templates select="node()" />
    </xsl:template>
</xsl:stylesheet>
