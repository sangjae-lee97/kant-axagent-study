
import re
from html import escape
from datetime import date
from pathlib import Path

from PIL import Image as PILImage
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Image,
    HRFlowable,
    KeepTogether,
)

BASE_DIR = Path(__file__).resolve().parents[1]
REPORTS_DIR = BASE_DIR / "reports"

FONT_PATH = Path(r"C:\Windows\Fonts\malgun.ttf")
if not FONT_PATH.exists():
    raise RuntimeError("맑은 고딕 폰트를 찾을 수 없습니다.")

pdfmetrics.registerFont(TTFont("Malgun", str(FONT_PATH)))

styles = {
    "title": ParagraphStyle(
        "KoreanTitle",
        fontName="Malgun",
        fontSize=18,
        leading=26,
        spaceAfter=16,
    ),
    "heading": ParagraphStyle(
        "KoreanHeading",
        fontName="Malgun",
        fontSize=13,
        leading=20,
        spaceBefore=15,
        spaceAfter=8,
    ),
    "body": ParagraphStyle(
        "KoreanBody",
        fontName="Malgun",
        fontSize=10,
        leading=17,
        spaceAfter=6,
        wordWrap="CJK",
    ),
}


def format_inline(text):
    parts = re.split(
        r"(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`)",
        text,
    )

    result = []

    for part in parts:
        if part.startswith("**") and part.endswith("**"):
            result.append(f"<b>{escape(part[2:-2])}</b>")
        elif part.startswith("*") and part.endswith("*"):
            result.append(escape(part[1:-1]))
        elif part.startswith("`") and part.endswith("`"):
            result.append(escape(part[1:-1]))
        else:
            result.append(escape(part))

    return "".join(result)


def add_markdown(story, text):
    for raw_line in text.splitlines():
        line = raw_line.strip()

        if not line:
            story.append(Spacer(1, 5))
            continue

        if re.fullmatch(r"-{3,}", line):
            story.append(HRFlowable(width="100%"))
            continue

        heading = re.match(r"^#{1,6}\s+(.+)$", line)
        if heading:
            story.append(Paragraph(
                format_inline(heading.group(1)),
                styles["heading"],
            ))
            continue

        bullet = re.match(r"^[-*]\s+(.+)$", line)
        if bullet:
            line = "• " + bullet.group(1)

        quote = re.match(r"^>\s*(.+)$", line)
        if quote:
            line = quote.group(1)

        story.append(Paragraph(
            format_inline(line),
            styles["body"],
        ))


def add_chart(story, filename, title):
    path = REPORTS_DIR / filename

    if not path.exists():
        raise FileNotFoundError(f"그래프 없음: {path}")

    with PILImage.open(path) as img:
        width, height = img.size

    max_width = 480
    max_height = 300
    scale = min(max_width / width, max_height / height)

    chart_image = Image(
        str(path),
        width=width * scale,
        height=height * scale,
    )

    story.append(
        KeepTogether([
            Spacer(1, 16),
            Paragraph(title, styles["heading"]),
            chart_image,
        ])
    )


today = date.today().isoformat()
pdf_path = REPORTS_DIR / f"tourism_trend_report_{today}.pdf"
md_path = REPORTS_DIR / "llm_summary.md"

if not md_path.exists():
    raise FileNotFoundError("llm_summary.md 파일이 없습니다.")

report_text = md_path.read_text(encoding="utf-8")

if not report_text.strip():
    raise ValueError("LLM 보고서 내용이 비어 있습니다.")

doc = SimpleDocTemplate(
    str(pdf_path),
    pagesize=A4,
    rightMargin=42,
    leftMargin=42,
    topMargin=42,
    bottomMargin=42,
)

story = [
    Paragraph("관광 트렌드 자동 분석 보고서", styles["title"]),
    Paragraph(f"보고서 생성일: {today}", styles["body"]),
    Spacer(1, 12),
]

add_markdown(story, report_text)

add_chart(
    story,
    "naver_trend.png",
    "NAVER 검색 관심도 추이",
)

add_chart(
    story,
    "tourism_consumption_top10.png",
    "서울 자치구 관광 소비 지표 TOP 10",
)

doc.build(story)

print("[PASS] PDF created:", pdf_path)
