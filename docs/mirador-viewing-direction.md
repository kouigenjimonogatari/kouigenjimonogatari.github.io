# Miradorの表示方向を外部から制御する方法

## 概要

Mirador viewerの表示方向（`viewingDirection`）をURLパラメータから動的に指定する実装について解説します。この機能により、同じマニフェストを左から右（left-to-right）または右から左（right-to-left）で表示することができます。

## 実装方法

### 1. URLパラメータの取得

URLから`viewingDirection`パラメータを取得し、デフォルト値を設定します：

```javascript
// URLパラメータから表示方向を取得
const urlParams = new URLSearchParams(window.location.search);
const viewingDirection = urlParams.get('viewingDirection') || 'right-to-left';
```

この実装では、パラメータが指定されていない場合は`'right-to-left'`（右から左）がデフォルトとして使用されます。

### 2. Mirador設定への適用

取得した`viewingDirection`をMiradorの初期設定に組み込みます：

```javascript
const miradorConfig = {
    id: "viewer",
    windows: [{
        id: 'known-window-id',
        loadedManifest: manifestUrl,
        viewingDirection: viewingDirection,  // URLパラメータの値を使用
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
```

### 3. 使用例

#### 右から左表示（デフォルト）
```
https://example.com/viewer.xml
```
または
```
https://example.com/viewer.xml?viewingDirection=right-to-left
```

#### 左から右表示
```
https://example.com/viewer.xml?viewingDirection=left-to-right
```

## XSLTでの実装

XSLTテンプレート内でこの機能を実装する場合、以下のコードをスクリプトセクションに追加します（mirador.xsl:222-230）:

```xml
<!-- URLパラメータから表示方向を取得 -->
const viewingDirection = urlParams.get('viewingDirection') || 'right-to-left';

// Miradorの初期設定
const miradorConfig = {
    id: "viewer",
    windows: [{
        id: 'known-window-id',
        loadedManifest: manifestUrl,
        viewingDirection: viewingDirection,
    }],
    // ... その他の設定
};
```

## 利用可能な値

Miradorの`viewingDirection`には以下の値が使用できます：

- `left-to-right` - 左から右へページをめくる（欧文書籍など）
- `right-to-left` - 右から左へページをめくる（和書、アラビア語書籍など）
- `top-to-bottom` - 上から下へ（巻物など）
- `bottom-to-top` - 下から上へ

## 注意点

1. **マニフェストファイル内で`viewingDirection`が指定されている場合、マニフェストの設定が優先されます**。この方法は主にマニフェストファイル内で表示方向が指定されていない場合に有効です
2. この設定はwindow単位で適用されます
3. URLパラメータはページ読み込み時にのみ評価されます
4. ユーザーがMirador UI上で表示方向を変更した場合、URLパラメータの値は上書きされます

## 関連ファイル

- `xsl/mirador.xsl` - XSLT変換テンプレート（実装箇所）
