// ============================================
// CARTA ERP - Supabase Safe Helpers
// ============================================
// Centralizirani wrapperi za Supabase pozive s ugrađenim error handlingom.
// Cilj: spriječiti silent failures kao bug s GENERATED kolonama u
// tuber-materijal.html (cc96144), gdje je nedostatak .error checka
// uzrokovao da operateri vide lažni success log a baza odbije UPDATE.
//
// KORIŠTENJE u modulima:
//   const data = await SB.select('prod_inventory_rolls', { eq: { roll_code: 'X' } });
//   await SB.update('prod_inventory_rolls', { consumed_kg: 100 }, { id: rollId });
//   const result = await SB.rpc('complete_bottomer_phase', { p_work_order_id, p_phase: 'voditelj' });
//
// SVE METODE:
// - Bacaju iznimku ako Supabase vrati error
// - Loguju u console s prefiksom ❌ i imenom tablice
// - Pokazuju toast korisniku osim ako se eksplicitno opt-out: { silent: true }
// - Vraćaju .data direktno (ne { data, error })
// ============================================

const SB = {

  // ----- internal -----
  _handle(table, op, result, opts) {
    if (result.error) {
      const msg = `${op} ${table}: ${result.error.message}`;
      console.error('❌ ' + msg, result.error);
      if (!opts.silent && typeof showMessage === 'function') {
        showMessage('Greška baze: ' + result.error.message, 'error');
      }
      const err = new Error(msg);
      err.original = result.error;
      err.table = table;
      err.op = op;
      throw err;
    }
    return result.data;
  },

  // ----- SELECT -----
  // opts: { columns: '*', eq: {col: val}, in: {col: [vals]}, gt/gte/lt/lte: {col:val},
  //         order: {col: 'asc'|'desc'}, limit: N, single: bool, silent: bool }
  async select(table, opts = {}) {
    let q = initSupabase().from(table).select(opts.columns || '*');

    if (opts.eq) for (const [k, v] of Object.entries(opts.eq)) q = q.eq(k, v);
    if (opts.in) for (const [k, v] of Object.entries(opts.in)) q = q.in(k, v);
    if (opts.gt) for (const [k, v] of Object.entries(opts.gt)) q = q.gt(k, v);
    if (opts.gte) for (const [k, v] of Object.entries(opts.gte)) q = q.gte(k, v);
    if (opts.lt) for (const [k, v] of Object.entries(opts.lt)) q = q.lt(k, v);
    if (opts.lte) for (const [k, v] of Object.entries(opts.lte)) q = q.lte(k, v);
    if (opts.neq) for (const [k, v] of Object.entries(opts.neq)) q = q.neq(k, v);

    if (opts.order) {
      const [col, dir] = Object.entries(opts.order)[0];
      q = q.order(col, { ascending: dir !== 'desc' });
    }

    // Pravilo 3: limit uvijek eksplicitan
    q = q.limit(opts.limit || 10000);

    if (opts.single) q = q.single();
    if (opts.maybeSingle) q = q.maybeSingle();

    return this._handle(table, 'SELECT', await q, opts);
  },

  // ----- INSERT -----
  async insert(table, data, opts = {}) {
    let q = initSupabase().from(table).insert(data);
    if (opts.returning !== false) q = q.select();
    return this._handle(table, 'INSERT', await q, opts);
  },

  // ----- UPDATE -----
  // filter: { col: val } — UPDATE WHERE col=val AND ...
  async update(table, data, filter, opts = {}) {
    if (!filter || Object.keys(filter).length === 0) {
      throw new Error(`SB.update(${table}): filter je obavezan (sigurnosna mjera, sprečava UPDATE bez WHERE)`);
    }
    let q = initSupabase().from(table).update(data);
    for (const [k, v] of Object.entries(filter)) q = q.eq(k, v);
    if (opts.returning !== false) q = q.select();
    return this._handle(table, 'UPDATE', await q, opts);
  },

  // ----- UPSERT -----
  async upsert(table, data, opts = {}) {
    let q = initSupabase().from(table).upsert(data, { onConflict: opts.onConflict });
    if (opts.returning !== false) q = q.select();
    return this._handle(table, 'UPSERT', await q, opts);
  },

  // ----- DELETE -----
  async delete(table, filter, opts = {}) {
    if (!filter || Object.keys(filter).length === 0) {
      throw new Error(`SB.delete(${table}): filter je obavezan (sigurnosna mjera, sprečava DELETE bez WHERE)`);
    }
    let q = initSupabase().from(table).delete();
    for (const [k, v] of Object.entries(filter)) q = q.eq(k, v);
    return this._handle(table, 'DELETE', await q, opts);
  },

  // ----- RPC -----
  async rpc(fnName, params = {}, opts = {}) {
    return this._handle(fnName, 'RPC', await initSupabase().rpc(fnName, params), opts);
  },

  // ----- COUNT -----
  async count(table, filter = {}, opts = {}) {
    let q = initSupabase().from(table).select('*', { count: 'exact', head: true });
    for (const [k, v] of Object.entries(filter)) q = q.eq(k, v);
    const result = await q;
    if (result.error) return this._handle(table, 'COUNT', result, opts);
    return result.count;
  }
};

// Globalno dostupan
window.SB = SB;
