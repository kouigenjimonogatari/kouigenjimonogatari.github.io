#!/bin/bash

# 01から54までループ処理
for i in $(seq -f "%02g" 1 54); do
  echo "Processing directory $i..."

  # XMLからTeXを生成
  npx xslt3 -xsl:xsl/tex.xsl -s:xml/xsl/$i.xml -o:output/$i/main.tex
  if [ $? -ne 0 ]; then
    echo "Error during XSLT processing for $i. Skipping..."
    continue
  fi

  # LuaLaTeXでPDFを生成
  lualatex -output-directory=output/$i output/$i/main.tex
  if [ $? -ne 0 ]; then
    echo "Error during PDF generation for $i. Skipping..."
    continue
  fi

  echo "Finished processing $i."
done

echo "All tasks completed."