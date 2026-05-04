"""
Audit view fragment <style> blokova u CARTA-ERP-u i strip duplikate base klasa.
Plus mod za migraciju inline hex boja u theme tokens (var(--...)).

Pokretanje:
    python scripts/audit_view_styles.py                       # samo audit (dry-run)
    python scripts/audit_view_styles.py --apply               # primijeni audit (strip duplikate)
    python scripts/audit_view_styles.py --report-only         # lista preostalih module-spec klasa
    python scripts/audit_view_styles.py --migrate-colors      # dry-run inline hex migracija
    python scripts/audit_view_styles.py --migrate-colors --apply  # primijeni inline hex migracija

Audit mod (default):
- Strip pure base/global selektore: .btn, .modal, .form-control, .card, .tab-btn, itd.
- NE dira: descendantne selektore (.modal-content h3), nested (.my-class .btn),
  module-specific klase

Migrate-colors mod:
- Skenira inline style="..." atribute u HTML body-u
- Zamjenjuje hex literale (npr. #666, #fff3e0) s CSS varijablama iz HEX_TO_VAR_MAP
- Ne dira hex u <style> blokovima
- Ne dira hex koji nije u mapi (semantic colors: NLI orange, brand-blue, modul purple itd.)
- Output: migration_report.txt s mapped count + unmapped lista per fajl

Output: report.txt / migration_report.txt s rezimeom.
"""

import argparse
import re
import sys
import shutil
from pathlib import Path

# Klase koje su definirane u globalnom css/styles.css i ne smiju se duplicirati u modulima.
# Svaka stavka matcha svaki selektor koji POCINJE s ovom klasom + opcionalno
# pseudo-class/pseudo-element (npr. .btn:hover, .btn-primary:disabled, .btn::before).
BASE_CLASSES = {
    # Buttons
    'btn', 'btn-primary', 'btn-secondary', 'btn-success', 'btn-danger',
    'btn-warning', 'btn-info', 'btn-outline', 'btn-sm', 'btn-lg', 'btn-block',
    'btn-group', 'btn-logout', 'btn-password', 'btn-notif',

    # Cards / status cards
    'card', 'card-header', 'card-body', 'card-header-actions',
    'status-card', 'status-card-icon', 'status-card-value', 'status-card-label',
    'status-grid',

    # Modals
    'modal', 'modal-content', 'modal-header', 'modal-body', 'modal-footer',
    'modal-actions', 'modal-close', 'modal-lg', 'modal-sm',

    # Forms
    'form-control', 'form-group', 'form-row',

    # Tabs
    'tab-navigation', 'tab-btn', 'tab-content',

    # Badges
    'badge', 'badge-success', 'badge-warning', 'badge-danger',
    'badge-info', 'badge-primary', 'badge-secondary',

    # Toasts/Loading
    'toast-container', 'toast', 'toast-icon', 'toast-text',
    'toast-success', 'toast-error', 'toast-warning', 'toast-info',
    'loading-overlay', 'loading-content', 'spinner',

    # Login
    'login-container', 'login-box', 'login-logo', 'login-title',
    'login-subtitle', 'pin-input-container', 'pin-input',

    # Layout
    'app-container', 'sidebar', 'sidebar-header', 'sidebar-menu',
    'sidebar-footer', 'main-content', 'top-header', 'top-header-left',
    'top-header-right', 'top-header-center',
    'nav-item', 'nav-icon', 'nav-separator',
    'mobile-header', 'menu-toggle',

    # Tables
    'table-container',

    # Action buttons in tables
    'action-btn',

    # Search/empty
    'search-box', 'empty-state', 'empty-state-icon', 'empty-state-text',
    'date-picker-group', 'date-range-group',

    # User
    'user-info', 'user-name', 'user-role', 'user-avatar', 'icon-btn',
}

# Element selektori koji se ponekad redefiniraju u modulima — strip ako su pure
BASE_ELEMENTS = {'table', 'th', 'td', 'tr', 'thead', 'tbody', 'a', 'body', 'html'}


# === HEX → CSS var mapping (za migrate-colors mod) ===
#
# Mapira SAMO univerzalne boje (greys, status, pasteli) koje su definirane u
# sva 3 theme blocka u css/styles.css. NE dira semantic boje (NLI orange,
# brand-blue, modul-specific purple, itd.) — one ostaju literali.
#
# Sve mapiranje case-insensitive (matches #666 i #666 i #666666 ako alias).
HEX_TO_VAR_MAP = {
    # === GREYS (text colors — preko Layer 2 alias-a) ===
    '#666': 'var(--text-mid)',
    '#666666': 'var(--text-mid)',
    '#555': 'var(--text-mid)',
    '#555555': 'var(--text-mid)',
    '#6c757d': 'var(--text-mid)',
    '#94a3b8': 'var(--text-mid)',

    '#999': 'var(--text-lo)',
    '#999999': 'var(--text-lo)',
    '#888': 'var(--text-lo)',
    '#888888': 'var(--text-lo)',
    '#9e9e9e': 'var(--text-lo)',
    '#bbb': 'var(--text-lo)',
    '#bbbbbb': 'var(--text-lo)',

    '#333': 'var(--text-hi)',
    '#333333': 'var(--text-hi)',

    # === BORDERS (subtle lines) ===
    '#ddd': 'var(--border)',
    '#dddddd': 'var(--border)',
    '#eee': 'var(--border)',
    '#eeeeee': 'var(--border)',
    '#e0e0e0': 'var(--border)',
    '#dee2e6': 'var(--border)',
    '#ccc': 'var(--border)',
    '#cccccc': 'var(--border)',

    # === GREY BACKGROUNDS ===
    '#f5f5f5': 'var(--remap-grey-bg)',
    '#f8f9fa': 'var(--remap-grey-bg)',
    '#fafafa': 'var(--remap-grey-bg)',
    '#efebe9': 'var(--remap-grey-bg)',

    # === PASTEL BACKGROUNDS (status tints) ===
    '#fff3e0': 'var(--remap-warning-bg)',
    '#fff8e1': 'var(--remap-warning-bg)',
    '#fff3cd': 'var(--remap-warning-bg)',
    '#ffe0b2': 'var(--remap-warning-bg)',
    '#ffecb3': 'var(--remap-warning-bg)',

    '#e3f2fd': 'var(--remap-info-bg)',
    '#bbdefb': 'var(--remap-info-bg)',
    '#e0f7fa': 'var(--remap-info-bg)',

    '#e8f5e9': 'var(--remap-success-bg)',
    '#c8e6c9': 'var(--remap-success-bg)',
    '#e0f2f1': 'var(--remap-success-bg)',

    '#ffebee': 'var(--remap-danger-bg)',
    '#ffcdd2': 'var(--remap-danger-bg)',
    '#fce4ec': 'var(--remap-danger-bg)',

    # === STATUS COLORS (semantic — radi i kao text i kao bg) ===
    # Greens → success
    '#2e7d32': 'var(--success)',
    '#43a047': 'var(--success)',
    '#4caf50': 'var(--success)',
    '#388e3c': 'var(--success)',
    '#28a745': 'var(--success)',
    '#1b5e20': 'var(--success)',

    # Reds → danger
    '#c62828': 'var(--danger)',
    '#d32f2f': 'var(--danger)',
    '#e53935': 'var(--danger)',
    '#f44336': 'var(--danger)',
    '#b71c1c': 'var(--danger)',

    # Oranges (warning, NE NLI brand orange) → warning
    '#ff9800': 'var(--warning)',
    '#f57c00': 'var(--warning)',
    '#f57f17': 'var(--warning)',
    '#ffc107': 'var(--warning)',
    '#ffa726': 'var(--warning)',

    # Blues (info / primary, ne Carta brand) → info/primary
    '#1976d2': 'var(--primary)',
    '#1565c0': 'var(--primary)',
    '#2196f3': 'var(--info)',
    '#0d47a1': 'var(--primary-dark)',
    '#0277bd': 'var(--primary)',

    # === DODATNO: rijetke ali sigurne ===
    '#aaa': 'var(--text-lo)',
    '#aaaaaa': 'var(--text-lo)',
    '#757575': 'var(--text-mid)',
    '#fffde7': 'var(--remap-warning-bg)',
    '#ffb74d': 'var(--warning)',
    '#00796b': 'var(--success)',
    '#f3e5f5': 'var(--remap-grey-bg)',  # purple pastel → najbliži neutral bg
    '#e8eaf6': 'var(--remap-info-bg)',  # indigo pastel → info-bg

    # === PURE WHITES & BLACKS — SKIP ===
    # #fff i #000 nikad ne migriramo, oni su literalni i koriste se za
    # konkretan kontrast (npr. status pill text, modal overlay)
}

# Hex koji se NIKAD ne diraju (eksplicit deny — primarno za dokumentaciju):
HEX_NEVER_MIGRATE = {
    '#fff', '#ffffff',         # white literal
    '#000', '#000000',         # black literal
    '#e65100',                 # NLI brand orange (semantic linija)
    '#1e3a5f',                 # Carta dark blue brand
    '#1a237e',                 # indigo (Maintenance/Calendar custom)
    '#9c27b0', '#7b1fa2', '#6a1b9a', '#ba68c8', '#ad1457',  # purple/magenta
    '#667eea', '#764ba2',      # gradient-only indigo/purple
    '#5d4e37',                 # brown (custom)
    '#856404',                 # dark gold (custom)
    '#2c3e50',                 # dark blue-grey
    '#212121',                 # near-black
}


def migrate_inline_colors(html: str, hex_map: dict, log: list, file_name: str = '') -> tuple:
    """Replace hex values inside style="..." attrs with var(...) calls.

    Vraca: (new_html, mapped_count, unmapped_hex_set)

    Skipa hex u HEX_NEVER_MIGRATE i hex koji nije u hex_map (logira ih kao unmapped).
    """
    # Lower-case keys za case-insensitive lookup
    lc_map = {k.lower(): v for k, v in hex_map.items()}
    never = {h.lower() for h in HEX_NEVER_MIGRATE}

    mapped_count = 0
    unmapped = set()

    # Match style="..." or style='...'
    attr_re = re.compile(r'style=([\"\'])([^\"\']*)\1', re.IGNORECASE)
    # Match #hex (3, 4, 6 ili 8 hex digit znakova) within an attribute value.
    # Use word boundary fallback: end with non-hex char or end-of-string.
    hex_in_val = re.compile(r'#[0-9a-fA-F]{3,8}\b')

    def replace_hex(hex_match):
        nonlocal mapped_count
        h = hex_match.group(0).lower()
        if h in never:
            return hex_match.group(0)
        if h in lc_map:
            mapped_count += 1
            log.append({
                'file': file_name,
                'hex': h,
                'replacement': lc_map[h],
            })
            return lc_map[h]
        # Not in map — log as unmapped, keep original
        unmapped.add(h)
        return hex_match.group(0)

    def replace_attr(attr_match):
        quote = attr_match.group(1)
        value = attr_match.group(2)
        # Process per-declaration (split by ;) tako da gradient deklaracije
        # mozemo skipirati cijele — boje unutar linear/radial gradient su
        # gradient stops koji ne smiju biti zamijenjeni s var() (ili razbijemo gradient).
        out_parts = []
        for decl in value.split(';'):
            decl_lower = decl.lower()
            if 'gradient(' in decl_lower:
                # Gradient deklaracija — ne diraj hex unutra
                out_parts.append(decl)
            else:
                out_parts.append(hex_in_val.sub(replace_hex, decl))
        new_value = ';'.join(out_parts)
        return f'style={quote}{new_value}{quote}'

    new_html = attr_re.sub(replace_attr, html)
    return new_html, mapped_count, unmapped


def process_file_color_migration(path, apply: bool):
    """Procesiraj jedan fajl za inline color migration. Vrati rezultat dict."""
    html = path.read_text(encoding='utf-8')
    log = []
    new_html, mapped, unmapped = migrate_inline_colors(
        html, HEX_TO_VAR_MAP, log, file_name=str(path.name)
    )

    if apply and new_html != html:
        bak = path.with_suffix(path.suffix + '.bak')
        if not bak.exists():
            shutil.copy2(path, bak)
        path.write_text(new_html, encoding='utf-8')

    return {
        'path': str(path),
        'mapped': mapped,
        'unmapped': sorted(unmapped),
        'changed': new_html != html,
    }


def run_color_migration(files, apply: bool):
    """Pokreni color migration na listi fajlova. Print summary + write report."""
    results = []
    for f in files:
        if f.suffix == '.bak':
            continue
        try:
            r = process_file_color_migration(f, apply=apply)
            if r['mapped'] > 0 or r['unmapped']:
                results.append(r)
        except Exception as e:
            print(f'  ERROR processing {f}: {e}')

    total_mapped = sum(r['mapped'] for r in results)
    files_changed = sum(1 for r in results if r['changed'])
    all_unmapped = {}
    for r in results:
        for h in r['unmapped']:
            all_unmapped[h] = all_unmapped.get(h, 0) + 1

    print(f'\n=== COLOR MIGRATION REZULTATI ===')
    print(f'Fajlova procesirano:        {len(results)}')
    print(f'Fajlova s promjenama:       {files_changed}')
    print(f'Ukupno mapiranih hex zamjena: {total_mapped}')
    print(f'Unique unmapped hex boja:   {len(all_unmapped)}')
    print()

    print(f'=== TOP 30 UNMAPPED HEX (semantic / brand / nepoznate) ===')
    for h, n in sorted(all_unmapped.items(), key=lambda x: -x[1])[:30]:
        marker = ' [SKIP-listed]' if h in {x.lower() for x in HEX_NEVER_MIGRATE} else ''
        print(f'  {n:5}  {h}{marker}')

    print()
    print(f'=== TOP 15 FAJLOVA PO BROJU ZAMJENA ===')
    sorted_by_mapped = sorted(results, key=lambda r: -r['mapped'])
    for r in sorted_by_mapped[:15]:
        if r['mapped'] == 0:
            continue
        clean_path = r['path'].replace('\\', '/').split('/views/')[-1]
        print(f'  {r["mapped"]:5} zamjena   views/{clean_path}')

    # Write detailed report
    report_path = Path(__file__).parent.parent / 'migration_report.txt'
    with open(report_path, 'w', encoding='utf-8') as fh:
        fh.write(f'=== INLINE COLOR MIGRATION REPORT ===\n')
        fh.write(f'Mode: {"APPLIED" if apply else "DRY-RUN"}\n')
        fh.write(f'Fajlova procesirano: {len(results)}\n')
        fh.write(f'Fajlova s promjenama: {files_changed}\n')
        fh.write(f'Ukupno zamjena: {total_mapped}\n\n')
        fh.write(f'=== UNMAPPED HEX (sve, sortirano po frekvenciji) ===\n')
        for h, n in sorted(all_unmapped.items(), key=lambda x: -x[1]):
            marker = '   [SKIP-listed]' if h in {x.lower() for x in HEX_NEVER_MIGRATE} else ''
            fh.write(f'  {n:5}  {h}{marker}\n')
        fh.write(f'\n=== ZAMJENE PO FAJLU ===\n')
        for r in sorted_by_mapped:
            if r['mapped'] == 0 and not r['unmapped']:
                continue
            clean_path = r['path'].replace('\\', '/').split('/views/')[-1]
            fh.write(f'\nviews/{clean_path}\n')
            fh.write(f'  Mapirano: {r["mapped"]}\n')
            if r['unmapped']:
                fh.write(f'  Unmapped (manual review): {", ".join(r["unmapped"])}\n')
    print(f'\nDetaljni report: {report_path}')

    if not apply:
        print('\n*** DRY RUN MODE — nista nije promijenjeno. Pokrenite s --apply za primjenu. ***')
    else:
        print('\n*** PRIMIJENJENO — backup .bak fajlovi spremljeni za prvi run. ***')


def strip_pseudo(sel: str) -> str:
    """Vraca selektor bez pseudo-class/element (.btn:hover -> .btn, .btn::before -> .btn)."""
    return re.split(r'::?[a-z-]+', sel, maxsplit=1)[0].strip()


def is_base_selector(sel: str) -> bool:
    """True ako je selektor pure-base (samo .baseclass ili .baseclass:hover, ili element pure)."""
    sel = sel.strip()
    if not sel:
        return False
    # Skini pseudo-class/element
    base = strip_pseudo(sel)
    base = base.strip()
    # Provjeri: mora biti tocno jedan selektor (bez razmaka, bez >/+/~)
    if re.search(r'[\s>+~]', base):
        return False
    # Class selector?
    if base.startswith('.'):
        cls_name = base[1:]
        # Provjeri compound class (.btn.disabled) — ako ima . unutra, samo strip ako su SVI dijelovi base
        parts = [p for p in cls_name.split('.') if p]
        return all(p in BASE_CLASSES for p in parts)
    # Element selector?
    return base in BASE_ELEMENTS


def find_style_blocks(html: str):
    """Vrati listu (start_idx, end_idx, content) za svaki <style>...</style> blok."""
    blocks = []
    for m in re.finditer(r'(<style[^>]*>)([\s\S]*?)(</style>)', html, re.IGNORECASE):
        blocks.append({
            'start': m.start(),
            'end': m.end(),
            'open_tag': m.group(1),
            'content': m.group(2),
            'close_tag': m.group(3),
            'open_end': m.start() + len(m.group(1)),
        })
    return blocks


def parse_css_rules(css: str):
    """Naivni parser CSS pravila. Vrati listu (selector_str, full_rule_text, start, end).

    Skipa @rule blokove (@keyframes, @media — ti se NE diraju).
    """
    rules = []
    i = 0
    n = len(css)
    depth = 0  # za nested rules / @media

    while i < n:
        # Skip whitespace & comments
        # Comment /* ... */
        if css[i:i+2] == '/*':
            end = css.find('*/', i+2)
            if end == -1:
                break
            i = end + 2
            continue
        if css[i].isspace():
            i += 1
            continue

        # @at-rule? skip cijeli blok ili stmt
        if css[i] == '@':
            # Nadji prvi { ili ;
            block_start = css.find('{', i)
            stmt_end = css.find(';', i)
            if stmt_end != -1 and (block_start == -1 or stmt_end < block_start):
                # @import-style
                i = stmt_end + 1
                continue
            if block_start == -1:
                break
            # Skip cijeli blok (counting braces)
            d = 1
            j = block_start + 1
            while j < n and d > 0:
                if css[j] == '/' and css[j+1:j+2] == '*':
                    j = css.find('*/', j+2)
                    if j == -1:
                        break
                    j += 2
                    continue
                if css[j] == '{':
                    d += 1
                elif css[j] == '}':
                    d -= 1
                j += 1
            i = j
            continue

        # Normal rule: find selector + { ... }
        rule_start = i
        sel_end = css.find('{', i)
        if sel_end == -1:
            break
        selector = css[i:sel_end].strip()

        # Find matching }
        d = 1
        j = sel_end + 1
        while j < n and d > 0:
            if css[j] == '/' and css[j+1:j+2] == '*':
                j = css.find('*/', j+2)
                if j == -1:
                    break
                j += 2
                continue
            if css[j] == '{':
                d += 1
            elif css[j] == '}':
                d -= 1
            j += 1
        rule_end = j

        rules.append({
            'selector': selector,
            'start': rule_start,
            'end': rule_end,
            'full_text': css[rule_start:rule_end],
        })
        i = rule_end

    return rules


def is_strippable_rule(selector: str) -> bool:
    """True ako su SVI dijelovi comma-separated selektora pure-base."""
    parts = [p.strip() for p in selector.split(',')]
    if not parts:
        return False
    return all(is_base_selector(p) for p in parts)


def process_view_file(path: Path, apply: bool):
    """Procesiraj jedan view file. Vrati rjecnik s rezultatima."""
    html = path.read_text(encoding='utf-8')
    blocks = find_style_blocks(html)

    if not blocks:
        return None

    result = {
        'path': str(path),
        'rel': str(path.relative_to(path.parent.parent.parent)) if 'views' in path.parts else str(path),
        'blocks': len(blocks),
        'stripped_rules': [],
        'kept_rules': [],
        'all_classes_remaining': set(),
    }

    # Build new HTML by processing each block
    new_html_parts = []
    last = 0

    for blk in blocks:
        # Append content before this block
        new_html_parts.append(html[last:blk['open_end']])

        css = blk['content']
        rules = parse_css_rules(css)

        new_css = ''
        prev_end = 0
        for r in rules:
            # Append whitespace/comments between rules
            interlude = css[prev_end:r['start']]
            if is_strippable_rule(r['selector']):
                # SKIP this rule (don't add)
                # But keep the leading whitespace
                new_css += interlude
                result['stripped_rules'].append({
                    'file': str(path.name),
                    'selector': r['selector'],
                    'preview': r['full_text'][:80].replace('\n', ' ')
                })
            else:
                new_css += interlude + r['full_text']
                result['kept_rules'].append(r['selector'])
                # Extract class names for inventory
                for m in re.finditer(r'\.([a-zA-Z][a-zA-Z0-9_-]*)', r['selector']):
                    result['all_classes_remaining'].add(m.group(1))
            prev_end = r['end']
        # Append trailing whitespace after last rule
        new_css += css[prev_end:]

        # Compress multiple consecutive blank lines (cosmetic)
        new_css = re.sub(r'\n{3,}', '\n\n', new_css)

        new_html_parts.append(new_css)
        new_html_parts.append(blk['close_tag'])
        last = blk['end']

    new_html_parts.append(html[last:])
    new_html = ''.join(new_html_parts)

    if apply and new_html != html:
        # Backup
        bak = path.with_suffix(path.suffix + '.bak')
        if not bak.exists():
            shutil.copy2(path, bak)
        path.write_text(new_html, encoding='utf-8')

    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--apply', action='store_true', help='Stvarno primijeni promjene (inače dry-run)')
    ap.add_argument('--report-only', action='store_true', help='Samo lista preostalih module-spec klasa')
    ap.add_argument('--migrate-colors', action='store_true',
                    help='NEW MODE: zamijeni hex u inline style="..." atributima s var(...) tokenima')
    ap.add_argument('--root', default='views', help='Root folder za scan (default: views)')
    args = ap.parse_args()

    root = Path(args.root)
    if not root.is_absolute():
        # Run from project root
        script_dir = Path(__file__).parent
        root = (script_dir.parent / args.root).resolve()

    files = sorted(root.rglob('*.html'))
    print(f'Scan root: {root}')
    print(f'Files found: {len(files)}\n')

    # NEW MODE: inline color migration
    if args.migrate_colors:
        run_color_migration(files, apply=args.apply)
        return

    # POSTOJECI MODE: audit/strip duplikata
    results = []
    for f in files:
        # Preskoci .bak
        if f.suffix == '.bak':
            continue
        try:
            r = process_view_file(f, apply=args.apply)
            if r is not None:
                results.append(r)
        except Exception as e:
            print(f'  ERROR processing {f}: {e}')

    # Summary
    total_stripped = sum(len(r['stripped_rules']) for r in results)
    total_kept = sum(len(r['kept_rules']) for r in results)

    print(f'\n=== AUDIT REZULTATI ===')
    print(f'Files with <style> blocks: {len(results)}')
    print(f'Total rules stripped (duplicates of global): {total_stripped}')
    print(f'Total rules kept (module-specific): {total_kept}')
    print()

    if args.report_only:
        print('\n=== PREOSTALE MODULE-SPEC KLASE PO FAJLU ===')
        for r in results:
            if r['all_classes_remaining']:
                clean_path = r['path'].replace('\\', '/').split('/views/')[-1]
                cls_list = sorted(r['all_classes_remaining'])
                print(f'\n{clean_path} ({len(cls_list)} klasa):')
                # Print in chunks of 6 per line
                for i in range(0, len(cls_list), 6):
                    print('  ' + ', '.join(cls_list[i:i+6]))
        return

    print('=== TOP 20 MODULA PO BROJU STRIPPED RULES ===')
    sorted_results = sorted(results, key=lambda r: -len(r['stripped_rules']))
    for r in sorted_results[:20]:
        if not r['stripped_rules']:
            continue
        clean_path = r['path'].replace('\\', '/').split('/views/')[-1]
        print(f'\n  views/{clean_path}: {len(r["stripped_rules"])} pravila za strip')
        for s in r['stripped_rules'][:8]:
            print(f'    - {s["selector"]}')
        if len(r['stripped_rules']) > 8:
            print(f'    ... +{len(r["stripped_rules"])-8} more')

    if not args.apply:
        print('\n*** DRY RUN MODE — nista nije promijenjeno. Pokrenite s --apply za primjenu. ***')
    else:
        print('\n*** PRIMIJENJENO — backup .bak fajlovi spremljeni za prvi run. ***')


if __name__ == '__main__':
    main()
