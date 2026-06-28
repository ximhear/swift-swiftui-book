#!/usr/bin/env python3
"""소스 원고(chapters/, appendix/)를 epub 빌드용 build/ 디렉토리로 전처리한다.

수행 작업:
- chapters/chXX-*/chapter.md → build/chXX.md (장 순서대로 평탄화)
- 각 ```mermaid 블록을 전역 번호의 이미지 참조(![다이어그램 N](images/diagram_NN.png))로
  치환하고, mermaid 소스를 build/images/diagram_NN.mmd로 추출
- appendix/*.md → build/appA-D.md
- part1-3.md, appendix-header.md, metadata.yaml을 build/로 복사해 자족적 입력 구성

다이어그램 PNG 자체는 이 스크립트가 렌더링하지 않는다(mermaid-cli 의존). build/images에
기존 PNG가 있으면 재사용하고, .mmd 내용이 바뀌었으면 경고한다.
"""
import re
import shutil
import sys
from pathlib import Path

EPUB_DIR = Path(__file__).resolve().parent
ROOT = EPUB_DIR.parent
BUILD = EPUB_DIR / "build"
IMAGES = BUILD / "images"

# 장 순서: (소스 디렉토리, build 파일명)
CHAPTERS = [
    ("ch01-swift-type-system", "ch01.md"),
    ("ch02-generics-protocols", "ch02.md"),
    ("ch03-swift-concurrency", "ch03.md"),
    ("ch04-memory-performance", "ch04.md"),
    ("ch05-swift-macro", "ch05.md"),
    ("ch06-swiftui-rendering", "ch06.md"),
    ("ch07-state-management", "ch07.md"),
    ("ch08-custom-layout", "ch08.md"),
    ("ch09-animation", "ch09.md"),
    ("ch10-navigation", "ch10.md"),
    ("ch11-architecture", "ch11.md"),
    ("ch12-network-data", "ch12.md"),
    ("ch13-testing", "ch13.md"),
    ("ch14-profiling", "ch14.md"),
]

APPENDICES = [
    ("appendix-a-swift61.md", "appA.md"),
    ("appendix-b-swiftui-versions.md", "appB.md"),
    ("appendix-c-tools.md", "appC.md"),
    ("appendix-d-resources.md", "appD.md"),
]

# 본문에 그대로 복사되는 보조 파일
PASSTHROUGH = ["part1.md", "part2.md", "part3.md", "appendix-header.md", "metadata.yaml", "style.css"]

MERMAID_RE = re.compile(r"```mermaid\n(.*?)\n```", re.DOTALL)


def main() -> int:
    BUILD.mkdir(exist_ok=True)
    IMAGES.mkdir(exist_ok=True)

    counter = 0
    warnings = []

    def replace_mermaid(match: "re.Match") -> str:
        nonlocal counter
        counter += 1
        n = f"{counter:02d}"
        mmd_path = IMAGES / f"diagram_{n}.mmd"
        png_path = IMAGES / f"diagram_{n}.png"
        new_src = match.group(1).strip() + "\n"
        # 기존 .mmd와 비교: 내용이 바뀌었으면 PNG 재렌더 필요 경고
        if mmd_path.exists():
            old_src = mmd_path.read_text(encoding="utf-8")
            if old_src.strip() != new_src.strip():
                warnings.append(
                    f"diagram_{n}: mermaid 소스가 변경됨 — PNG 재렌더 필요 "
                    f"(mmdc -i {mmd_path} -o {png_path})"
                )
        mmd_path.write_text(new_src, encoding="utf-8")
        if not png_path.exists():
            warnings.append(f"diagram_{n}: PNG 누락 — {png_path} 렌더 필요")
        return f"![다이어그램 {counter}](images/diagram_{n}.png)"

    for src_dir, out_name in CHAPTERS:
        src = ROOT / "chapters" / src_dir / "chapter.md"
        if not src.exists():
            print(f"ERROR: 소스 없음 {src}", file=sys.stderr)
            return 1
        text = src.read_text(encoding="utf-8")
        text = MERMAID_RE.sub(replace_mermaid, text)
        (BUILD / out_name).write_text(text, encoding="utf-8")

    for src_name, out_name in APPENDICES:
        src = ROOT / "appendix" / src_name
        if not src.exists():
            print(f"ERROR: 부록 소스 없음 {src}", file=sys.stderr)
            return 1
        shutil.copyfile(src, BUILD / out_name)

    for name in PASSTHROUGH:
        shutil.copyfile(EPUB_DIR / name, BUILD / name)

    print(f"전처리 완료: 장 {len(CHAPTERS)}개, 부록 {len(APPENDICES)}개, 다이어그램 {counter}개")
    if warnings:
        print("\n경고:")
        for w in warnings:
            print(f"  - {w}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
