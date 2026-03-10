#!/usr/bin/env python3
import argparse
import csv
import datetime as dt
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = REPO_ROOT / 'BUILD_HISTORY_LOG.csv'
MD_PATH = REPO_ROOT / 'BUILD_HISTORY.md'


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Append a build benchmark entry and compute overall completion automatically.'
    )
    parser.add_argument('--date', default=dt.date.today().isoformat(), help='Build date (YYYY-MM-DD)')
    parser.add_argument('--build-id', help='Optional explicit build ID (e.g. BH-2026-02-28-02)')
    parser.add_argument('--summary', required=True, help='Summary of what was implemented in this build')
    parser.add_argument('--blockers', required=True, help='Known blockers after this build')
    parser.add_argument('--next-focus', required=True, help='Next focus areas')

    parser.add_argument('--epic-a', type=float, required=True, help='Epic A completion %')
    parser.add_argument('--epic-b', type=float, required=True, help='Epic B completion %')
    parser.add_argument('--epic-c', type=float, required=True, help='Epic C completion %')
    parser.add_argument('--epic-d', type=float, required=True, help='Epic D completion %')
    parser.add_argument('--epic-e', type=float, required=True, help='Epic E completion %')
    parser.add_argument('--epic-f', type=float, required=True, help='Epic F completion %')
    parser.add_argument('--epic-g', type=float, required=True, help='Epic G completion %')
    parser.add_argument('--epic-h', type=float, required=True, help='Epic H completion %')

    parser.add_argument(
        '--append-markdown',
        action='store_true',
        help='Also append the entry to the markdown Build History Entries table',
    )
    return parser.parse_args()


def auto_build_id(build_date: str, csv_rows: list[dict[str, str]]) -> str:
    prefix = f'BH-{build_date}-'
    max_seq = 0
    for row in csv_rows:
        build_id = row.get('build_id', '')
        if build_id.startswith(prefix):
            match = re.search(r'-(\d{2})$', build_id)
            if match:
                max_seq = max(max_seq, int(match.group(1)))
    return f'{prefix}{max_seq + 1:02d}'


def ensure_csv_exists() -> None:
    if CSV_PATH.exists():
        return

    CSV_PATH.write_text(
        'build_id,date,overall_completion_percent,epic_a_map,epic_b_actions,epic_c_questions,epic_d_recommendations,epic_e_learning,epic_f_external,epic_g_geospatial,epic_h_security,summary,blockers,next_focus\n',
        encoding='utf-8',
    )


def read_csv_rows() -> list[dict[str, str]]:
    ensure_csv_exists()
    with CSV_PATH.open('r', encoding='utf-8', newline='') as f:
        reader = csv.DictReader(f)
        return list(reader)


def compute_overall(epic_scores: list[float]) -> float:
    return round(sum(epic_scores) / len(epic_scores), 1)


def append_csv_row(row: dict[str, str]) -> None:
    fieldnames = [
        'build_id',
        'date',
        'overall_completion_percent',
        'epic_a_map',
        'epic_b_actions',
        'epic_c_questions',
        'epic_d_recommendations',
        'epic_e_learning',
        'epic_f_external',
        'epic_g_geospatial',
        'epic_h_security',
        'summary',
        'blockers',
        'next_focus',
    ]
    with CSV_PATH.open('a', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writerow(row)


def append_markdown_table_row(row: dict[str, str]) -> bool:
    if not MD_PATH.exists():
        return False

    content = MD_PATH.read_text(encoding='utf-8')
    marker = '## 5) Build History Entries\n'
    idx = content.find(marker)
    if idx == -1:
        return False

    section_start = idx + len(marker)
    section_tail = content[section_start:]

    md_row = (
        f"| {row['build_id']} | {row['date']} | {row['overall_completion_percent']} | "
        f"{row['summary']} | {row['blockers']} | {row['next_focus']} |\n"
    )

    # Insert before next section heading
    next_heading = section_tail.find('\n## ')
    if next_heading == -1:
        new_tail = section_tail + '\n' + md_row
    else:
        insert_at = next_heading + 1
        new_tail = section_tail[:insert_at] + md_row + section_tail[insert_at:]

    MD_PATH.write_text(content[:section_start] + new_tail, encoding='utf-8')
    return True


def main() -> None:
    args = parse_args()
    rows = read_csv_rows()

    epic_scores = [
        args.epic_a,
        args.epic_b,
        args.epic_c,
        args.epic_d,
        args.epic_e,
        args.epic_f,
        args.epic_g,
        args.epic_h,
    ]

    for score in epic_scores:
        if score < 0 or score > 100:
            raise ValueError('Epic scores must be between 0 and 100')

    overall = compute_overall(epic_scores)
    build_id = args.build_id or auto_build_id(args.date, rows)

    row = {
        'build_id': build_id,
        'date': args.date,
        'overall_completion_percent': f'{overall:.1f}',
        'epic_a_map': f'{args.epic_a:g}',
        'epic_b_actions': f'{args.epic_b:g}',
        'epic_c_questions': f'{args.epic_c:g}',
        'epic_d_recommendations': f'{args.epic_d:g}',
        'epic_e_learning': f'{args.epic_e:g}',
        'epic_f_external': f'{args.epic_f:g}',
        'epic_g_geospatial': f'{args.epic_g:g}',
        'epic_h_security': f'{args.epic_h:g}',
        'summary': args.summary,
        'blockers': args.blockers,
        'next_focus': args.next_focus,
    }

    append_csv_row(row)

    markdown_updated = False
    if args.append_markdown:
        markdown_updated = append_markdown_table_row(row)

    print('Build entry logged successfully')
    print(f"Build ID: {build_id}")
    print(f"Overall Completion: {overall:.1f}%")
    print(f"CSV: {CSV_PATH}")
    print(f"Markdown updated: {'yes' if markdown_updated else 'no'}")


if __name__ == '__main__':
    main()
