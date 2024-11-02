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
                        height: calc(100% - 120px); /* 120px = header 60px + footer 60px */
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
                        height: 100%;
                    }

                    /* Pageリンクの英語テキストを横向きに設定 */
                    .sideways-text {
                        text-orientation: sideways;
                        display: inline;
                    }
                </style>
            </head>
            <body class="bg-gray-50 text-gray-900">
                <!-- ヘッダー -->
                <header class="bg-blue-600 text-white p-4">
                    <h1 class="text-2xl font-bold">
                        <xsl:value-of select="tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title"/>
                    </h1>
                </header>

                <!-- メインコンテンツ -->
                <main>
                    <!-- 左側: TEIテキスト表示用 -->
                    <div class="w-1/2 p-4 border-r border-gray-300 vertical-text horizontal-scroll">
                        <xsl:apply-templates select="tei:text/tei:body" />
                    </div>

                    <!-- 右側: Miradorビューワー -->
                    <div class="w-1/2">
                        <div id="viewer" class="border border-gray-300"></div>

                        <script>
                            
                            // マニフェストURLをXSLTから受け取る
                            const manifestUrl = "<xsl:value-of select="//tei:facsimile/@sameAs"></xsl:value-of>";

                            // Miradorの初期設定
                            const miradorInstance = Mirador.viewer({
                                id: "viewer",
                                windows: [{
                                    id: 'known-window-id',
                                    loadedManifest: manifestUrl,
                                    canvasIndex: 0
                                }]
                            });

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

                                    // 前回のcanvasIdを更新
                                    previousCanvasId = currentWindow.canvasId;
                                }
                            });

                            // ページ遷移関数
                            function goToPage(canvasUri) {
                                var action = Mirador.actions.setCanvas('known-window-id', canvasUri);
                                // Now we can dispatch it.
                                miradorInstance.store.dispatch(action);
                            }
                            
                            document.querySelector('.horizontal-scroll').addEventListener('wheel', function(e) {
                                e.preventDefault();
                                this.scrollLeft += e.deltaY; // 縦スクロールを横スクロールに変換
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

    <!-- `seg`タグの処理 (corresp属性を非表示) -->
    <xsl:template match="tei:seg">
        <span>
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
