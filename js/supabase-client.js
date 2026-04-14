// ============================================
// CARTA ERP - Supabase Client
// ============================================

window._supabaseClient = null;

function initSupabase() {
  if (!window._supabaseClient) {
    window._supabaseClient = window.supabase.createClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_ANON_KEY);
  }
  return window._supabaseClient;
}

// Generic CRUD operations
const DB = {
  // SELECT
  async select(table, options = {}) {
    const { columns = '*', filters = {}, order = null, limit = null, single = false } = options;
    let query = initSupabase().from(table).select(columns);
    
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== null && value !== undefined) {
        query = query.eq(key, value);
      }
    });
    
    if (order) query = query.order(order.column, { ascending: order.ascending ?? true });
    if (limit) query = query.limit(limit);
    if (single) query = query.single();
    
    const { data, error } = await query;
    if (error) throw error;
    return data;
  },

  // INSERT
  async insert(table, data) {
    const { data: result, error } = await initSupabase()
      .from(table)
      .insert(data)
      .select();
    if (error) throw error;
    return result;
  },

  // UPDATE
  async update(table, id, data) {
    const { data: result, error } = await initSupabase()
      .from(table)
      .update(data)
      .eq('id', id)
      .select();
    if (error) throw error;
    return result;
  },

  // DELETE
  async delete(table, id) {
    const { error } = await initSupabase()
      .from(table)
      .delete()
      .eq('id', id);
    if (error) throw error;
    return true;
  },

  // UPSERT
  async upsert(table, data, onConflict = 'id') {
    const { data: result, error } = await initSupabase()
      .from(table)
      .upsert(data, { onConflict })
      .select();
    if (error) throw error;
    return result;
  },

  // RPC (stored procedures)
  async rpc(fnName, params = {}) {
    const { data, error } = await initSupabase().rpc(fnName, params);
    if (error) throw error;
    return data;
  },

  // Search with ILIKE
  async search(table, column, term, options = {}) {
    const { columns = '*', limit = 50 } = options;
    const { data, error } = await initSupabase()
      .from(table)
      .select(columns)
      .ilike(column, `%${term}%`)
      .limit(limit);
    if (error) throw error;
    return data;
  }
};

// Specific table helpers
const Customers = {
  async getAll() { return DB.select('prod_customers', { order: { column: 'name' } }); },
  async getById(id) { return DB.select('prod_customers', { filters: { id }, single: true }); },
  async getByCode(code) { return DB.select('prod_customers', { filters: { customer_code: code }, single: true }); },
  async search(term) { return DB.search('prod_customers', 'name', term); }
};

const Articles = {
  async getAll() { return DB.select('prod_articles', { order: { column: 'name' } }); },
  async getById(id) { return DB.select('prod_articles', { filters: { id }, single: true }); },
  async getByCustomer(customerId) { return DB.select('prod_articles', { filters: { customer_id: customerId } }); },
  async search(term) { return DB.search('prod_articles', 'name', term); }
};

const Employees = {
  async getAll() { return DB.select('employees', { filters: { active: true }, order: { column: 'last_name' } }); },
  async getByPin(pin) { return DB.select('employees', { filters: { pin_code: pin, active: true }, single: true }); },
  async getById(id) { return DB.select('employees', { filters: { id }, single: true }); }
};

const Machines = {
  async getAll() { return DB.select('prod_machines', { order: { column: 'name' } }); },
  async getByLine(line) { return DB.select('prod_machines', { filters: { production_line: line } }); }
};

const Orders = {
  async getActive() { return DB.select('prod_orders', { filters: { status: 'Aktivno' }, order: { column: 'created_at', ascending: false } }); },
  async getAll() { return DB.select('prod_orders', { order: { column: 'created_at', ascending: false } }); }
};

const WorkOrders = {
  async getActive() { return DB.select('prod_work_orders', { filters: { status: 'U tijeku' } }); },
  async getByOrder(orderNumber) { return DB.select('prod_work_orders', { filters: { order_number: orderNumber } }); }
};

const InventoryRolls = {
  async getAll() { return DB.select('prod_inventory_rolls', { order: { column: 'entry_date', ascending: false } }); },
  async getAvailable() { return DB.select('prod_inventory_rolls', { filters: { status: 'Na skladištu' } }); }
};

const PaperCodes = {
  async getAll() { return DB.select('prod_paper_codes', { order: { column: 'code' } }); }
};

const Belts = {
  async getAll() { return DB.select('prod_belts', { order: { column: 'belt_code' } }); },
  async getByMachine(machineCode) { return DB.select('prod_belts', { filters: { machine_code: machineCode } }); }
};

// ============================================
// SCHEDULES - Dohvaćanje rasporeda
// ============================================
const Schedules = {
  // Dohvati djelatnike za određeni datum i liniju
  async getByDateAndLine(date, line) {
    const { data, error } = await initSupabase()
      .from('schedules')
      .select('*, employees(id, first_name, last_name), shifts(id, name, start_time, end_time), teams(id, name)')
      .eq('date', date)
      .eq('line', line);
    if (error) throw error;
    return data;
  },
  
  // Dohvati djelatnike za određeni datum, liniju i smjenu
  async getByDateLineAndShift(date, line, shiftId) {
    const { data, error } = await initSupabase()
      .from('schedules')
      .select('*, employees(id, first_name, last_name), shifts(id, name, start_time, end_time), teams(id, name)')
      .eq('date', date)
      .eq('line', line)
      .eq('shift_id', shiftId);
    if (error) throw error;
    return data;
  },
  
  // Dohvati trenutnu smjenu za liniju (automatski određuje datum i smjenu po satu)
  async getCurrentShift(line) {
    var now = new Date();
    var hour = now.getHours();
    var dateStr = now.toISOString().split('T')[0];
    
    // Ako je između ponoći i 6 ujutro, smjena je zapravo počela jučer
    if (hour < 6) {
      var yesterday = new Date(now);
      yesterday.setDate(yesterday.getDate() - 1);
      dateStr = yesterday.toISOString().split('T')[0];
    }
    
    // Dohvati smjene da nađemo pravu
    var shiftsResult = await initSupabase()
      .from('shifts')
      .select('id, name, start_time, end_time');
    
    if (shiftsResult.error) throw shiftsResult.error;
    
    var currentShiftId = null;
    (shiftsResult.data || []).forEach(function(s) {
      var startHour = parseInt(s.start_time.split(':')[0]);
      if (startHour === 6 && hour >= 6 && hour < 14) currentShiftId = s.id;
      else if (startHour === 14 && hour >= 14 && hour < 22) currentShiftId = s.id;
      else if (startHour === 22 && (hour >= 22 || hour < 6)) currentShiftId = s.id;
    });
    
    if (!currentShiftId) return [];
    
    return this.getByDateLineAndShift(dateStr, line, currentShiftId);
  },
  
  // Dohvati raspored za period
  async getByPeriod(startDate, endDate, line) {
    var query = initSupabase()
      .from('schedules')
      .select('*, employees(id, first_name, last_name), shifts(id, name)')
      .gte('date', startDate)
      .lte('date', endDate);
    
    if (line) query = query.eq('line', line);
    
    var result = await query.order('date');
    if (result.error) throw result.error;
    return result.data;
  }
};
