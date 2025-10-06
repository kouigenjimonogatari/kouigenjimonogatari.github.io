<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0" version="2.0">
    <xsl:output method="html" encoding="UTF-8" />

    <!-- ルート要素にマッチさせる -->
    <xsl:template match="/tei:TEI">
        <html>
            <head>
                <title>
                    <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title"/>
                </title>
                <!-- Tailwind CSS CDNのリンク -->
                <link href="https://cdn.jsdelivr.net/npm/tailwindcss@2.0.0/dist/tailwind.min.css" rel="stylesheet"/>
                <script type="text/javascript" src="https://unpkg.com/mirador@latest/dist/mirador.min.js"></script>
                <style>
                    /* 全体の高さを100%に設定 */
                    html, body {
                        height: 100%;
                        margin: 0;
                        display: flex;
                        flex-direction: column;
                    }

                    /* ヘッダーとフッターの固定高さ */
                    header, footer {
                        height: 60px; /* 必要に応じて高さを調整 */
                        flex-shrink: 0;
                    }

                    /* メインコンテンツがヘッダーとフッターの高さを引いた分の高さを占有 */
                    main {
                        height: calc(100%);
                        display: flex;
                    }

                    /* テキストを縦書きに設定 */
                    .vertical-text {
                        writing-mode: vertical-rl;
                        text-orientation: upright;
                        overflow-y: auto;
                        height: 100%;
                    }

                    /* Miradorが親コンテナのサイズに従うように調整 */
                    #viewer {
                        width: 100%;
                        position: relative;
                    }

                    /* Pageリンクの英語テキストを横向きに設定 */
                    .sideways-text {
                        text-orientation: sideways;
                        display: inline;
                    }

                    /* ハイライト表示用のスタイル */
                    .highlight {
                        background-color: yellow;
                        font-weight: bold;
                    }

                    /* モーダル用のスタイル */
                    .modal {
                        display: none;
                        position: fixed;
                        z-index: 1000;
                        left: 0;
                        top: 0;
                        width: 100%;
                        height: 100%;
                        background-color: rgba(0, 0, 0, 0.5);
                    }

                    .modal.active {
                        display: flex;
                        align-items: center;
                        justify-content: center;
                    }

                    .modal-content {
                        background-color: white;
                        padding: 2rem;
                        border-radius: 0.5rem;
                        max-width: 600px;
                        max-height: 80vh;
                        overflow-y: auto;
                        position: relative;
                    }
                </style>
            </head>
            <body class="bg-gray-50 text-gray-900">
                <!-- ヘッダー -->
                <header class="bg-blue-600 text-white p-4 flex justify-between items-center">
                    <div class="flex items-center gap-4">
                        <a href="../../" class="text-white hover:text-blue-200 transition-colors">
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                            </svg>
                        </a>
                        <h1 class="text-2xl font-bold">
                            <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title"/>
                        </h1>
                    </div>
                    <div class="flex gap-2">
                        <button id="showMetadataBtn" class="bg-white text-blue-600 px-4 py-2 rounded hover:bg-blue-50 font-semibold">
                            メタデータ
                        </button>
                        <button id="downloadXmlBtn" class="bg-white text-blue-600 px-4 py-2 rounded hover:bg-blue-50 font-semibold">
                            TEI/XML ダウンロード
                        </button>
                    </div>
                </header>

                <!-- メタデータモーダル -->
                <div id="metadataModal" class="modal">
                    <div class="modal-content">
                        <div class="flex justify-between items-center mb-4">
                            <h2 class="text-xl font-bold">メタデータ</h2>
                            <button id="closeModalBtn" class="text-gray-500 hover:text-gray-700 text-2xl leading-none">×</button>
                        </div>
                        <div class="text-sm text-gray-700 space-y-3">
                            <div>
                                <p><strong>著者:</strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author"/></p>
                                <p><strong>出版社:</strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:sourceDesc/tei:bibl/tei:publisher"/></p>
                            </div>
                            <div>
                                <p><strong>配布:</strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:distributor"/></p>
                                <p><strong>公開日:</strong> <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:date"/></p>
                            </div>
                            <div>
                                <p><strong>責任者:</strong></p>
                                <ul class="ml-4 list-disc">
                                    <xsl:for-each select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:respStmt">
                                        <li><xsl:value-of select="tei:resp"/> - <xsl:value-of select="tei:name"/></li>
                                    </xsl:for-each>
                                </ul>
                            </div>
                            <div>
                                <p><strong>ライセンス:</strong>
                                    <a href="{tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:availability/tei:p/tei:ref/@target}"
                                       class="text-blue-600 hover:underline" target="_blank">
                                        <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:publicationStmt/tei:availability/tei:p/tei:ref"/>
                                    </a>
                                </p>
                            </div>
                            <xsl:if test="tei:teiHeader/tei:encodingDesc/tei:p">
                                <div>
                                    <p><strong>エンコーディング:</strong></p>
                                    <p class="ml-4 text-xs">
                                        <xsl:value-of select="tei:teiHeader/tei:encodingDesc/tei:p"/>
                                    </p>
                                </div>
                            </xsl:if>
                            <xsl:if test="tei:teiHeader/tei:revisionDesc">
                                <div>
                                    <p><strong>改訂履歴:</strong></p>
                                    <ul class="ml-4 list-disc text-xs">
                                        <xsl:for-each select="tei:teiHeader/tei:revisionDesc/tei:change">
                                            <li>
                                                <xsl:value-of select="@when"/> - <xsl:value-of select="."/>
                                            </li>
                                        </xsl:for-each>
                                    </ul>
                                </div>
                            </xsl:if>
                        </div>
                    </div>
                </div>

                <!-- メインコンテンツ -->
                <main>
                    <!-- 左側: TEIテキスト表示用 -->
                    <div class="w-1/2 border-r border-gray-300 flex flex-col">
                        <!-- TEI本文（横スクロール対象） -->
                        <div class="flex-1 p-4 vertical-text horizontal-scroll overflow-y-auto">
                            <xsl:apply-templates select="tei:text/tei:body" />
                        </div>
                    </div>

                    <!-- 右側: Miradorビューワー -->
                    <div class="w-1/2 flex">
                        <div id="viewer" class="border border-gray-300 flex-1"></div>

                        <script>
                            // マニフェストURLをXSLTから受け取る
                            const manifestUrl = "<xsl:value-of select="//tei:facsimile/@sameAs"></xsl:value-of>";

                            // pbタグのページ番号とcanvasIdのマッピング
                            const pageToCanvasMap = {
                                <xsl:for-each select="//tei:pb">
                                    <xsl:variable name="zoneId" select="substring-after(@corresp, '#')" />
                                    <xsl:variable name="canvasUrl" select="//tei:zone[@xml:id=$zoneId]/ancestor::tei:surface/@sameAs" />
                                    "<xsl:value-of select="@n"/>": "<xsl:value-of select="$canvasUrl"/>"<xsl:if test="position() != last()">,</xsl:if>
                                </xsl:for-each>
                            };

                            // canvasIdからページ番号への逆マッピング
                            const canvasToPageMap = {};
                            for (const [page, canvas] of Object.entries(pageToCanvasMap)) {
                                canvasToPageMap[canvas] = page;
                            }

                            // URLパラメータから初期canvasを取得
                            const urlParams = new URLSearchParams(window.location.search);
                            let initialCanvasId = urlParams.get('canvas');
                            const pageNumber = urlParams.get('n');

                            // ページ番号が指定されている場合は、それをcanvasIdに変換
                            if (pageNumber &amp;&amp; pageToCanvasMap[pageNumber]) {
                                initialCanvasId = pageToCanvasMap[pageNumber];
                            }

                            // canvasもnも指定されていない場合は、最初のpbに対応するcanvasを使用
                            if (!initialCanvasId) {
                                const firstPageNumber = Object.keys(pageToCanvasMap)[0];
                                if (firstPageNumber) {
                                    initialCanvasId = pageToCanvasMap[firstPageNumber];
                                }
                            }

                            // URLパラメータから表示方向を取得
                            const viewingDirection = urlParams.get('viewingDirection') || 'right-to-left';

                            // Miradorの初期設定
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

                            // 初期canvasが指定されている場合は設定
                            if (initialCanvasId) {
                                miradorConfig.windows[0].canvasId = initialCanvasId;
                            } else {
                                miradorConfig.windows[0].canvasIndex = 0;
                            }

                            const miradorInstance = Mirador.viewer(miradorConfig);

                            // ページ遷移に使用する関数
                            let previousCanvasId = null;

                            // ページ移動時に対応するpbタグにスクロールする関数
                            function scrollToPbTag(canvasId) {
                                const pbTag = document.querySelector(`span[data-canvas-id='${canvasId}']`);
                                if (pbTag) {
                                    pbTag.scrollIntoView({ behavior: "smooth", block: "start" });
                                }
                            }

                            // ページ遷移イベントのリスナーを追加
                            miradorInstance.store.subscribe(() => {
                                const state = miradorInstance.store.getState();
                                const currentWindow = state.windows['known-window-id'];

                                // canvasIdが変更された場合の処理
                                if (currentWindow.canvasId !== previousCanvasId) {
                                    // 任意の処理をここに記述
                                    // 例えば、対応するページ番号の表示、またはページが変わったことを知らせるUI更新など

                                    scrollToPbTag(currentWindow.canvasId);

                                    // URLパラメータを更新
                                    updateURLParameter('canvas', currentWindow.canvasId);

                                    // 前回のcanvasIdを更新
                                    previousCanvasId = currentWindow.canvasId;
                                }
                            });

                            // URLパラメータを更新する関数
                            function updateURLParameter(key, value) {
                                const url = new URL(window.location);

                                // nパラメータは初回のみ使用するため削除
                                url.searchParams.delete('n');

                                // canvasパラメータを設定
                                url.searchParams.set(key, value);

                                window.history.replaceState({}, '', url);
                            }

                            // ページ遷移関数
                            function goToPage(canvasId) {
                                try {
                                    console.log('Target Canvas ID:', canvasId);

                                    // setCanvasアクションを正しい形式で作成（visibleCanvasesを含める）
                                    const action = {
                                        type: 'mirador/SET_CANVAS',
                                        windowId: 'known-window-id',
                                        canvasId: canvasId,
                                        visibleCanvases: [canvasId]  // これが必須
                                    };

                                    console.log('Dispatching action:', action);
                                    miradorInstance.store.dispatch(action);
                                } catch (error) {
                                    console.error('Error navigating to canvas:', error, error.stack);
                                }
                            }
                            
                            // 横スクロール領域のみにイベントリスナーを追加
                            const scrollArea = document.querySelector('.horizontal-scroll');
                            if (scrollArea) {
                                scrollArea.addEventListener('wheel', function(e) {
                                    e.preventDefault();
                                    this.scrollLeft += e.deltaY; // 縦スクロールを横スクロールに変換
                                });
                            }

                            // corresp パラメータによるハイライト機能
                            const correspParam = urlParams.get('corresp');
                            if (correspParam) {
                                // リトライ機能付きでハイライトを適用
                                let attempts = 0;
                                const maxAttempts = 20;

                                const tryHighlight = () => {
                                    const targetElement = document.querySelector(`span[data-corresp="${correspParam}"]`);
                                    if (targetElement) {
                                        // テキストをハイライト
                                        targetElement.classList.add('highlight');

                                        // 親のスクロールコンテナを取得
                                        const scrollContainer = document.querySelector('.horizontal-scroll');
                                        if (scrollContainer) {
                                            setTimeout(() => {
                                                // 現在の位置情報を取得
                                                const targetRect = targetElement.getBoundingClientRect();
                                                const containerRect = scrollContainer.getBoundingClientRect();

                                                // 現在のスクロール位置 + 要素の相対位置 - コンテナ幅の半分
                                                const currentScroll = scrollContainer.scrollLeft;
                                                const targetRelativeLeft = targetRect.left - containerRect.left;
                                                const scrollPosition = currentScroll + targetRelativeLeft - (scrollContainer.clientWidth / 2) + (targetRect.width / 2);

                                                console.log('Scroll debug:', {
                                                    currentScroll,
                                                    targetRelativeLeft,
                                                    containerWidth: scrollContainer.clientWidth,
                                                    scrollPosition
                                                });

                                                scrollContainer.scrollTo({
                                                    left: scrollPosition,
                                                    behavior: 'smooth'
                                                });
                                            }, 300);
                                        }

                                        // 対応するcanvasに移動
                                        const canvas = targetElement.getAttribute('data-canvas');
                                        if (canvas) {
                                            const action = {
                                                type: 'mirador/SET_CANVAS',
                                                windowId: 'known-window-id',
                                                canvasId: canvas,
                                                visibleCanvases: [canvas]
                                            };
                                            miradorInstance.store.dispatch(action);
                                        }
                                        return true;
                                    }
                                    return false;
                                };

                                const retryInterval = setInterval(() => {
                                    attempts++;
                                    if (tryHighlight() || attempts >= maxAttempts) {
                                        clearInterval(retryInterval);
                                        if (attempts >= maxAttempts) {
                                            console.warn('Could not find element with corresp:', correspParam);
                                        }
                                    }
                                }, 200);
                            }

                            // メタデータモーダルの開閉機能
                            const metadataModal = document.getElementById('metadataModal');
                            const showMetadataBtn = document.getElementById('showMetadataBtn');
                            const closeModalBtn = document.getElementById('closeModalBtn');

                            showMetadataBtn.addEventListener('click', function() {
                                metadataModal.classList.add('active');
                            });

                            closeModalBtn.addEventListener('click', function() {
                                metadataModal.classList.remove('active');
                            });

                            // モーダル背景クリックで閉じる
                            metadataModal.addEventListener('click', function(e) {
                                if (e.target === metadataModal) {
                                    metadataModal.classList.remove('active');
                                }
                            });

                            // TEI/XMLダウンロード機能
                            document.getElementById('downloadXmlBtn').addEventListener('click', function() {
                                // 現在のXMLファイルのURLを取得
                                const xmlUrl = window.location.href.split('?')[0];

                                // XMLファイルを取得してダウンロード
                                fetch(xmlUrl)
                                    .then(response => response.text())
                                    .then(xmlContent => {
                                        // XSL処理命令を除去
                                        const cleanedXml = xmlContent.replace(/&lt;\?xml-stylesheet[^?]*\?&gt;\s*/g, '');

                                        // Blobを作成
                                        const blob = new Blob([cleanedXml], { type: 'application/xml' });
                                        const url = URL.createObjectURL(blob);

                                        // ダウンロード用のリンクを作成
                                        const a = document.createElement('a');
                                        a.href = url;
                                        a.download = xmlUrl.split('/').pop() || 'document.xml';
                                        document.body.appendChild(a);
                                        a.click();

                                        // クリーンアップ
                                        document.body.removeChild(a);
                                        URL.revokeObjectURL(url);
                                    })
                                    .catch(error => {
                                        console.error('ダウンロードエラー:', error);
                                        alert('XMLファイルのダウンロードに失敗しました。');
                                    });
                            });
                        </script>
                    </div>
                </main>

                <!-- フッター -->
                <footer class="bg-gray-800 text-white p-4 text-center">
                    <p>Powered by TEI, Mirador, and XSLT</p>
                </footer>
            </body>
        </html>
    </xsl:template>

    <!-- body要素とpbタグの処理 -->
    <xsl:template match="tei:body">
        <div class="prose">
            <xsl:apply-templates select="*|text()" />
        </div>
    </xsl:template>

    <!-- `lb`タグの処理 (改行) -->
    <xsl:template match="tei:lb">
        <br/>
    </xsl:template>

    <!-- `pb`タグの表示 -->
    <xsl:template match="tei:pb">
        <xsl:variable name="zoneId" select="substring-after(@corresp, '#')" />
        <!-- 対応するsurface/canvasのURLを取得 -->
        <xsl:variable name="canvasUrl" select="//tei:zone[@xml:id=$zoneId]/ancestor::tei:surface/@sameAs" />

        <span class="text-blue-500 cursor-pointer hover:underline sideways-text" data-canvas-id="{ $canvasUrl }">
            <xsl:attribute name="onclick">
                <xsl:text>goToPage('</xsl:text>
                <xsl:value-of select="$canvasUrl"/>
                <xsl:text>')</xsl:text>
            </xsl:attribute>
            [Page <xsl:value-of select="@n" />
]
        </span>
    </xsl:template>

    <!-- `seg`タグの処理 (corresp属性とzone情報をdata属性として保持) -->
    <xsl:template match="tei:seg">
        <span>
            <xsl:if test="@corresp">
                <xsl:attribute name="data-corresp">
                    <xsl:value-of select="@corresp"/>
                </xsl:attribute>
                <!-- 直前のpb要素を取得 -->
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
        </span>
    </xsl:template>

    <!-- その他の要素の処理 -->
    <xsl:template match="tei:*">
        <xsl:element name="{name()}">
            <xsl:attribute name="class">my-2</xsl:attribute>
            <xsl:apply-templates select="@*|node()" />
        </xsl:element>
    </xsl:template>
</xsl:stylesheet>
