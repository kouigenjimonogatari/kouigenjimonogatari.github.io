<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0" version="2.0">
    <xsl:output method="html" encoding="UTF-8" />

    <xsl:template match="/tei:TEI">
        <html lang="ja">
            <head>
                <meta charset="UTF-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
                <title>
                    <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title"/>
                </title>
                <link rel="preconnect" href="https://fonts.googleapis.com"/>
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin=""/>
                <link href="https://fonts.googleapis.com/css2?family=Noto+Serif+JP:wght@400;600;700&amp;family=Noto+Sans+JP:wght@400;500;600&amp;display=swap" rel="stylesheet"/>
                <script type="text/javascript" src="https://unpkg.com/mirador@latest/dist/mirador.min.js"></script>
                <style>
                    :root {
                        --color-primary: #2c3e50;
                        --color-accent: #8b4513;
                        --color-text: #333;
                        --color-bg: #fafafa;
                        --color-border: #e0d8cf;
                        --color-persName: #1565c0;
                        --color-placeName: #e65100;
                        --font-body: "Noto Serif JP", "Yu Mincho", "YuMincho", serif;
                        --font-ui: "Noto Sans JP", "Yu Gothic", "YuGothic", sans-serif;
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
                        <a href="../../" class="home-link">
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                            </svg>
                        </a>
                        <h1 class="site-title">
                            <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title"/>
                        </h1>
                    </div>
                    <div class="header-actions">
                        <button id="showSettingsBtn" class="btn">表示設定</button>
                        <button id="showMetadataBtn" class="btn">メタデータ</button>
                        <button id="downloadXmlBtn" class="btn">TEI/XML</button>
                    </div>
                </header>

                <!-- Metadata Modal -->
                <div id="metadataModal" class="modal-overlay">
                    <div class="modal-box">
                        <div class="modal-header">
                            <h2>メタデータ</h2>
                            <button id="closeModalBtn" class="modal-close">&#xd7;</button>
                        </div>
                        <div class="modal-body">
                            <div class="modal-section">
                                <p><strong>著者:</strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author"/></p>
                                <p><strong>出版社:</strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:bibl/tei:publisher"/></p>
                            </div>
                            <div class="modal-section">
                                <p><strong>配布:</strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:distributor"/></p>
                                <p><strong>公開日:</strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:date"/></p>
                            </div>
                            <div class="modal-section">
                                <p><strong>責任者:</strong></p>
                                <ul>
                                    <xsl:for-each select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:respStmt">
                                        <li><xsl:value-of select="tei:resp"/> - <xsl:value-of select="tei:name"/></li>
                                    </xsl:for-each>
                                </ul>
                            </div>
                            <div class="modal-section">
                                <p><strong>ライセンス:</strong>
                                    <a href="{tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:availability/tei:p/tei:ref/@target}" target="_blank">
                                        <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:availability/tei:p/tei:ref"/>
                                    </a>
                                </p>
                            </div>
                            <xsl:if test="tei:teiHeader/tei:encodingDesc/tei:p">
                                <div class="modal-section">
                                    <p><strong>エンコーディング:</strong></p>
                                    <p><xsl:value-of select="tei:teiHeader/tei:encodingDesc/tei:p"/></p>
                                </div>
                            </xsl:if>
                            <xsl:if test="tei:teiHeader/tei:revisionDesc">
                                <div class="modal-section">
                                    <p><strong>改訂履歴:</strong></p>
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
                <div id="settingsModal" class="modal-overlay">
                    <div class="modal-box" style="max-width:420px">
                        <div class="modal-header">
                            <h2>表示設定</h2>
                            <button id="closeSettingsBtn" class="modal-close">&#xd7;</button>
                        </div>
                        <div class="modal-body">
                            <div class="setting-item">
                                <div>
                                    <div class="setting-label">和歌ハイライト</div>
                                    <div class="setting-desc">和歌（短歌）を背景色で強調表示します</div>
                                </div>
                                <label class="toggle-switch">
                                    <input type="checkbox" id="toggleWaka" />
                                    <span class="toggle-slider"></span>
                                </label>
                            </div>
                            <div class="setting-item">
                                <div>
                                    <div class="setting-label">ページ区切り</div>
                                    <div class="setting-desc">原本のページ番号リンクを表示します</div>
                                </div>
                                <label class="toggle-switch">
                                    <input type="checkbox" id="togglePagebreak" checked="checked" />
                                    <span class="toggle-slider"></span>
                                </label>
                            </div>
                            <div class="setting-item">
                                <div>
                                    <div class="setting-label">RDFリンク</div>
                                    <div class="setting-desc">各行のLinked Data URIへのリンクを表示します</div>
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
                            for (const [page, canvas] of Object.entries(pageToCanvasMap)) {
                                canvasToPageMap[canvas] = page;
                            }

                            const urlParams = new URLSearchParams(window.location.search);
                            let initialCanvasId = urlParams.get('canvas');
                            const pageNumber = urlParams.get('n');

                            if (pageNumber &amp;&amp; pageToCanvasMap[pageNumber]) {
                                initialCanvasId = pageToCanvasMap[pageNumber];
                            }

                            if (!initialCanvasId) {
                                const firstPageNumber = Object.keys(pageToCanvasMap)[0];
                                if (firstPageNumber) {
                                    initialCanvasId = pageToCanvasMap[firstPageNumber];
                                }
                            }

                            const viewingDirection = urlParams.get('viewingDirection') || 'right-to-left';

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

                            let previousCanvasId = null;

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
                                    scrollToPbTag(currentWindow.canvasId);
                                    updateURLParameter('canvas', currentWindow.canvasId);
                                    previousCanvasId = currentWindow.canvasId;
                                }
                            });

                            function updateURLParameter(key, value) {
                                const url = new URL(window.location);
                                url.searchParams.delete('n');
                                url.searchParams.set(key, value);
                                window.history.replaceState({}, '', url);
                            }

                            function goToPage(canvasId) {
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

                            const wakaParam = urlParams.get('waka');
                            const correspParam = urlParams.get('corresp');
                            const highlightTarget = wakaParam ? `#${wakaParam}` : correspParam ? `span[data-corresp="${correspParam}"]` : null;

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
                                    + '<span>和歌一覧（' + wakaList.length + '首）</span>'
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
                                const htmlUrl = window.location.href.split('?')[0];
                                const xmlUrl = htmlUrl.replace(/\/html\/(\d+)\.html$/, '/tei/$1.xml');
                                fetch(xmlUrl)
                                    .then(response => response.text())
                                    .then(xmlContent => {
                                        const cleanedXml = xmlContent.replace(/&lt;\?xml-stylesheet[^?]*\?&gt;\s*/g, '');
                                        const blob = new Blob([cleanedXml], { type: 'application/xml' });
                                        window.location.href = URL.createObjectURL(blob);
                                    })
                                    .catch(error => {
                                        console.error('XMLファイル取得エラー:', error);
                                        alert('XMLファイルの取得に失敗しました。');
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
        <span class="page-link" data-canvas-id="{ $canvasUrl }">
            <xsl:attribute name="onclick">
                <xsl:text>goToPage('</xsl:text>
                <xsl:value-of select="$canvasUrl"/>
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
