#!/usr/bin/env bash
# epub 빌드 스크립트
# 사용법: epub/build.sh
# 1) preprocess.py로 소스(chapters/, appendix/)를 build/로 전처리
# 2) pandoc으로 build/ 입력을 단일 epub으로 조립
set -euo pipefail

EPUB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="$EPUB_DIR/build"
OUT="$EPUB_DIR/../swift-swiftui-심화가이드.epub"

command -v pandoc >/dev/null || { echo "ERROR: pandoc이 필요합니다"; exit 1; }

echo "[1/2] 전처리"
python3 "$EPUB_DIR/preprocess.py"

echo "[2/2] pandoc 조립"
# 조립 순서: 메타 → Part1(ch01-05) → Part2(ch06-10) → Part3(ch11-14) → 부록(A-D)
# 이미지 경로(images/...)가 풀리도록 build/에서 실행한다.
cd "$BUILD"
pandoc \
    metadata.yaml \
    part1.md ch01.md ch02.md ch03.md ch04.md ch05.md \
    part2.md ch06.md ch07.md ch08.md ch09.md ch10.md \
    part3.md ch11.md ch12.md ch13.md ch14.md \
    appendix-header.md appA.md appB.md appC.md appD.md \
    --toc --toc-depth=2 \
    --split-level=1 \
    --css=style.css \
    --metadata title-prefix="" \
    -o "$OUT"

echo "완료: $OUT"
ls -la "$OUT"
