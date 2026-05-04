"""
Generira css/icons.css iz Lucide-style SVG path mape.

Koristi mask-image pristup tako da ikone slijede currentColor (potrebno za sidebar
gdje se boja mijenja na hover/active state).

Pokreni iz korijena projekta:
    python scripts/generate_icons_css.py

Nakon promjene icons mape, pokreni opet i CSS se prepise.

VAŽNO za Pravilo 25 (CLAUDE.md): URL-encoding (<>=>%3C%3E) je obavezan jer
VSCode Live Server lomi script tag kad nađe inline </svg>. Ovaj generator
forsira encoding pa je sigurno.
"""
import os
import urllib.parse

# ====================================================================
# Icon set — Lucide-style line icons (lucide.dev, MIT licence).
# Svaka stavka je: 'icon-name': 'inner_svg_paths'
# Boilerplate (xmlns, viewBox, stroke params) se dodaje automatski.
# ====================================================================
ICONS = {
    # ─── Sidebar ikone ───
    'dashboard': "<rect width='7' height='9' x='3' y='3' rx='1'/><rect width='7' height='5' x='14' y='3' rx='1'/><rect width='7' height='9' x='14' y='12' rx='1'/><rect width='7' height='5' x='3' y='16' rx='1'/>",
    'users': "<path d='M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2'/><circle cx='9' cy='7' r='4'/><path d='M22 21v-2a4 4 0 0 0-3-3.87'/><path d='M16 3.13a4 4 0 0 1 0 7.75'/>",
    'wallet': "<path d='M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2'/><path d='M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4'/><circle cx='17' cy='13' r='1'/>",
    'trending-up': "<polyline points='22 7 13.5 15.5 8.5 10.5 2 17'/><polyline points='16 7 22 7 22 13'/>",
    'clipboard': "<rect width='8' height='4' x='8' y='2' rx='1' ry='1'/><path d='M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2'/>",
    'clipboard-list': "<rect width='8' height='4' x='8' y='2' rx='1' ry='1'/><path d='M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2'/><path d='M12 11h4'/><path d='M12 16h4'/><circle cx='8.5' cy='11' r='.5' fill='currentColor'/><circle cx='8.5' cy='16' r='.5' fill='currentColor'/>",
    'clock': "<circle cx='12' cy='12' r='10'/><polyline points='12 6 12 12 16 14'/>",
    'check-circle': "<path d='M22 11.08V12a10 10 0 1 1-5.93-9.14'/><polyline points='22 4 12 14.01 9 11.01'/>",
    'package': "<path d='M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z'/><path d='M3.3 7 12 12l8.7-5'/><path d='M12 22V12'/>",
    'warehouse': "<path d='M22 8.35V20a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8.35A2 2 0 0 1 3.26 6.5l8-3.2a2 2 0 0 1 1.48 0l8 3.2A2 2 0 0 1 22 8.35Z'/><path d='M6 18h12'/><path d='M6 14h12'/><path d='M6 10v8'/><path d='M18 10v8'/>",
    'scissors': "<circle cx='6' cy='6' r='3'/><path d='M8.12 8.12 12 12'/><path d='M20 4 8.12 15.88'/><circle cx='6' cy='18' r='3'/><path d='M14.8 14.8 20 20'/>",
    'printer': "<polyline points='6 9 6 2 18 2 18 9'/><path d='M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2'/><rect width='12' height='8' x='6' y='14'/>",
    'cylinder': "<ellipse cx='12' cy='5' rx='9' ry='3'/><path d='M3 5v14a9 3 0 0 0 18 0V5'/>",
    'layers': "<polygon points='12 2 2 7 12 12 22 7 12 2'/><polyline points='2 17 12 22 22 17'/><polyline points='2 12 12 17 22 12'/>",
    'cog': "<path d='M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z'/><circle cx='12' cy='12' r='3'/>",
    'bar-chart-2': "<line x1='18' x2='18' y1='20' y2='10'/><line x1='12' x2='12' y1='20' y2='4'/><line x1='6' x2='6' y1='20' y2='14'/>",
    'bar-chart': "<path d='M3 3v18h18'/><path d='M7 16V9'/><path d='M12 16V5'/><path d='M17 16v-4'/>",
    'truck': "<path d='M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2'/><path d='M15 18H9'/><path d='M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.624l-3.48-4.35A1 1 0 0 0 17.52 8H14'/><circle cx='17' cy='18' r='2'/><circle cx='7' cy='18' r='2'/>",
    'droplet': "<path d='M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z'/>",
    'zap': "<polygon points='13 2 3 14 12 14 11 22 21 10 12 10 13 2'/>",
    'hard-hat': "<path d='M2 18a1 1 0 0 0 1 1h18a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1H3a1 1 0 0 0-1 1z'/><path d='M10 10V5a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1v5'/><path d='M4 15v-3a6 6 0 0 1 6-6'/><path d='M14 6a6 6 0 0 1 6 6v3'/>",
    'calendar': "<rect width='18' height='18' x='3' y='4' rx='2' ry='2'/><line x1='16' x2='16' y1='2' y2='6'/><line x1='8' x2='8' y1='2' y2='6'/><line x1='3' x2='21' y1='10' y2='10'/>",
    'palette': "<circle cx='13.5' cy='6.5' r='.5' fill='currentColor'/><circle cx='17.5' cy='10.5' r='.5' fill='currentColor'/><circle cx='8.5' cy='7.5' r='.5' fill='currentColor'/><circle cx='6.5' cy='12.5' r='.5' fill='currentColor'/><path d='M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2z'/>",
    'video': "<path d='m22 8-6 4 6 4V8Z'/><rect width='14' height='12' x='2' y='6' rx='2' ry='2'/>",
    'wrench': "<path d='M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z'/>",
    'landmark': "<line x1='3' x2='21' y1='22' y2='22'/><line x1='6' x2='6' y1='18' y2='11'/><line x1='10' x2='10' y1='18' y2='11'/><line x1='14' x2='14' y1='18' y2='11'/><line x1='18' x2='18' y1='18' y2='11'/><polygon points='12 2 20 7 4 7'/>",
    'settings': "<path d='M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z'/><circle cx='12' cy='12' r='3'/>",
    'check-square': "<polyline points='9 11 12 14 22 4'/><path d='M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11'/>",
    # ─── ISO 9001 ikone ───
    'shield-check': "<path d='M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z'/><path d='m9 12 2 2 4-4'/>",
    'file-text': "<path d='M14.5 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7.5L14.5 2z'/><polyline points='14 2 14 8 20 8'/><line x1='16' x2='8' y1='13' y2='13'/><line x1='16' x2='8' y1='17' y2='17'/><line x1='10' x2='8' y1='9' y2='9'/>",
    'alert-triangle': "<path d='m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z'/><path d='M12 9v4'/><circle cx='12' cy='17' r='.5' fill='currentColor'/>",
    'refresh-cw': "<path d='M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8'/><path d='M21 3v5h-5'/><path d='M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16'/><path d='M3 21v-5h5'/>",
    'target': "<circle cx='12' cy='12' r='10'/><circle cx='12' cy='12' r='6'/><circle cx='12' cy='12' r='2'/>",
    'workflow': "<rect width='8' height='8' x='3' y='3' rx='2'/><path d='M7 11v4a2 2 0 0 0 2 2h4'/><rect width='8' height='8' x='13' y='13' rx='2'/>",
    'globe': "<circle cx='12' cy='12' r='10'/><line x1='2' x2='22' y1='12' y2='12'/><path d='M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z'/>",
    'search': "<circle cx='11' cy='11' r='8'/><line x1='21' x2='16.65' y1='21' y2='16.65'/>",
    'building-2': "<path d='M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z'/><path d='M6 12H4a2 2 0 0 0-2 2v6a2 2 0 0 0 2 2h2'/><path d='M18 9h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-2'/><path d='M10 6h4'/><path d='M10 10h4'/><path d='M10 14h4'/><path d='M10 18h4'/>",
    'graduation-cap': "<path d='M22 10v6'/><path d='M2 10l10-5 10 5-10 5z'/><path d='M6 12v5c3 3 9 3 12 0v-5'/>",
    'ruler': "<path d='M21.3 8.7 8.7 21.3c-1 1-2.5 1-3.4 0l-2.6-2.6c-1-1-1-2.5 0-3.4L15.3 2.7c1-1 2.5-1 3.4 0l2.6 2.6c1 .9 1 2.4 0 3.4z'/><path d='m7.5 10.5 2 2'/><path d='m10.5 7.5 2 2'/><path d='m13.5 4.5 2 2'/><path d='m4.5 13.5 2 2'/>",
    'mail-warning': "<path d='M22 10.5V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v12c0 1.1.9 2 2 2h8'/><path d='m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7'/><path d='M20 14v4'/><circle cx='20' cy='21' r='.5' fill='currentColor'/>",
    'briefcase': "<rect width='20' height='14' x='2' y='7' rx='2' ry='2'/><path d='M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16'/>",
    # ─── Pomoćne / razno ───
    'plus': "<line x1='12' x2='12' y1='5' y2='19'/><line x1='5' x2='19' y1='12' y2='12'/>",
    'pencil': "<path d='M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z'/>",
    'trash': "<path d='M3 6h18'/><path d='M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6'/><path d='M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2'/>",
    'download': "<path d='M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'/><polyline points='7 10 12 15 17 10'/><line x1='12' x2='12' y1='15' y2='3'/>",
    'upload': "<path d='M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4'/><polyline points='17 8 12 3 7 8'/><line x1='12' x2='12' y1='3' y2='15'/>",
    'chevron-right': "<polyline points='9 18 15 12 9 6'/>",
    'eye': "<path d='M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z'/><circle cx='12' cy='12' r='3'/>",
    'check': "<polyline points='20 6 9 17 4 12'/>",
    'x': "<line x1='18' x2='6' y1='6' y2='18'/><line x1='6' x2='18' y1='6' y2='18'/>",
    'bot': "<path d='M12 8V4H8'/><rect width='16' height='12' x='4' y='8' rx='2'/><path d='M2 14h2'/><path d='M20 14h2'/><circle cx='9' cy='13' r='1' fill='currentColor'/><circle cx='15' cy='13' r='1' fill='currentColor'/><path d='M9 17h6'/>",
    'user': "<path d='M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2'/><circle cx='12' cy='7' r='4'/>",
    'gauge': "<path d='m12 14 4-4'/><path d='M3.34 19a10 10 0 1 1 17.32 0'/>",
    'mail': "<rect width='20' height='16' x='2' y='4' rx='2'/><path d='m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7'/>",
    'tag': "<path d='M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z'/><line x1='7' x2='7.01' y1='7' y2='7'/>",
}

SVG_TEMPLATE = (
    "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' "
    "fill='none' stroke='black' stroke-width='2' stroke-linecap='round' "
    "stroke-linejoin='round'>{paths}</svg>"
)


def url_encode_svg(svg: str) -> str:
    """Forsiraj URL encoding za <, >, /, # da Live Server ne lomi script tag.
    (CLAUDE.md Pravilo 25.) Ostavi single quotes, =, : nepromijenjene jer
    su čitljivi i validni u data URL-u.
    """
    return (
        svg
        .replace('%', '%25')
        .replace('<', '%3C')
        .replace('>', '%3E')
        .replace('#', '%23')
        .replace('"', '%22')
    )


def main() -> None:
    out_lines = [
        "/* ============================================================",
        " * CARTA-ERP — SVG icon set (Lucide-style, MIT licence)",
        " * ============================================================",
        " * Generirano s scripts/generate_icons_css.py — NE ureduj rucno!",
        " * Za promjenu: dodaj ikonu u ICONS map u skripti pa pokreni:",
        " *   python scripts/generate_icons_css.py",
        " *",
        " * Pristup: mask-image + background-color: currentColor",
        " * - ikona slijedi text color (radi za hover, active, sve)",
        " * - URL-encoded SVG (Pravilo 25 — Live Server bug zaobilaznica)",
        " * ",
        " * Korištenje:",
        " *   <span class=\"svg-icon svg-icon-NAME\"></span>",
        " *   <span class=\"svg-icon svg-icon-NAME\" style=\"width:18px;height:18px\"></span>",
        " * ============================================================ */",
        "",
        ".svg-icon {",
        "  display: inline-block;",
        "  width: 20px;",
        "  height: 20px;",
        "  background-color: currentColor;",
        "  -webkit-mask-repeat: no-repeat;",
        "  mask-repeat: no-repeat;",
        "  -webkit-mask-position: center;",
        "  mask-position: center;",
        "  -webkit-mask-size: contain;",
        "  mask-size: contain;",
        "  vertical-align: middle;",
        "  flex-shrink: 0;",
        "}",
        "",
        "/* Velicinske varijante */",
        ".svg-icon-xs { width: 14px; height: 14px; }",
        ".svg-icon-sm { width: 16px; height: 16px; }",
        ".svg-icon-md { width: 24px; height: 24px; }",
        ".svg-icon-lg { width: 32px; height: 32px; }",
        ".svg-icon-xl { width: 48px; height: 48px; }",
        "",
        "/* ─── Ikone ─── */",
    ]

    for name in sorted(ICONS.keys()):
        paths = ICONS[name]
        svg = SVG_TEMPLATE.format(paths=paths)
        encoded = url_encode_svg(svg)
        url = f'url("data:image/svg+xml;utf8,{encoded}")'
        out_lines.append(
            f".svg-icon-{name} {{ "
            f"-webkit-mask-image: {url}; "
            f"mask-image: {url}; "
            f"}}"
        )

    # App-specific override-i — kontekstualne veličine ikona unutar postojećih
    # CARTA-ERP klasa. Stavljeno OVDJE (a ne u styles.css) jer je dio icon
    # sistema i ovisi o icons.css; ako se icons.css izbrise, ovi nemaju smisla.
    out_lines += [
        "",
        "/* ─── App-specific kontekst overridei ─── */",
        "/* Sidebar — nav-icon je 24px po styles.css; kad je SVG ikona, malo manja */",
        ".nav-icon.svg-icon { width: 22px; height: 22px; }",
        "",
        "/* Mobile bottom nav (3 tab-a u nekim view-ovima) — vece ikone */",
        ".mobile-nav-item .svg-icon { width: 24px; height: 24px; margin-bottom: 3px; }",
        "",
        "/* Mobile burger menu lijeva ikona */",
        ".menu-icon.svg-icon { width: 22px; height: 22px; margin-right: 12px; }",
        "",
        "/* Sidebar logo (gornji left header) — koristi se cesto jedna velika ikona */",
        ".sidebar-logo .svg-icon { width: 32px; height: 32px; color: white; }",
        "",
        "/* Status KPI kartice — emoji je bio font-size: 2em, SVG mora biti slicne velicine */",
        ".status-card-icon .svg-icon { width: 36px; height: 36px; }",
        "",
        "/* Status KPI bojanje koristi var(--primary) za ikone neutralnih kartica */",
        ".status-card .svg-icon { color: var(--primary); }",
        ".status-card.warning .svg-icon { color: var(--warning, #f57f17); }",
        ".status-card.success .svg-icon { color: var(--success, #2e7d32); }",
        ".status-card.danger .svg-icon { color: var(--danger, #c62828); }",
        ".status-card.info .svg-icon { color: var(--info, #1565c0); }",
        "",
    ]

    out_path = os.path.join(
        os.path.dirname(__file__), '..', 'css', 'icons.css'
    )
    out_path = os.path.normpath(out_path)
    with open(out_path, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(out_lines))

    print(f"OK — {len(ICONS)} ikona generirano u {out_path}")


if __name__ == '__main__':
    main()
