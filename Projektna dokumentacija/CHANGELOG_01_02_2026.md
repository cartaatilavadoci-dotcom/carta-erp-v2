# CARTA ERP - Changelog 01. Veljače 2026

## 📋 Pregled

Implementiran sistem **rezervacija POP-a** koji rješava problem nekonzistentnog stanja zaliha između Tuber i Bottomer modula.

---

## 🎯 Problem

**Simptom:**
- U bazi prikazano dosta POP-a na stanju (`quantity_in_stock`)
- U stvarnosti POP je potrošen

**Uzrok:**
- Bottomer-slagač AUTOMATSKI skida POP sa stanja pri dodavanju GOP paleta
- Tuber operateri ne unose male količine POP-a odmah
- Rezultat: `quantity_in_stock` nekonzistentan - pokazuje "duhove" u inventaru

---

## ✅ Rješenje - Sistem Rezervacija

### Nova funkcionalnost

**Bottomer-slagač:**
- Ako NEMA dovoljno POP-a na skladištu → REZERVIRA razliku
- `quantity_reserved` se povećava
- Operater dobiva upozorenje: "📌 Rezervirano X kom - automatski će se skinuti"

**Tuber:**
- Pri dodavanju novog POP-a → automatski provjerava rezervacije
- Skida rezervacije (FIFO pristup)
- Smanjuje `quantity_in_stock` na novom POP-u
- Operater dobiva obavijest: "📌 Automatski skinuto X kom za Bottomer"

---

## 🗄️ Promjene u bazi

### Nove kolone u `prod_inventory_pop`

```sql
-- 1. Rezervirana količina
quantity_reserved INTEGER DEFAULT 0

-- 2. Dostupna količina (GENERATED kolona)
quantity_available INTEGER
GENERATED ALWAYS AS (quantity_in_stock - COALESCE(quantity_reserved, 0)) STORED
```

### Indeksi

```sql
-- Za brže pretraživanje rezervacija
CREATE INDEX idx_pop_reserved
ON prod_inventory_pop(work_order_number)
WHERE quantity_reserved > 0;

CREATE INDEX idx_pop_wo_status_reserved
ON prod_inventory_pop(work_order_number, status, quantity_reserved);

CREATE INDEX idx_pop_available
ON prod_inventory_pop(quantity_available)
WHERE quantity_available > 0;
```

---

## 💻 Promjene u kodu

### 1. `bottomer-slagac.html`

**Modificirana funkcija:** `skiniPOPSaStanja()` (linija ~2612)

**Dodano:**
- Logika za rezervaciju preostale količine
- Ažuriranje `quantity_reserved` na postojećim POP-ovima
- Nova upozorenja s emoji ikonom 📌

### 2. `tuber.html`

**Nova funkcija:** `tuberSkiniRezervacije()` (linija ~2884)

**Dodano:**
- Automatska detekcija rezervacija pri dodavanju POP-a
- FIFO logika za skidanje rezervacija
- Ažuriranje `quantity_in_stock` na novom POP-u
- Obavijest operateru o automatskom skidanju

**Modificirana funkcija:** `tuberDodajProizvodnju()` (linija ~2802)

**Dodano:**
- Poziv `tuberSkiniRezervacije()` nakon dodavanja POP-a

---

## 📚 Ažurirana dokumentacija

### DATABASE_UPDATED.md
- Ažuriran broj kolona u `prod_inventory_pop`: 18 → 20
- Dodane nove kolone (`quantity_reserved`, `quantity_available`)
- Nova sekcija: "Rezervacije POP-a"
- Dokumentiran workflow rezervacija

### RULES_UPDATED.md
- Dodano pravilo #21: "Rezervacije POP-a - automatsko upravljanje"
- Ažuriran broj pravila: 20 → 21
- Vizualni ASCII dijagram workflow-a

---

## 📁 Novi fajlovi

### `sql/add_pop_reservations.sql`
SQL skripta za dodavanje kolona i indeksa u bazu.

**Koraci za pokretanje:**
1. Otvori Supabase SQL Editor
2. Kopiraj sadržaj iz `sql/add_pop_reservations.sql`
3. Izvrši

---

## 🧪 Test plan

### Test 1: Rezervacija
```
1. Bottomer-slagač → Dodaj GOP paletu
2. Odaberi nalog koji NEMA dovoljno POP-a
3. Provjeri upozorenje: "📌 Rezervirano X kom"
4. Supabase → Provjeri quantity_reserved > 0
```

### Test 2: Automatsko skidanje
```
1. Tuber → Dodaj POP za isti nalog (iz Test 1)
2. Provjeri obavijest: "📌 Automatski skinuto X kom"
3. Supabase → Provjeri:
   - quantity_reserved = 0
   - quantity_in_stock smanjen za rezerviranu količinu
```

### Test 3: Provjera stanja
```
1. Skladište → POP tab
2. Provjeri da stanje odgovara stvarnosti
3. Provjeri quantity_available kolonu
```

---

## 🎓 Prednosti novog sistema

✅ **Točno stanje zaliha** - `quantity_in_stock` odgovara fizičkom stanju
✅ **Transparentnost** - jasno se vidi što je rezervirano
✅ **Automatizacija** - nema ručnog rada
✅ **Audit trail** - sva skidanja zapisana u `prod_pop_consumption`
✅ **ESP32 ready** - kada brojač bude točan, sve će raditi automatski

---

## 📌 Ostale izmjene (ranije tijekom dana)

### bottomer-slagac.html
- Dodana funkcionalnost reaktivacije slučajno zatvorenih naloga
- Checkbox "Sakrij završene" za prikaz završenih naloga
- Gumb "🔄 Ponovno pokreni" za završene naloge
- Nova funkcija `reaktivirajRN()` koja poziva `reactivate_bottomer_phase` RPC

### skladiste.html
- Ručno dodavanje, uređivanje i brisanje GOP paleta (adminonly)
- Filteri: RN, Kupac, Artikl, Datum od/do, Smjena, Status
- Dropdowns umjesto text inputa za RN, Kupac, Artikl
- Admin kontrole (`imaAdminUlogu()`)

---

## 🚀 Sljedeći koraci

1. ✅ **Pokreni SQL skriptu** u Supabase
2. 🧪 **Testiraj** sve scenarije
3. 📊 **Prati** `quantity_reserved` u produkciji
4. 🔧 **Optimiziraj** ESP32 brojač za automatski unos POP-a
5. 📈 **Analiziraj** smanjenje nekonzistentnosti

---

*Autor: Claude (AI asistent) + Atila (supervizor)*
*Datum: 01. Veljače 2026*
