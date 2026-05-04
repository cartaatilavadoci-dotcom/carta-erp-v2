// ============================================
// CARTA ERP - Roll Consumption (v2)
// ============================================
// Univerzalni helper za skidanje rola sa stanja kroz atomsku PLPGSQL RPC
// `consume_rolls_for_work_order`. Koriste ga sva 3 stroja (tuber, tisak, rezač).
//
// Princip: sljedivost je primarna, bilanca sekundarna. Save UVIJEK prolazi.
// Overdraft, nepoznata šifra, NULL initial — sve se logira u discrepancy_log
// ali ne blokira save.
//
// KORIŠTENJE:
//   const result = await RollConsumption.consume({
//     machine: 'tuber',                     // 'tuber' | 'tisak' | 'rezac'
//     workOrderId: '<uuid>',
//     workOrderNumber: 'RN045/26',
//     popIds: ['<uuid>', ...],              // tuber only
//     rolls: [
//       { scannedCode: 'B70-9123', consumedKg: 12.5, layerNumber: 1 },
//       ...
//     ]
//   });
//   // result = { status: 'ok', rows: [...], discrepancies: 0, ... }
// ============================================

window.RollConsumption = {

  /**
   * Skida role sa stanja kroz atomsku RPC.
   * Save UVIJEK prolazi (osim mreža/permissions). Discrepance se logiraju.
   *
   * @param {object} opts
   * @param {'tuber'|'tisak'|'rezac'} opts.machine
   * @param {string} [opts.workOrderId] - UUID radnog naloga (preporuča se)
   * @param {string} opts.workOrderNumber - npr. 'RN045/26'
   * @param {string[]} [opts.popIds] - samo za tuber
   * @param {string} [opts.printedRollId] - samo za tisak
   * @param {string[]} [opts.stripIds] - samo za rezač
   * @param {Array} opts.rolls - [{ scannedCode, consumedKg, layerNumber?, isNewRoll?, manualInitialKg?, manualInternalId?, manualManufacturer? }]
   * @param {string} [opts.idempotencyKey] - override; default: machine:wo:timestamp
   * @returns {Promise<{status, rows, discrepancies, skipped, idempotency_key}>}
   */
  async consume(opts) {
    if (!opts || !opts.machine) throw new Error('RollConsumption.consume: machine required');
    if (!opts.workOrderNumber) throw new Error('RollConsumption.consume: workOrderNumber required');
    if (!Array.isArray(opts.rolls)) throw new Error('RollConsumption.consume: rolls array required');

    const idempotency = opts.idempotencyKey ||
      `${opts.machine}:${opts.workOrderNumber}:${Date.now()}`;

    const operator = (typeof Auth !== 'undefined' && Auth.getUser)
      ? (Auth.getUser()?.name || 'Operator') : 'Operator';

    const shiftDate = (typeof getProductionDate === 'function')
      ? getProductionDate() : new Date().toISOString().split('T')[0];

    const shiftNumber = (typeof getCurrentShiftNumber === 'function')
      ? getCurrentShiftNumber() : null;

    const productionLine = window.LINIJA || opts.productionLine || null;

    const payload = {
      machine: opts.machine,
      work_order_id: opts.workOrderId || null,
      work_order_number: opts.workOrderNumber,
      idempotency_key: idempotency,
      operator: operator,
      shift_date: shiftDate,
      shift_number: shiftNumber,
      production_line: productionLine,
      pop_ids: opts.popIds || [],
      printed_roll_id: opts.printedRollId || null,
      strip_ids: opts.stripIds || [],
      rolls: (opts.rolls || []).map((r, i) => ({
        scanned_code: (r.scannedCode || '').trim(),
        consumed_kg: Number(r.consumedKg) || 0,
        layer_number: r.layerNumber || null,
        client_row_id: r.clientRowId || `r${i}`,
        is_new_roll: !!r.isNewRoll,
        manual_initial_kg: r.manualInitialKg || null,
        manual_internal_id: r.manualInternalId || null,
        manual_manufacturer: r.manualManufacturer || null,
        is_phantom: !!r.isPhantom,
        phantom_internal_id: r.phantomInternalId || null
      })).filter(r => r.scanned_code)
    };

    if (payload.rolls.length === 0 && !opts.allowEmpty) {
      throw new Error('RollConsumption.consume: nema rola za skidanje');
    }

    console.log(`[RollConsumption] consume(${opts.machine})`, {
      wo: opts.workOrderNumber,
      rolls: payload.rolls.length,
      idem: idempotency
    });

    const data = await SB.rpc('consume_rolls_for_work_order', { p_input: payload });

    if (data?.status === 'no_op') {
      console.warn('[RollConsumption] no_op (already deducted)', data);
      if (typeof showMessage === 'function') {
        showMessage('Materijal je već skinut za ovaj nalog.', 'info');
      }
      return data;
    }

    const disc = data?.discrepancies || 0;
    if (disc > 0) {
      console.warn(`[RollConsumption] ${disc} discrepancies`, data);
      if (typeof showMessage === 'function') {
        showMessage(
          `Spremljeno. ${disc} stavki za reviziju u skladištu (overdraft / nepoznata rola).`,
          'warning'
        );
      }
    }

    return data;
  },

  /**
   * UI helper: prikaže modal koji pita "Je li ovo nova rola u skladištu?".
   * Vraća { isNewRoll, manualInitialKg?, manualInternalId?, manualManufacturer? }
   * ili null ako je operater odustao.
   *
   * @param {string} scannedCode
   * @param {object} [hints] - { internalId, manufacturer } iz artikla
   * @returns {Promise<object|null>}
   */
  async promptUnknownRoll(scannedCode, hints = {}) {
    return new Promise((resolve) => {
      // Lijepo bi bilo izvuć modal markup u zaseban template, ali za prvu iteraciju
      // ostajemo s inline modal-om koji se ubaci u body.
      const modalId = 'rc-unknown-roll-modal-' + Date.now();
      const wrap = document.createElement('div');
      wrap.id = modalId;
      wrap.style.cssText =
        'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,0.55);' +
        'z-index:100000;display:flex;align-items:center;justify-content:center;';
      wrap.innerHTML = `
        <div style="background:#fff;max-width:520px;width:92%;border-radius:8px;
                    padding:20px;box-shadow:0 8px 24px rgba(0,0,0,0.2);">
          <h3 style="margin:0 0 12px 0;color:#c62828;">⚠️ Rola nije u skladištu</h3>
          <p style="margin:0 0 8px 0;font-size:14px;">
            Šifra <strong>${escapeHtml(scannedCode)}</strong> nije pronađena u sustavu.
          </p>
          <p style="margin:0 0 16px 0;font-size:13px;color:#555;">
            Je li ovo <em>nova rola</em> koja nije evidentirana, ili <em>postojeća</em>
            koju samo želiš povezati s nalogom (bez umanjenja stanja)?
          </p>
          <div id="${modalId}-newroll-fields" style="display:none;
               background:#fff8e1;padding:12px;border-radius:6px;margin-bottom:14px;">
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;">
              <label style="font-size:12px;">
                Početna težina (kg):
                <input type="number" step="0.1" id="${modalId}-init-kg"
                       style="width:100%;padding:6px;border:1px solid #ccc;border-radius:4px;"
                       placeholder="npr. 450">
              </label>
              <label style="font-size:12px;">
                Vrsta papira (interni ID):
                <input type="text" id="${modalId}-internal-id"
                       value="${escapeHtml(hints.internalId || '')}"
                       style="width:100%;padding:6px;border:1px solid #ccc;border-radius:4px;"
                       placeholder="npr. S70-106-SE">
              </label>
              <label style="font-size:12px;grid-column:1/-1;">
                Proizvođač (opcijski):
                <input type="text" id="${modalId}-mfr"
                       value="${escapeHtml(hints.manufacturer || '')}"
                       style="width:100%;padding:6px;border:1px solid #ccc;border-radius:4px;">
              </label>
            </div>
          </div>
          <div style="display:flex;gap:8px;justify-content:flex-end;flex-wrap:wrap;">
            <button id="${modalId}-cancel"
                    style="padding:8px 14px;background:#9e9e9e;color:#fff;
                           border:none;border-radius:4px;cursor:pointer;">
              Odustani
            </button>
            <button id="${modalId}-existing"
                    style="padding:8px 14px;background:#1976d2;color:#fff;
                           border:none;border-radius:4px;cursor:pointer;">
              📋 Postojeća — samo poveži s RN-om
            </button>
            <button id="${modalId}-new"
                    style="padding:8px 14px;background:#388e3c;color:#fff;
                           border:none;border-radius:4px;cursor:pointer;">
              ➕ Nova rola
            </button>
          </div>
        </div>
      `;
      document.body.appendChild(wrap);

      const cleanup = () => { if (wrap.parentNode) wrap.parentNode.removeChild(wrap); };

      document.getElementById(`${modalId}-cancel`).onclick = () => {
        cleanup();
        resolve(null);
      };

      document.getElementById(`${modalId}-existing`).onclick = () => {
        cleanup();
        resolve({ isNewRoll: false });
      };

      document.getElementById(`${modalId}-new`).onclick = () => {
        const fields = document.getElementById(`${modalId}-newroll-fields`);
        if (fields.style.display === 'none') {
          fields.style.display = 'block';
          return; // prvi klik samo otvori formu
        }
        const initKg = parseFloat(document.getElementById(`${modalId}-init-kg`).value);
        const iid = document.getElementById(`${modalId}-internal-id`).value.trim();
        const mfr = document.getElementById(`${modalId}-mfr`).value.trim();
        if (!initKg || initKg <= 0) {
          alert('Unesi početnu težinu role.');
          return;
        }
        cleanup();
        resolve({
          isNewRoll: true,
          manualInitialKg: initKg,
          manualInternalId: iid || null,
          manualManufacturer: mfr || null
        });
      };
    });

    // local helper
    function escapeHtml(s) {
      return String(s || '').replace(/[&<>"']/g, c => ({
        '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
      }[c]));
    }
  },

  /**
   * Provjeri je li v2 flow uključen za stroj. Cache 60s u memoriji.
   * @param {'tuber'|'tisak'|'rezac'} machine
   * @returns {Promise<boolean>}
   */
  async isV2Enabled(machine) {
    if (!this._flagCache) this._flagCache = { ts: 0, values: {} };
    const now = Date.now();
    if (now - this._flagCache.ts > 60000) {
      try {
        const rows = await SB.select('prod_settings', {
          columns: 'key,value',
          in: { key: [
            'roll_consumption_v2_tuber',
            'roll_consumption_v2_tisak',
            'roll_consumption_v2_rezac'
          ]},
          silent: true
        });
        this._flagCache.values = {};
        (rows || []).forEach(r => {
          this._flagCache.values[r.key] = (r.value === 'true' || r.value === '1');
        });
        this._flagCache.ts = now;
      } catch (e) {
        console.warn('[RollConsumption] flag check failed, assuming v1', e);
        return false;
      }
    }
    return !!this._flagCache.values[`roll_consumption_v2_${machine}`];
  }
};

// Helper za sigurno HTML escape kad se koristi izvan modal funkcije
function escapeHtml(s) {
  return String(s || '').replace(/[&<>"']/g, c => ({
    '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
  }[c]));
}
