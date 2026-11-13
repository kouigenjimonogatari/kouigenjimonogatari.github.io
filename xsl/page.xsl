<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0" exclude-result-prefixes="tei" version="2.0">
    <xsl:output method="html" encoding="UTF-8" />

    <!-- 表示の言語。ja なら html/NN.html、en なら en/html/NN.html として書き出す（scripts/prebuild.py）。
         以前は 1 つの頁を ?lang=en で切り替えていたが、URL のクエリに頼らないよう
         （Endings Principles 4.4）、言語ごとに静的な頁にした。 -->
    <xsl:param name="lang" select="'ja'"/>
    <!-- 版・公開日・DOI。scripts/prebuild.py が CITATION.cff から渡す -->
    <xsl:param name="version" select="''"/>
    <xsl:param name="released" select="''"/>
    <xsl:param name="doi" select="''"/>
    <xsl:variable name="en" select="$lang = 'en'"/>
    <!-- この頁からサイトの根への相対パス（英語の頁は 1 段深い） -->
    <xsl:variable name="root" select="if ($en) then '../../' else '../'"/>
    <xsl:key name="zone" match="tei:zone" use="@xml:id"/>
    <xsl:variable name="vol" select="replace(tokenize(base-uri(/), '/')[last()], '\.xml$', '')"/>

    <xsl:template match="/tei:TEI">
        <html lang="{$lang}">
            <head>
                <meta charset="UTF-8"/>
                <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
                <title>
                    <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[not(@type)][1]"/>
                </title>
                <link rel="alternate" hreflang="ja" href="https://kouigenjimonogatari.github.io/html/{$vol}.html"/>
                <link rel="alternate" hreflang="en" href="https://kouigenjimonogatari.github.io/en/html/{$vol}.html"/>
                <script src="{$root}lib/openseadragon-6.1.1/openseadragon.min.js"></script>
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
                        min-height: 56px;
                        gap: 0.5rem 1rem;
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

                    .header-version {
                        font-size: 0.75rem;
                        color: rgba(255,255,255,0.7);
                        white-space: nowrap;
                    }

                    .header-version a { color: inherit; }

                    @media (max-width: 768px) { .header-version { display: none; } }

                    .header-actions {
                        display: flex;
                        gap: 0.5rem;
                    }

                    a.btn { text-decoration: none; }

                    /* 狭い画面: 題名は 1 行で省略し、ボタンは次の行に並べる（以前は題名が縦に 1 字ずつ折れ、ボタンが 107px の高さになっていた） */
                    .header-left { min-width: 0; flex: 1 1 auto; }
                    .site-title { margin: 0; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
                    .btn { white-space: nowrap; }
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
                        position: relative;
                    }

                    #viewer {
                        width: 100%;
                        height: 100%;
                        position: relative;
                        background: #2b2b2b;
                    }

                    /* 画像の上のボタン（前後の画像・拡大・縮小・全体） */
                    .viewer-nav {
                        position: absolute;
                        top: 0.5rem;
                        left: 50%;
                        transform: translateX(-50%);
                        z-index: 10;
                        display: flex;
                        align-items: center;
                        gap: 0.25rem;
                        background: rgba(255,255,255,0.92);
                        border-radius: 6px;
                        padding: 0.2rem 0.35rem;
                        box-shadow: 0 1px 4px rgba(0,0,0,0.3);
                        font-size: 0.8125rem;
                    }
                    .viewer-nav button {
                        font: inherit;
                        border: 1px solid var(--color-border);
                        background: #fff;
                        color: var(--color-primary);
                        border-radius: 4px;
                        min-width: 2rem;
                        padding: 0.15rem 0.45rem;
                        cursor: pointer;
                    }
                    .viewer-nav button:hover:not(:disabled) { background: #f3ede6; }
                    .viewer-nav button:disabled { opacity: 0.4; cursor: default; }
                    .viewer-nav .viewer-count { padding: 0 0.35rem; white-space: nowrap; color: var(--color-text); }

                    /* 本文の行。押すと画像の上にその行の枠を描く */
                    span[data-line] { cursor: pointer; border-radius: 2px; }
                    span[data-line]:hover { background-color: rgba(229,57,53,0.07); }
                    span.line-active { background-color: rgba(229,57,53,0.14); }
                    /* 線で囲むと行の端の字が読みにくいので、薄い塗りにする（multiply で字の黒は残る） */
                    .line-box {
                        background-color: rgba(229,57,53,0.22);
                        mix-blend-mode: multiply;
                        border-radius: 3px;
                        pointer-events: none;
                    }

                    /* 狭い画面（600px 以下）。.btn と .text-pane の後に置く（前に置くと通常の指定に負ける） */
                    @media (max-width: 600px) {
                        .site-header { flex-wrap: wrap; padding: 0.5rem 0.75rem; }
                        .header-left { flex-basis: 100%; }
                        .site-title { font-size: 1rem; }
                        .header-actions { flex-basis: 100%; overflow-x: auto; gap: 0.375rem; }
                        .btn { padding: 0.3rem 0.6rem; font-size: 0.75rem; }
                        /* 本文と画像を左右に並べると 1 つが 130px ほどになるので、上下に積む */
                        .main-content { flex-direction: column; }
                        .text-pane { width: 100%; height: 45%; border-right: none; border-bottom: 1px solid var(--color-border); }
                        .viewer-pane { width: 100%; flex: 1; min-height: 0; }
                        .text-scroll { padding: 1rem; }
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
                        <a href="../index.html" class="home-link" aria-label="{if ($en) then 'Home' else 'トップ'}">
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
                                <path stroke-linecap="round" stroke-linejoin="round" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                            </svg>
                        </a>
                        <h1 class="site-title">
                            <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title[not(@type)][1]"/>
                        </h1>
                        <xsl:if test="$version != ''">
                            <!-- 版と公開日はどの頁にも見える形で出す（Endings Principles 5.3・5.4）。詳しくはメタデータの窓 -->
                            <a class="header-version" href="../index.html#cite">
                                <xsl:value-of select="if ($en) then concat('Version ', $version, ' (', $released, ')') else concat('版 ', $version, '（', $released, '）')"/>
                            </a>
                        </xsl:if>
                    </div>
                    <div class="header-actions">
                        <button id="showSettingsBtn" class="btn"><xsl:value-of select="if ($en) then 'Settings' else '表示設定'"/></button>
                        <button id="showMetadataBtn" class="btn"><xsl:value-of select="if ($en) then 'Metadata' else 'メタデータ'"/></button>
                        <button id="downloadXmlBtn" class="btn">TEI/XML</button>
                        <xsl:choose>
                            <xsl:when test="$en"><a class="btn" href="../../html/{$vol}.html" hreflang="ja" lang="ja">日本語</a></xsl:when>
                            <xsl:otherwise><a class="btn" href="../en/html/{$vol}.html" hreflang="en" lang="en">English</a></xsl:otherwise>
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
                            <xsl:if test="$version != ''">
                                <div class="modal-section">
                                    <p><strong><xsl:value-of select="if ($en) then 'Version:' else '版:'"/></strong>
                                        <xsl:text> </xsl:text><xsl:value-of select="$version"/>
                                        <xsl:value-of select="if ($en) then concat(' (released ', $released, ')') else concat('（', $released, ' 公開）')"/></p>
                                    <p><strong>DOI:</strong><xsl:text> </xsl:text><a href="https://doi.org/{$doi}" target="_blank"><xsl:value-of select="$doi"/></a></p>
                                    <p><a href="../index.html#cite"><xsl:value-of select="if ($en) then 'How to cite' else '引用の仕方'"/></a></p>
                                </div>
                            </xsl:if>
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

                    <!-- Right: 画像（OpenSeadragon） -->
                    <div class="viewer-pane">
                        <div class="viewer-nav">
                            <!-- 右から左へめくる本なので、「次」を左に置く -->
                            <button type="button" id="nextImage" title="{if ($en) then 'Next image' else '次の画像'}" aria-label="{if ($en) then 'Next image' else '次の画像'}">&#x2039;</button>
                            <span class="viewer-count" id="imageCount"></span>
                            <button type="button" id="prevImage" title="{if ($en) then 'Previous image' else '前の画像'}" aria-label="{if ($en) then 'Previous image' else '前の画像'}">&#x203a;</button>
                            <button type="button" id="zoomIn" title="{if ($en) then 'Zoom in' else '拡大'}" aria-label="{if ($en) then 'Zoom in' else '拡大'}">+</button>
                            <button type="button" id="zoomOut" title="{if ($en) then 'Zoom out' else '縮小'}" aria-label="{if ($en) then 'Zoom out' else '縮小'}">&#x2212;</button>
                            <button type="button" id="zoomHome" title="{if ($en) then 'Whole image' else '全体'}" aria-label="{if ($en) then 'Whole image' else '全体'}">&#x25a1;</button>
                        </div>
                        <div id="viewer"></div>

                        <script>
                            // この巻の画像。canvas は IIIF の Canvas、service は画像の配信（IIIF Image API）。
                            // 頁の facs の URL から配信の URL を取り出すので、マニフェストは読みに行かない。
                            const surfaces = [
                                <xsl:for-each select="//tei:surface">
                                    <xsl:variable name="ids" select="tei:zone/@xml:id"/>
                                    <xsl:variable name="pb" select="(//tei:pb[substring-after(@corresp, '#') = $ids])[1]"/>
                                    <xsl:if test="$pb">{ canvas: "<xsl:value-of select="@sameAs"/>", service: "<xsl:value-of select="replace($pb/@facs, '(/[^/]+){4}$', '')"/>" },
                                    </xsl:if>
                                </xsl:for-each>
                            ];

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
                                window.location.replace('../en/html/<xsl:value-of select="$vol"/>.html' + (rest ? '?' + rest : '') + window.location.hash);
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

                            const canvasIndex = {};
                            surfaces.forEach((sf, i) => { canvasIndex[sf.canvas] = i; });
                            const initialCanvasId = canvasForHash(hash) || (surfaces[0] &amp;&amp; surfaces[0].canvas);

                            const viewer = OpenSeadragon({
                                id: 'viewer',
                                tileSources: surfaces.map(sf => sf.service + '/info.json'),
                                sequenceMode: true,
                                initialPage: canvasIndex[initialCanvasId] || 0,
                                showNavigationControl: false,
                                showSequenceControl: false,
                                visibilityRatio: 0.5,
                                gestureSettingsMouse: { clickToZoom: false },
                            });

                            let imageOpen = false;   // 今の画像が読み込まれたか（枠を描くには座標の換算が要る）
                            let pendingLine = null;  // 画像の読み込みを待っている行
                            let quietPageChange = false; // 行や和歌から画像を替えたときは、本文を頁の頭へ送らない
                            let lineOverlay = null;
                            let activeLine = null;

                            function updateNav() {
                                const i = viewer.currentPage();
                                document.getElementById('imageCount').textContent = (i + 1) + ' / ' + surfaces.length;
                                document.getElementById('prevImage').disabled = i &lt;= 0;
                                document.getElementById('nextImage').disabled = i &gt;= surfaces.length - 1;
                            }
                            updateNav();

                            // 指定の画像へ替える。替えたら true
                            function showCanvas(canvasId, quiet) {
                                const i = canvasIndex[canvasId];
                                if (i === undefined || i === viewer.currentPage()) return false;
                                quietPageChange = !!quiet;
                                viewer.goToPage(i);
                                return true;
                            }

                            function scrollToPbTag(canvasId) {
                                const pbTag = document.querySelector(`span[data-canvas-id='${canvasId}']`);
                                if (pbTag) {
                                    pbTag.scrollIntoView({ behavior: "smooth", block: "start" });
                                }
                            }

                            viewer.addHandler('page', function(e) {
                                imageOpen = false;
                                lineOverlay = null; // 画像を開き直すと重ねた枠は消える
                                updateNav();
                                const sf = surfaces[e.page];
                                if (!sf) return;
                                if (quietPageChange) { quietPageChange = false; return; }
                                pendingLine = null;
                                if (activeLine) { activeLine.classList.remove('line-active'); activeLine = null; }
                                scrollToPbTag(sf.canvas);
                                const cur = /^#p(.+)$/.exec(window.location.hash);
                                if (cur &amp;&amp; pageToCanvasMap[cur[1]] === sf.canvas) return;
                                const page = canvasToPageMap[sf.canvas];
                                if (page) window.history.replaceState({}, '', '#p' + page);
                            });

                            viewer.addHandler('open', function() {
                                imageOpen = true;
                                if (pendingLine) { const l = pendingLine; pendingLine = null; drawLine(l); }
                            });

                            // 行の枠（TEI の zone type="line"）を赤で描き、その行が収まるように拡大する
                            function drawLine(span) {
                                const c = span.getAttribute('data-line').split(',').map(Number);
                                const vp = viewer.viewport;
                                const r = vp.imageToViewportRectangle(c[0], c[1], c[2] - c[0], c[3] - c[1]);
                                if (lineOverlay) viewer.removeOverlay(lineOverlay);
                                lineOverlay = document.createElement('div');
                                lineOverlay.className = 'line-box';
                                viewer.addOverlay({ element: lineOverlay, location: r });
                                // 行は縦に細長いので、左右に前後の数行が見える余白を取る
                                const padX = Math.max(r.width * 4, r.height * 0.15);
                                const padY = r.height * 0.06;
                                vp.fitBounds(new OpenSeadragon.Rect(r.x - padX, r.y - padY, r.width + 2 * padX, r.height + 2 * padY));
                            }

                            // 行の色付けを消す（拡大の位置はそのまま）
                            function clearLine() {
                                pendingLine = null;
                                if (lineOverlay) { viewer.removeOverlay(lineOverlay); lineOverlay = null; }
                                if (activeLine) { activeLine.classList.remove('line-active'); activeLine = null; }
                            }
                            document.addEventListener('keydown', function(e) {
                                if (e.key === 'Escape' &amp;&amp; !document.querySelector('.modal-overlay.active')) clearLine();
                            });

                            function selectLine(span) {
                                if (activeLine) activeLine.classList.remove('line-active');
                                activeLine = span;
                                span.classList.add('line-active');
                                const changed = showCanvas(span.getAttribute('data-canvas'), true);
                                if (changed || !imageOpen) pendingLine = span;
                                else drawLine(span);
                            }

                            document.getElementById('nextImage').addEventListener('click', () => viewer.goToPage(viewer.currentPage() + 1));
                            document.getElementById('prevImage').addEventListener('click', () => viewer.goToPage(viewer.currentPage() - 1));
                            document.getElementById('zoomIn').addEventListener('click', () => viewer.viewport.zoomBy(1.5));
                            document.getElementById('zoomOut').addEventListener('click', () => viewer.viewport.zoomBy(1 / 1.5));
                            document.getElementById('zoomHome').addEventListener('click', () => viewer.viewport.goHome());

                            window.addEventListener('hashchange', function() {
                                const h = decodeURIComponent(window.location.hash.slice(1));
                                const el = h &amp;&amp; document.getElementById(h);
                                if (el &amp;&amp; el.classList.contains('tei-lg')) {
                                    scrollToAndHighlight(el);
                                } else {
                                    const c = canvasForHash(h);
                                    if (c) goToPage(c, /^p/.test(h) ? h.slice(1) : null);
                                }
                            });

                            // 本文の [Page n] を押したとき
                            function goToPage(canvasId, page) {
                                if (page) window.history.replaceState({}, '', '#p' + page);
                                showCanvas(canvasId, false);
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
                                // 和歌の行の枠を画像に描く
                                const seg = targetElement.closest('span[data-line]');
                                if (seg) selectLine(seg);
                                else {
                                    const cs = targetElement.closest('span[data-canvas]');
                                    if (cs) showCanvas(cs.getAttribute('data-canvas'), true);
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

                            // 本文の行を押すと、画像の上にその行の枠を描く（文字を選んでいるときは何もしない）
                            textScroll.addEventListener('click', function(e) {
                                if (e.target.closest('a, .page-link')) return;
                                const sel = window.getSelection();
                                if (sel &amp;&amp; !sel.isCollapsed) return;
                                const span = e.target.closest('span[data-line]');
                                if (!span) return;
                                // 色の付いた行をもう一度押すと消す
                                if (span === activeLine) clearLine();
                                else selectLine(span);
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
                                const xmlUrl = '<xsl:value-of select="$root"/>tei/<xsl:value-of select="$vol"/>.xml';
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
                    <p>Powered by TEI, OpenSeadragon, and XSLT</p>
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
                <!-- この行の枠（直前の lb の facs が指す zone type="line"）。画像は行の zone の surface を優先する -->
                <xsl:variable name="lineZone" select="key('zone', substring-after(preceding-sibling::*[1][self::tei:lb]/@facs, '#'))[@type = 'line']"/>
                <xsl:if test="$lineZone">
                    <xsl:attribute name="data-canvas">
                        <xsl:value-of select="$lineZone/ancestor::tei:surface/@sameAs"/>
                    </xsl:attribute>
                    <xsl:attribute name="data-line">
                        <xsl:value-of select="concat($lineZone/@ulx, ',', $lineZone/@uly, ',', $lineZone/@lrx, ',', $lineZone/@lry)"/>
                    </xsl:attribute>
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
