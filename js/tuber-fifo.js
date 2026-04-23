// ============================================
// CARTA ERP - Tuber FIFO skidanje materijala
// ============================================
// Helper library za novi FIFO flow u tuber-materijal.html.
//
// Prerequisite: sql/tuber_fifo_placeholder.sql je primijenjen u bazi
// (tablica prod_inventory_placeholder_consumption + 5 RPC funkcija).
//
// KORIŠTENJE (primjer):
//
//   var ctx = {
//     workOrderId: '...', workOrderNumber: 'RN123/26',
//     articleId: '...', productionLine: 'NLI',
//     popProduced: 48000, rez: 98,
//     paperCodes: {
//       1: 'B70-91,5-SE',   // sloj 1
//       2: 'S70-91,5-SE',   // sloj 2
//       3: null, 4: null
//     },
//     scannedRolls: {       // što je operater skenirao
//       1: [{code: 'T-20263...', fullyConsumed: true}, {code: '99999', fullyConsumed: false}],
//       2: [...]
//     }
//   };
//
//   var plan = await TuberFifo.computePlan(ctx);
//   // plan = { layers: [...], totalConsumed, needsRemainderChoice, ... }
//   var result = await TuberFifo.executePlan(ctx, plan);
// ============================================

const TuberFifo = {

  // ----- Public API -----

  /**
   * Računa FIFO plan skidanja. NE dira bazu — samo dohvaća + računa.
   * Vraća: { layers: {1: {...}, 2: {...}, ...}, needsRemainderChoice: bool, warnings: [] }
   */
  async computePlan(ctx) {
    var plan = {
      workOrderId: ctx.workOrderId,
      workOrderNumber: ctx.workOrderNumber,
      articleId: ctx.articleId,
      popProduced: ctx.popProduced,
      rez: ctx.rez,
      hasPrinting: false,
      layers: {},
      warnings: [],
      needsRemainderChoice: false
    };

    // Detekcija ima li RN tisak
    try {
      plan.hasPrinting = await SB.rpc('wo_has_printing',
        { p_wo_number: ctx.workOrderNumber }, { silent: true });
    } catch (e) {
      console.warn('wo_has_printing RPC failed:', e);
    }

    // Za svaki sloj 1-4
    for (var s = 1; s <= 4; s++) {
      var paperCode = ctx.paperCodes[s];
      if (!paperCode) continue;

      // Folija → preskoči (user instrukcija)
      if (paperCode.charAt(0).toUpperCase() === 'F') {
        plan.layers[s] = { skipped: true, reason: 'folija' };
        continue;
      }

      var scanned = ctx.scannedRolls[s] || [];
      var layerPlan = await this._computeLayerPlan(ctx, s, paperCode, scanned, plan.hasPrinting && s === 1);
      plan.layers[s] = layerPlan;

      if (layerPlan.unmarkedCount > 1 && layerPlan.remainder > 0.01) {
        plan.needsRemainderChoice = true;
      }
    }

    return plan;
  },

  /**
   * Izvršava plan. Dotiče bazu:
   * - UPDATE inventory (FIFO reduce od neoznačenih + full consume od označenih)
   * - INSERT consumed_rolls (audit)
   * - INSERT placeholder_consumption ako ima
   * - UPDATE prod_inventory_pop material_deducted
   * - UPDATE prod_work_orders tuber_status (ako tip==='nalog')
   * - INSERT pop_roll_link (traceability)
   *
   * @param ctx - context kao u computePlan
   * @param plan - rezultat computePlan()
   * @param remainderAssignments - opcional: { layer_num: roll_id } za raspodjelu ostatka
   *        (potreban kad needsRemainderChoice === true)
   */
  async executePlan(ctx, plan, remainderAssignments) {
    remainderAssignments = remainderAssignments || {};
    var linkStartTime = new Date().toISOString();
    var errors = [];
    var successCount = 0;

    for (var s = 1; s <= 4; s++) {
      var layer = plan.layers[s];
      if (!layer || layer.skipped) continue;

      try {
        await this._executeLayer(ctx, s, layer, remainderAssignments[s], linkStartTime);
        successCount++;
      } catch (e) {
        console.error('Sloj ' + s + ' greška:', e);
        errors.push({ layer: s, error: e });
      }
    }

    // Označi POP-ove kao obrađene
    if (ctx.popIds && ctx.popIds.length > 0) {
      try {
        await SB.update('prod_inventory_pop', { material_deducted: true },
          { /* placeholder filter — coristim .in() direktno */ });
        // SB.update ne podržava in() - koristim direktno
        var upd = await initSupabase().from('prod_inventory_pop')
          .update({ material_deducted: true }).in('id', ctx.popIds);
        if (upd.error) throw upd.error;
      } catch (e) {
        console.warn('POP material_deducted update failed:', e);
      }
    }

    // Populiraj pop_roll_link (traceability)
    await this._populatePopRollLink(ctx, linkStartTime);

    // Završi tuber fazu ako je tip 'nalog'
    if (ctx.tip === 'nalog' && ctx.workOrderId) {
      try {
        await initSupabase().from('prod_work_orders')
          .update({ tuber_status: 'Završeno', tuber_completed_at: new Date().toISOString() })
          .eq('id', ctx.workOrderId);
      } catch (e) { console.warn('tuber_status update failed:', e); }
    }

    return { successCount, errors };
  },

  // ----- Internal helpers -----

  async _computeLayerPlan(ctx, layerNum, paperCode, scanned, usePrintedRolls) {
    var layer = {
      layerNumber: layerNum,
      paperCode: paperCode,
      skipped: false,
      usePrintedRolls: usePrintedRolls,
      potrebno: 0,
      dodano: 0,
      remainder: 0,
      scannedResolved: [],    // [{code, roll_obj, fullyConsumed, isPlaceholder}]
      unmarkedCount: 0,
      actions: []             // opis što će se napraviti pri execute
    };

    // Širina i gramatura iz artikla — moramo dohvatiti iz ctx.article
    var sirina = ctx.article['paper_s' + layerNum + '_width'];
    var gramatura = ctx.article['paper_s' + layerNum + '_grammage'];
    if (!sirina || !gramatura) {
      layer.skipped = true;
      layer.reason = 'nedostaju širina/gramatura u artiklu';
      return layer;
    }

    layer.potrebno = (ctx.popProduced * parseFloat(sirina) * parseFloat(gramatura) * ctx.rez) / 10000000;

    // Resolve skenirane šifre
    for (var i = 0; i < scanned.length; i++) {
      var item = scanned[i];
      var resolved = await this._resolveScannedRoll(item.code, paperCode);
      layer.scannedResolved.push({
        code: item.code,
        fullyConsumed: !!item.fullyConsumed,
        roll: resolved.roll,
        isPlaceholder: resolved.isPlaceholder,
        placeholderSource: resolved.placeholderSource
      });
      if (!item.fullyConsumed) layer.unmarkedCount++;
    }

    // Izračun kg-ova:
    // dodano = zbroj remaining_kg svih skeniranih (ili initial_weight za placeholder)
    layer.dodano = layer.scannedResolved.reduce(function(sum, r) {
      var kg = r.isPlaceholder
        ? 0  // placeholder nema vlastitu rolu - kg se posuđuje iz source
        : (parseFloat(r.roll && r.roll.remaining_kg) || 0);
      return sum + kg;
    }, 0);

    // Plus placeholder kapacitet iz source rola
    var placeholderCapacity = 0;
    for (var j = 0; j < layer.scannedResolved.length; j++) {
      var r = layer.scannedResolved[j];
      if (r.isPlaceholder && r.placeholderSource) {
        placeholderCapacity += parseFloat(r.placeholderSource.remaining_kg) || 0;
      }
    }
    layer.dodanoUkljucivPlaceholder = layer.dodano + placeholderCapacity;

    // Remainder = ono što ostaje nakon što namirimo potrebno
    // (ostaje na jednoj od neoznačenih rola)
    var oznacenoKg = layer.scannedResolved
      .filter(function(r) { return r.fullyConsumed && !r.isPlaceholder; })
      .reduce(function(s, r) { return s + (parseFloat(r.roll.remaining_kg) || 0); }, 0);

    layer.remainder = Math.max(0, layer.dodanoUkljucivPlaceholder - layer.potrebno);

    // Shortage detection
    if (layer.dodanoUkljucivPlaceholder < layer.potrebno - 0.1) {
      layer.shortage = layer.potrebno - layer.dodanoUkljucivPlaceholder;
      layer.warning = 'Nedostaje ' + layer.shortage.toFixed(1) + ' kg za sloj ' + layerNum;
    }

    return layer;
  },

  async _resolveScannedRoll(code, expectedInternalId) {
    // 1. Traži u prod_inventory_rolls
    try {
      var rolls = await SB.select('prod_inventory_rolls', {
        eq: { roll_code: code },
        limit: 1
      });
      if (rolls && rolls.length > 0 && rolls[0].status !== 'Utrošena') {
        return { roll: rolls[0], isPlaceholder: false };
      }
    } catch (e) { console.warn('roll lookup failed:', e); }

    // 2. Traži u otiskanim rolama
    try {
      var printed = await SB.select('prod_inventory_printed', {
        eq: { printed_roll_code: code },
        limit: 1
      });
      if (printed && printed.length > 0) {
        return { roll: printed[0], isPlaceholder: false, source: 'printed' };
      }
    } catch (e) { console.warn('printed lookup failed:', e); }

    // 3. NEPRONAĐENO — FIFO placeholder
    var candidates = await SB.rpc('fifo_roll_candidates',
      { p_internal_id: expectedInternalId, p_min_remaining: 1 }, { silent: true });

    if (!candidates || candidates.length === 0) {
      return { roll: null, isPlaceholder: true, placeholderSource: null,
               error: 'Nema FIFO kandidata za ' + expectedInternalId };
    }

    return { roll: null, isPlaceholder: true, placeholderSource: candidates[0] };
  },

  async _executeLayer(ctx, layerNum, layer, chosenRemainderRollId, linkStartTime) {
    // Strategija:
    // 1. Full-consume označene role (UPDATE + INSERT consumed_rolls)
    // 2. Distribute remainder na chosenRemainderRollId ili single unmarked
    // 3. Placeholder insert ako ima

    var operator = ctx.operator || 'System';
    var sirina = ctx.article['paper_s' + layerNum + '_width'];
    var gramatura = ctx.article['paper_s' + layerNum + '_grammage'];

    // Trenutni "dug" koji treba skinuti na razini sloja
    var debt = layer.potrebno;

    // Prvo: označene (full-consume)
    for (var i = 0; i < layer.scannedResolved.length; i++) {
      var r = layer.scannedResolved[i];
      if (!r.fullyConsumed || r.isPlaceholder) continue;

      var rollKg = parseFloat(r.roll.remaining_kg) || 0;
      if (rollKg <= 0) continue;

      // UPDATE inventory table - atomično
      var tablica = r.source === 'printed' ? 'prod_inventory_printed' : 'prod_inventory_rolls';
      var curConsumed = parseFloat(r.roll.consumed_kg) || 0;

      await initSupabase().from(tablica).update({
        consumed_kg: curConsumed + rollKg,
        status: 'Utrošena'   // standardiziran value
      }).eq('id', r.roll.id);

      // INSERT consumed_rolls
      await this._insertConsumedRoll(ctx, r.roll, rollKg, 0, layerNum, 'full', tablica);

      debt -= rollKg;
    }

    // Zatim: placeholder (posudi iz FIFO source)
    for (var j = 0; j < layer.scannedResolved.length; j++) {
      var p = layer.scannedResolved[j];
      if (!p.isPlaceholder || !p.placeholderSource) continue;

      // Koliko posuditi? Do izbjeći nadmjerno, uzmi manje od debt/source remaining
      var sourceRemaining = parseFloat(p.placeholderSource.remaining_kg) || 0;
      var borrowAmount = Math.min(debt, sourceRemaining);
      if (borrowAmount <= 0) continue;

      // Atomic consume — ako drugi proces je preduhitrio, vrati false
      var ok = await SB.rpc('atomic_consume_roll',
        { p_roll_id: p.placeholderSource.id, p_amount: borrowAmount }, { silent: true });
      if (!ok) {
        console.warn('atomic_consume_roll race condition za placeholder source', p.placeholderSource.roll_code);
        continue;
      }

      // INSERT placeholder zapis
      await initSupabase().from('prod_inventory_placeholder_consumption').insert({
        scanned_code: p.code,
        internal_id: layer.paperCode,
        layer_number: layerNum,
        placeholder_source_roll_id: p.placeholderSource.id,
        consumed_kg: borrowAmount,
        work_order_id: ctx.workOrderId,
        work_order_number: ctx.workOrderNumber,
        operator: operator,
        production_line: ctx.productionLine,
        shift_date: ctx.shiftDate
      });

      // INSERT consumed_rolls (bilježi posudbu)
      await initSupabase().from('prod_inventory_consumed_rolls').insert({
        roll_code: p.code + ' [placeholder]',
        source_table: 'placeholder',
        material_type: 'rolls',
        width_cm: sirina,
        grammage: gramatura,
        consumed_kg: borrowAmount,
        remaining_kg: 0,
        work_order_id: ctx.workOrderId,
        work_order_number: ctx.workOrderNumber,
        article_name: ctx.articleName,
        layer_number: layerNum,
        pop_quantity: ctx.popProduced,
        production_line: ctx.productionLine,
        shift_date: ctx.shiftDate,
        consumption_type: 'placeholder'
      });

      debt -= borrowAmount;
    }

    // Zadnje: remainder na neoznačenu rolu
    if (debt > 0.01) {
      var unmarked = layer.scannedResolved.filter(function(r) {
        return !r.fullyConsumed && !r.isPlaceholder && r.roll;
      });

      var targetRoll;
      if (chosenRemainderRollId) {
        targetRoll = unmarked.find(function(r) { return r.roll.id === chosenRemainderRollId; });
      } else if (unmarked.length === 1) {
        targetRoll = unmarked[0];
      }

      if (targetRoll) {
        var tablica = targetRoll.source === 'printed' ? 'prod_inventory_printed' : 'prod_inventory_rolls';
        var cur = parseFloat(targetRoll.roll.consumed_kg) || 0;
        var initialOrWeight = parseFloat(targetRoll.roll.initial_weight_kg || targetRoll.roll.weight_kg) || 0;
        var newConsumed = cur + debt;
        var newRemaining = initialOrWeight - newConsumed;

        await initSupabase().from(tablica).update({
          consumed_kg: newConsumed,
          status: newRemaining < 20 ? 'Utrošena' : 'Djelomično utrošeno'
        }).eq('id', targetRoll.roll.id);

        await this._insertConsumedRoll(ctx, targetRoll.roll, debt, newRemaining, layerNum, 'partial', tablica);
      } else {
        console.warn('Sloj ' + layerNum + ': ne mogu raspodijeliti ostatak ' + debt.toFixed(1) + ' kg (nema unmarked role)');
      }
    }
  },

  async _insertConsumedRoll(ctx, roll, consumedKg, remainingKg, layerNum, type, sourceTable) {
    return await initSupabase().from('prod_inventory_consumed_rolls').insert({
      source_roll_id: roll.id,
      roll_code: roll.roll_code || roll.printed_roll_code,
      source_table: sourceTable,
      material_type: sourceTable === 'prod_inventory_printed' ? 'printed' : 'rolls',
      width_cm: roll.width_cm,
      grammage: roll.grammage,
      color: roll.color,
      manufacturer: roll.manufacturer,
      consumed_kg: consumedKg,
      remaining_kg: remainingKg,
      work_order_id: ctx.workOrderId,
      work_order_number: ctx.workOrderNumber,
      article_name: ctx.articleName,
      layer_number: layerNum,
      pop_quantity: ctx.popProduced,
      production_line: ctx.productionLine,
      shift_date: ctx.shiftDate,
      consumption_type: type
    });
  },

  async _populatePopRollLink(ctx, linkStartTime) {
    if (!ctx.popIds || ctx.popIds.length === 0 || !ctx.workOrderId) return;

    try {
      var consumed = await SB.select('prod_inventory_consumed_rolls', {
        columns: 'id, layer_number',
        eq: { work_order_id: ctx.workOrderId },
        gte: { created_at: linkStartTime },
        limit: 500
      });
      if (!consumed || consumed.length === 0) return;

      var linkRows = [];
      for (var i = 0; i < ctx.popIds.length; i++) {
        for (var j = 0; j < consumed.length; j++) {
          linkRows.push({
            pop_id: ctx.popIds[i],
            consumed_roll_id: consumed[j].id,
            layer_number: consumed[j].layer_number || null
          });
        }
      }

      await initSupabase().from('prod_pop_roll_link')
        .upsert(linkRows, { onConflict: 'pop_id,consumed_roll_id', ignoreDuplicates: true });
    } catch (e) { console.warn('pop_roll_link populate failed:', e); }
  }
};

window.TuberFifo = TuberFifo;
