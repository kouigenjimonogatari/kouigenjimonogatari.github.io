<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" 
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tei="http://www.tei-c.org/ns/1.0">
  
  <xsl:output method="text" encoding="UTF-8"/>
  
  <xsl:template match="/">
\documentclass[a4paper,11pt,landscape]{ltjtarticle}
\usepackage{xcolor}

\usepackage{luatexja-fontspec} % fontspec を LuaTeX-ja と共に利用

\usepackage[top=2cm,bottom=2cm,left=2cm,right=2cm,textwidth=25cm]{geometry}

% スタイル定義
\newcommand{\person}[1]{\textbf{\color{blue}#1}}
\newcommand{\place}[1]{\textit{\color{green}#1}}

% 日本語フォント設定
\setmainjfont{Noto Serif CJK JP} % 日本語フォントを指定

\title{<xsl:value-of select="//tei:title"/>}
\date{}

\begin{document}
\maketitle

% 本文
<xsl:for-each select="//tei:seg">
<xsl:apply-templates/>
\par\medskip
</xsl:for-each>

\end{document}
  </xsl:template>

  <!-- 人名の処理 -->
  <xsl:template match="tei:persName">
\person{<xsl:value-of select="."/>}</xsl:template>

  <!-- 地名の処理 -->
  <xsl:template match="tei:placeName">
\place{<xsl:value-of select="."/>}</xsl:template>

</xsl:stylesheet>