"""
Bulk import postojecih ISO 9001 dokumenata iz Windows foldera u Supabase.

Skenira `ISO 9001/2025/` (default) ili drugi folder, prepoznaje tip dokumenta
po prefiksu filename-a (OB_, UP_, PK_, RU_, Politika, Plan, Procjena rizika...),
upload-a file u Supabase Storage bucket `iso-documents`, i kreira/zapis u
`iso_documents` + `iso_document_versions` (v1.0 Published).

Idempotentno: ako dokument s istim `code` vec postoji, **preskace** (ne overwriteam).
Mozes pokrenuti vise puta sigurno.

POKRETANJE:
    # iz korijena projekta:
    python scripts/import_iso_2025.py
    python scripts/import_iso_2025.py --folder "ISO 9001/2024"
    python scripts/import_iso_2025.py --dry-run     # samo log, bez upload-a
    python scripts/import_iso_2025.py --status Draft   # default je Published

ZAHTJEVI:
    pip install supabase python-dotenv

ENV VARIJABLE:
    SUPABASE_URL          - npr https://gusudzydgofdcywmvwbh.supabase.co
    SUPABASE_SERVICE_KEY  - service_role key (NE anon!) — treba bypass RLS
                            (alternativno SUPABASE_ANON_KEY ako su RLS politike permissive)

VIDI:
    sql/iso_schema_v1.sql za schemu
    CLAUDE.md Pravilo 26 za icon konvenciju
"""
from __future__ import annotations

import argparse
import datetime as dt
import mimetypes
import os
import re
import sys
import unicodedata
from pathlib import Path

try:
    from supabase import create_client, Client
except ImportError:
    print("FATAL: supabase paket nije instaliran. Pokreni:")
    print("    pip install supabase")
    sys.exit(1)

# Default config (override-able)
PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_ISO_FOLDER = PROJECT_ROOT / "ISO 9001" / "2025"
SUPABASE_URL_DEFAULT = "https://gusudzydgofdcywmvwbh.supabase.co"
BUCKET = "iso-documents"

# Skip files (sistemski/temp)
SKIP_PATTERNS = ["~$", ".tmp", "Thumbs.db", "desktop.ini", ".DS_Store"]


# ============================================================
# Doc type detection — prepoznavanje iz filename-a
# ============================================================
def detect_doc(fname: str) -> tuple[str, str, str, str]:
    """Vrati (code, doc_type, category, title) iz filename-a.
    Code je glavna sifra (OB-05, UP-04, PK-01, POL-01...).
    """
    base = Path(fname).stem  # bez ekstenzije
    base_lower = base.lower()

    # OB_05, OB-05, OB_05_01 itd → kod = OB-05
    m = re.match(r"^(OB)[\s_-]+(\d+)(?:[\s_-]+(\d+))?", base, re.IGNORECASE)
    if m:
        code = f"OB-{m.group(2).zfill(2)}"
        if m.group(3):
            code += f"-{m.group(3)}"
        title = re.sub(r"^(OB)[\s_-]+\d+(?:[\s_-]+\d+)?[\s_-]*", "", base, flags=re.IGNORECASE).strip()
        return code, "Obrazac", "kvaliteta", title or "Obrazac"

    # UP_02, UP-03A, UP_02UPUTSTVO itd
    # Slovo varijante (A/B/C/...) prihvaca SAMO ako je sljedeci znak separator ili kraj.
    # "UP_02UPUTSTVO" → UP-02 (jer 'U' je iza '02' ali nakon U je P-letter, ne separator)
    # "UP_03A UPUTSTVO" → UP-03A (jer iza A je razmak)
    # "UP_03B"          → UP-03B (jer iza B je kraj)
    m = re.match(r"^(UP)[\s_-]+(\d+)(?:([A-Za-z])(?=[\s_-]|$))?", base, re.IGNORECASE)
    if m:
        suffix = m.group(2) + (m.group(3) or '').upper()
        code = f"UP-{suffix}"
        title = re.sub(r"^(UP)[\s_-]+\d+([A-Za-z](?=[\s_-]|$))?[\s_-]*", "", base, flags=re.IGNORECASE).strip()
        return code, "Uputstvo", "sigurnost", title or "Uputstvo"

    # PK 01, PK_01
    m = re.match(r"^(PK)[\s_-]+(\d+)", base, re.IGNORECASE)
    if m:
        code = f"PK-{m.group(2).zfill(2)}"
        title = re.sub(r"^(PK)[\s_-]+\d+[\s_-]*", "", base, flags=re.IGNORECASE).strip()
        return code, "Prirucnik", "kvaliteta", title or "Prirucnik kvalitete"

    # RU-01, RU_01
    m = re.match(r"^(RU)[\s_-]+(\d+)(?:[\s_-]+(\d+))?", base, re.IGNORECASE)
    if m:
        code = f"RU-{m.group(2).zfill(2)}"
        if m.group(3):
            code += f"-{m.group(3)}"
        title = re.sub(r"^(RU)[\s_-]+\d+(?:[\s_-]+\d+)?[\s_-]*", "", base, flags=re.IGNORECASE).strip()
        return code, "Radna_uputa", "proizvodnja", title or "Radna uputa"

    # UR_01 (Ulaz robe)
    m = re.match(r"^(UR)[\s_-]+(\d+)", base, re.IGNORECASE)
    if m:
        code = f"UR-{m.group(2).zfill(2)}"
        title = re.sub(r"^(UR)[\s_-]+\d+[\s_-]*", "", base, flags=re.IGNORECASE).strip()
        return code, "Obrazac", "skladiste", title or "Ulaz robe"

    # Politika kvalitete
    if "politika" in base_lower and "kvalitet" in base_lower:
        return "POL-01", "Politika", "kvaliteta", "Politika kvalitete"

    # Procjena rizika
    if "procjena rizika" in base_lower or "popis mjera" in base_lower:
        cat = "sigurnost"
        if "popis mjera" in base_lower:
            return "POPIS-MJERA", "Plan", cat, "Popis mjera ZNR"
        return "PR-ZNR", "Plan", cat, "Procjena rizika"

    # Plan održavanja / podmazivanja / poslova
    if "plan održavanja" in base_lower or "plan odrzavanja" in base_lower:
        return "PLAN-ODR", "Plan", "odrzavanje", "Plan odrzavanja"
    if "plan podmazivanja" in base_lower:
        return "PLAN-POD", "Plan", "odrzavanje", "Plan podmazivanja"
    if "plan poslova" in base_lower and "remont" in base_lower:
        return "PLAN-REMONT", "Plan", "odrzavanje", "Plan poslova remont"
    if "plan poslova" in base_lower and "održav" in base_lower:
        return "PLAN-OD-POS", "Plan", "odrzavanje", "Plan poslova na odrzavanju"

    # Kontrola vreca u smjeni
    if "kontrola vre" in base_lower:
        return "KV-SMJENA", "Obrazac", "proizvodnja", "Kontrola vreca u smjeni"

    # Dnevnik rada
    if "dnevnik rada" in base_lower:
        clean = re.sub(r"^dnevnik rada[\s_-]*", "", base_lower)
        return f"DNEVNIK-{slugify(clean).upper()}", "Obrazac", "odrzavanje", base

    # Anketa zadovoljstva
    if "anketa" in base_lower or "zadovoljstv" in base_lower:
        return "ANK-KUP", "Obrazac", "kvaliteta", "Anketa zadovoljstva kupaca"
    if "rezultati ankete" in base_lower:
        return "REZ-ANK-KUP", "Izvjesce", "kvaliteta", "Rezultati ankete zadovoljstva kupaca"

    # Slijed dokumentacije zavrsenog projekta
    if "slijed dokumentacije" in base_lower:
        return "SLIJED-DOK", "Obrazac", "kvaliteta", "Slijed dokumentacije zavrsenog projekta"

    # Zbrinjavanje otpadne plastike/papira
    if "zbrinjavanje" in base_lower:
        if "plast" in base_lower:
            return "ZBR-PLAST", "Plan", "okolis", "Zbrinjavanje otpadne plastike"
        if "papir" in base_lower:
            return "ZBR-PAP", "Plan", "okolis", "Zbrinjavanje otpadnog papira"

    # Osposobljavanja, uvjerenja, certifikati (PDF) — koristi diferencijalne kljucne rijeci
    # Preskoci samo "osposobljavanje"/"uvjerenje" (vec u prefiksu OSP-) i prijedloge.
    # Zadrzi "rad"/"stroj"/"podrucja" jer su to esencijalne informacije.
    if "osposobljavanj" in base_lower or "uvjerenj" in base_lower:
        tokens = re.findall(r"[a-zA-ZčćšžđČĆŠŽĐ]+", base)
        skip = {"iz","za","na","i","o","u","ali","tako","jer","kao","sve","sa","te","ili","ne",
                "osposobljavanje","osposobljavanju","uvjerenje","uvjerenja","uvjerenju"}
        keep = [t for t in tokens if len(t) > 2 and t.lower() not in skip][:2]
        suffix = slugify("-".join(keep))[:18].upper() or "GEN"
        return f"OSP-{suffix}", "Izvjesce", "sigurnost", base

    # Opis radnih mjesta
    if "opis radnih mjesta" in base_lower:
        return "OPIS-RM", "Obrazac", "administracija", "Opis radnih mjesta"

    # Imenovanje kvaliteta
    if "imenovanje" in base_lower and "kvalitet" in base_lower:
        return "IMEN-KV", "Izvjesce", "kvaliteta", "Imenovanje predstavnika kvalitete"

    # Default — neprepoznato → Drugo
    return f"GEN-{slugify(base)[:24].upper()}", "Drugo", "kvaliteta", base


def slugify(s: str) -> str:
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r"[^a-zA-Z0-9]+", "-", s).strip("-").lower()
    return s[:60]


# ============================================================
# Supabase init
# ============================================================
def get_client(args) -> Client:
    url = os.environ.get("SUPABASE_URL", SUPABASE_URL_DEFAULT)
    key = os.environ.get("SUPABASE_SERVICE_KEY") or os.environ.get("SUPABASE_ANON_KEY")
    if not key:
        print("FATAL: Postavi SUPABASE_SERVICE_KEY ili SUPABASE_ANON_KEY env varijablu.")
        print("       service_role key bypassa RLS i siguran je za bulk operacije.")
        print("       anon key radi ako su RLS politike permissive (za iso_* tablice jesu).")
        sys.exit(1)
    return create_client(url, key)


# ============================================================
# Main
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Bulk import ISO 9001 dokumenata u CARTA-ERP.")
    parser.add_argument(
        "--folder", default=str(DEFAULT_ISO_FOLDER),
        help=f"Folder za skeniranje (default: {DEFAULT_ISO_FOLDER})"
    )
    parser.add_argument(
        "--status", default="Published",
        choices=["Draft", "Review", "Published"],
        help="Inicijalni status novih dokumenata (default: Published)"
    )
    parser.add_argument("--dry-run", action="store_true", help="Samo log, bez upload-a u Supabase")
    parser.add_argument("--limit", type=int, default=0, help="Stani nakon N dokumenata (0 = svi)")
    args = parser.parse_args()

    folder = Path(args.folder)
    if not folder.exists():
        print(f"FATAL: Folder ne postoji: {folder}")
        sys.exit(1)

    print(f"[import] Skenira: {folder}")
    print(f"[import] Status novih: {args.status}")
    print(f"[import] Dry-run: {args.dry_run}")
    print()

    # Skeniraj sve datoteke (ne i pod-foldere — flat scan da izbjegnemo Plan održavanja unutarnji folder)
    files = []
    for f in sorted(folder.iterdir()):
        if not f.is_file():
            continue
        if any(p in f.name for p in SKIP_PATTERNS):
            continue
        files.append(f)

    print(f"[import] Pronadjeno {len(files)} datoteka.")
    print()

    sb = None if args.dry_run else get_client(args)

    # Provjeri postojece kodove (idempotency)
    existing_codes = set()
    if sb is not None:
        try:
            res = sb.table("iso_documents").select("code").limit(10000).execute()
            existing_codes = {r["code"] for r in (res.data or [])}
            print(f"[import] Vec u bazi: {len(existing_codes)} dokumenata.")
            print()
        except Exception as e:
            print(f"WARN: ne mogu citat postojece dokumente — {e}")

    inserted = 0
    skipped_existing = 0
    skipped_unknown = 0
    failed = 0

    for f in files:
        if args.limit and (inserted + skipped_existing) >= args.limit:
            break

        code, doc_type, category, title = detect_doc(f.name)

        if code in existing_codes:
            print(f"  SKIP (vec postoji)  {code:24s}  {f.name}")
            skipped_existing += 1
            continue

        # Default review za 12 mjeseci
        next_review = (dt.date.today() + dt.timedelta(days=365)).isoformat()

        print(f"  IMPORT             {code:24s}  ({doc_type:12s})  {f.name}  ({f.stat().st_size:,} B)")

        if args.dry_run:
            inserted += 1
            existing_codes.add(code)
            continue

        try:
            # 1) Insert iso_documents
            doc_row = {
                "code": code,
                "title": title,
                "doc_type": doc_type,
                "category": category,
                "current_version": "1.0",
                "status": args.status,
                "classification": "Interni",
                "review_interval_months": 12,
                "next_review_date": next_review,
                "legacy_filename": f.name,
                "storage_folder": slugify(code),
                "description": f"Importirano iz: {folder.name}/{f.name}",
            }
            doc_res = sb.table("iso_documents").insert(doc_row).execute()
            doc_id = doc_res.data[0]["id"]

            # 2) Upload file u storage
            mime = mimetypes.guess_type(f.name)[0] or "application/octet-stream"
            safe_name = re.sub(r"[^a-zA-Z0-9._-]", "_", f.name)
            storage_path = f"{slugify(code)}/v1.0/{safe_name}"

            with open(f, "rb") as fh:
                sb.storage.from_(BUCKET).upload(
                    path=storage_path,
                    file=fh.read(),
                    file_options={"content-type": mime, "upsert": "true"},
                )

            # 3) Insert iso_document_versions
            version_row = {
                "document_id": doc_id,
                "version": "1.0",
                "file_path": storage_path,
                "file_size_bytes": f.stat().st_size,
                "file_mime_type": mime,
                "changelog": f"Inicijalni import iz {folder.name}",
                "is_current": True,
            }
            sb.table("iso_document_versions").insert(version_row).execute()

            inserted += 1
            existing_codes.add(code)

        except Exception as e:
            print(f"    !! GRESKA: {e}")
            failed += 1
            # Pokusaj ocistiti dokument bez verzije
            try:
                sb.table("iso_documents").delete().eq("code", code).execute()
            except Exception:
                pass

    print()
    print("=" * 60)
    print(f"  Importirano:           {inserted}")
    print(f"  Preskoceno (postoji):  {skipped_existing}")
    print(f"  Preskoceno (nepoznat): {skipped_unknown}")
    print(f"  Greske:                {failed}")
    print("=" * 60)

    if args.dry_run:
        print("(DRY-RUN — nista nije zapisano u bazu. Pokreni bez --dry-run za pravi import.)")


if __name__ == "__main__":
    main()
