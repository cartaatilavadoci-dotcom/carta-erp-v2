/* ============================================
 * CARTA ERP - ESP32 Brojač Integracija
 * ============================================
 * 
 * Ova datoteka sadrži kod koji se treba dodati u tuber.html
 * 
 * UPUTE ZA INTEGRACIJU:
 * 
 * 1. CSS (dodati prije </style> taga, oko linije 847)
 * 2. HTML (dodati unutar TRENUTNI NALOG kartice, nakon tuber-info-grid, oko linije 998)
 * 3. JavaScript (dodati prije </script> taga, oko linije 6206)
 * 
 * ============================================
 */

/* ============================================
 * 1. CSS - DODATI PRIJE </style>
 * ============================================ */

/* ESP32 BROJAČ WIDGET */
.esp32-counter-widget {
  background: linear-gradient(135deg, #1a237e 0%, #283593 100%);
  border-radius: 15px;
  padding: 25px;
  margin: 20px 0;
  color: white;
  position: relative;
  overflow: hidden;
}

.esp32-counter-widget::before {
  content: '';
  position: absolute;
  top: -50%;
  right: -50%;
  width: 100%;
  height: 100%;
  background: radial-gradient(circle, rgba(255,255,255,0.1) 0%, transparent 70%);
  pointer-events: none;
}

.esp32-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.esp32-title {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 1.1em;
  font-weight: 600;
}

.esp32-status-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  background: #4caf50;
  animation: pulse-green 2s infinite;
}

.esp32-status-dot.offline {
  background: #f44336;
  animation: pulse-red 2s infinite;
}

.esp32-status-dot.syncing {
  background: #ff9800;
  animation: pulse-orange 1s infinite;
}

@keyframes pulse-green {
  0%, 100% { box-shadow: 0 0 0 0 rgba(76, 175, 80, 0.7); }
  50% { box-shadow: 0 0 0 8px rgba(76, 175, 80, 0); }
}

@keyframes pulse-red {
  0%, 100% { box-shadow: 0 0 0 0 rgba(244, 67, 54, 0.7); }
  50% { box-shadow: 0 0 0 8px rgba(244, 67, 54, 0); }
}

@keyframes pulse-orange {
  0%, 100% { box-shadow: 0 0 0 0 rgba(255, 152, 0, 0.7); }
  50% { box-shadow: 0 0 0 8px rgba(255, 152, 0, 0); }
}

.esp32-device-info {
  font-size: 0.8em;
  opacity: 0.8;
}

.esp32-count-display {
  text-align: center;
  margin: 25px 0;
}

.esp32-count-value {
  font-size: 4em;
  font-weight: 700;
  font-family: 'Courier New', monospace;
  letter-spacing: 2px;
  text-shadow: 0 4px 15px rgba(0,0,0,0.3);
  line-height: 1;
}

.esp32-count-label {
  font-size: 0.85em;
  opacity: 0.8;
  margin-top: 8px;
  text-transform: uppercase;
  letter-spacing: 2px;
}

.esp32-progress-section {
  margin: 20px 0;
}

.esp32-progress-header {
  display: flex;
  justify-content: space-between;
  margin-bottom: 8px;
  font-size: 0.9em;
}

.esp32-progress-bar {
  height: 12px;
  background: rgba(255,255,255,0.2);
  border-radius: 6px;
  overflow: hidden;
}

.esp32-progress-fill {
  height: 100%;
  background: linear-gradient(90deg, #4caf50 0%, #8bc34a 100%);
  border-radius: 6px;
  transition: width 0.5s ease;
}

.esp32-progress-fill.warning {
  background: linear-gradient(90deg, #ff9800 0%, #ffc107 100%);
}

.esp32-progress-fill.complete {
  background: linear-gradient(90deg, #2196f3 0%, #03a9f4 100%);
}

.esp32-stats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 15px;
  margin-top: 20px;
}

.esp32-stat-item {
  background: rgba(255,255,255,0.1);
  padding: 12px;
  border-radius: 10px;
  text-align: center;
}

.esp32-stat-value {
  font-size: 1.4em;
  font-weight: 700;
}

.esp32-stat-label {
  font-size: 0.75em;
  opacity: 0.8;
  margin-top: 4px;
  text-transform: uppercase;
}

.esp32-actions {
  display: flex;
  gap: 10px;
  margin-top: 20px;
  flex-wrap: wrap;
}

.esp32-btn {
  padding: 12px 20px;
  border: none;
  border-radius: 8px;
  cursor: pointer;
  font-weight: 600;
  font-size: 0.95em;
  display: flex;
  align-items: center;
  gap: 8px;
  transition: all 0.2s;
}

.esp32-btn-primary {
  background: #4caf50;
  color: white;
}

.esp32-btn-primary:hover {
  background: #43a047;
  transform: translateY(-2px);
}

.esp32-btn-secondary {
  background: rgba(255,255,255,0.2);
  color: white;
}

.esp32-btn-secondary:hover {
  background: rgba(255,255,255,0.3);
}

.esp32-btn-danger {
  background: #f44336;
  color: white;
}

.esp32-btn-danger:hover {
  background: #e53935;
}

.esp32-last-sync {
  font-size: 0.8em;
  opacity: 0.7;
  margin-top: 15px;
  text-align: center;
}

/* ESP32 widget kad nije aktivan */
.esp32-counter-widget.inactive {
  background: linear-gradient(135deg, #455a64 0%, #607d8b 100%);
}

.esp32-counter-widget.inactive .esp32-count-value {
  opacity: 0.5;
}

/* Mobile responsiveness */
@media (max-width: 768px) {
  .esp32-count-value {
    font-size: 3em;
  }
  
  .esp32-stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  
  .esp32-actions {
    flex-direction: column;
  }
  
  .esp32-btn {
    width: 100%;
    justify-content: center;
  }
}


/* ============================================
 * 2. HTML - DODATI UNUTAR TRENUTNI NALOG KARTICE
 *    (nakon tuber-info-grid diva, oko linije 998)
 * ============================================ */

/*
Kopiraj ovaj HTML i dodaj ga u tuber.html:

    <!-- ESP32 BROJAČ -->
    <div id="esp32CounterWidget" class="esp32-counter-widget" style="display: none;">
      <div class="esp32-header">
        <div class="esp32-title">
          <span class="esp32-status-dot" id="esp32StatusDot"></span>
          <span>🔢 ESP32 Brojač</span>
        </div>
        <div class="esp32-device-info" id="esp32DeviceInfo">
          Device: ---
        </div>
      </div>
      
      <div class="esp32-count-display">
        <div class="esp32-count-value" id="esp32CountValue">0</div>
        <div class="esp32-count-label">Tuljaka proizvedeno</div>
      </div>
      
      <div class="esp32-progress-section">
        <div class="esp32-progress-header">
          <span>Napredak</span>
          <span id="esp32ProgressPercent">0%</span>
        </div>
        <div class="esp32-progress-bar">
          <div class="esp32-progress-fill" id="esp32ProgressFill" style="width: 0%"></div>
        </div>
      </div>
      
      <div class="esp32-stats-grid">
        <div class="esp32-stat-item">
          <div class="esp32-stat-value" id="esp32Target">0</div>
          <div class="esp32-stat-label">Cilj</div>
        </div>
        <div class="esp32-stat-item">
          <div class="esp32-stat-value" id="esp32Remaining">0</div>
          <div class="esp32-stat-label">Preostalo</div>
        </div>
        <div class="esp32-stat-item">
          <div class="esp32-stat-value" id="esp32Shift">-</div>
          <div class="esp32-stat-label">Smjena</div>
        </div>
        <div class="esp32-stat-item">
          <div class="esp32-stat-value" id="esp32Rate">0</div>
          <div class="esp32-stat-label">kom/min</div>
        </div>
      </div>
      
      <div class="esp32-actions">
        <button class="esp32-btn esp32-btn-primary" onclick="esp32UseCountForPOP()">
          ✅ Koristi za POP unos
        </button>
        <button class="esp32-btn esp32-btn-secondary" onclick="esp32RefreshCounter()">
          🔄 Osvježi
        </button>
        <button class="esp32-btn esp32-btn-secondary" onclick="esp32StopCounter()">
          ⏹️ Zaustavi brojač
        </button>
      </div>
      
      <div class="esp32-last-sync" id="esp32LastSync">
        Zadnja sinkronizacija: ---
      </div>
    </div>

*/


/* ============================================
 * 3. JAVASCRIPT - DODATI PRIJE </script>
 * ============================================ */

// ============================================
// ESP32 BROJAČ INTEGRACIJA
// ============================================

var esp32CounterData = null;
var esp32Subscription = null;
var esp32PollInterval = null;
var esp32LastPulseTime = null;
var esp32PulseCount = 0;

// Mapiranje linija na machine_code
var ESP32_MACHINE_CODES = {
  'WH': 'WH-1',
  'NLI': 'NLI-1'
};

// Inicijalizacija ESP32 brojača
async function esp32Init() {
  console.log('🔢 ESP32 init za liniju:', window.LINIJA);
  
  var machineCode = ESP32_MACHINE_CODES[window.LINIJA];
  if (!machineCode) {
    console.log('ESP32: Nema definiranog stroja za liniju', window.LINIJA);
    return;
  }
  
  // Dohvati stanje brojača
  await esp32LoadCounterStatus(machineCode);
  
  // Pokreni real-time subscription
  esp32StartRealtimeSubscription(machineCode);
  
  // Backup polling svakih 10 sekundi
  esp32PollInterval = setInterval(function() {
    esp32LoadCounterStatus(machineCode);
  }, 10000);
}

// Dohvati stanje brojača s baze
async function esp32LoadCounterStatus(machineCode) {
  try {
    var { data, error } = await initSupabase()
      .rpc('get_counter_status', { p_machine_code: machineCode });
    
    if (error) throw error;
    
    if (data && data.active) {
      esp32CounterData = data;
      esp32UpdateDisplay(data);
      document.getElementById('esp32CounterWidget').style.display = 'block';
    } else {
      esp32CounterData = null;
      document.getElementById('esp32CounterWidget').style.display = 'none';
    }
  } catch (e) {
    console.error('ESP32 load error:', e);
  }
}

// Pokreni real-time subscription
function esp32StartRealtimeSubscription(machineCode) {
  if (esp32Subscription) {
    esp32Subscription.unsubscribe();
  }
  
  esp32Subscription = initSupabase()
    .channel('esp32-counter-' + machineCode)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: 'prod_machine_counters',
        filter: 'machine_code=eq.' + machineCode
      },
      function(payload) {
        console.log('🔢 ESP32 realtime update:', payload.new);
        if (payload.new && payload.new.is_active) {
          esp32UpdateDisplayFromPayload(payload.new);
        }
      }
    )
    .subscribe(function(status) {
      console.log('ESP32 subscription status:', status);
    });
}

// Ažuriraj prikaz iz payload-a
function esp32UpdateDisplayFromPayload(data) {
  esp32CounterData = data;
  
  var count = data.count || 0;
  var target = data.target_quantity || 0;
  var progress = target > 0 ? Math.round((count / target) * 100) : 0;
  
  // Izračunaj rate (kom/min) - ako imamo last_pulse_at
  var rate = 0;
  if (data.last_pulse_at && data.started_at) {
    var startTime = new Date(data.started_at).getTime();
    var now = new Date().getTime();
    var minutes = (now - startTime) / 60000;
    if (minutes > 0) {
      rate = Math.round(count / minutes);
    }
  }
  
  document.getElementById('esp32CountValue').textContent = count.toLocaleString('hr-HR');
  document.getElementById('esp32Target').textContent = target.toLocaleString('hr-HR');
  document.getElementById('esp32Remaining').textContent = Math.max(0, target - count).toLocaleString('hr-HR');
  document.getElementById('esp32ProgressPercent').textContent = progress + '%';
  document.getElementById('esp32ProgressFill').style.width = Math.min(100, progress) + '%';
  document.getElementById('esp32Rate').textContent = rate;
  document.getElementById('esp32Shift').textContent = data.shift_number || '-';
  
  // Progress bar boja
  var progressFill = document.getElementById('esp32ProgressFill');
  progressFill.classList.remove('warning', 'complete');
  if (progress >= 100) {
    progressFill.classList.add('complete');
  } else if (progress >= 90) {
    progressFill.classList.add('warning');
  }
  
  // Status dot
  var statusDot = document.getElementById('esp32StatusDot');
  var secondsSincePulse = data.seconds_since_pulse || 0;
  statusDot.classList.remove('offline', 'syncing');
  
  if (secondsSincePulse > 60) {
    statusDot.classList.add('offline');
  } else if (secondsSincePulse > 10) {
    statusDot.classList.add('syncing');
  }
  
  // Device info
  if (data.device_id) {
    document.getElementById('esp32DeviceInfo').textContent = 'Device: ' + data.device_id.substring(0, 8) + '...';
  }
  
  // Last sync
  if (data.last_sync_at) {
    var syncTime = new Date(data.last_sync_at);
    document.getElementById('esp32LastSync').textContent = 
      'Zadnja sinkronizacija: ' + syncTime.toLocaleTimeString('hr-HR');
  }
  
  document.getElementById('esp32CounterWidget').style.display = 'block';
}

// Ažuriraj prikaz (wrapper za oba slučaja)
function esp32UpdateDisplay(data) {
  esp32UpdateDisplayFromPayload(data);
}

// Koristi vrijednost s brojača za POP unos
function esp32UseCountForPOP() {
  if (!esp32CounterData || !esp32CounterData.count) {
    showMessage('Nema podataka s brojača', 'warning');
    return;
  }
  
  var count = esp32CounterData.count;
  
  // Popuni polje za količinu
  var kolicinaInput = document.getElementById('tuberProizvedenaKolicina');
  if (kolicinaInput) {
    kolicinaInput.value = count;
    
    // Trigeraj izračun skidanja ako postoji
    if (typeof tuberIzracunajSkidanje === 'function') {
      tuberIzracunajSkidanje();
    }
    
    showMessage('✅ Količina ' + count.toLocaleString('hr-HR') + ' prenesena s ESP32 brojača', 'success');
    
    // Scroll do forme za unos
    kolicinaInput.scrollIntoView({ behavior: 'smooth', block: 'center' });
    kolicinaInput.focus();
  }
}

// Osvježi brojač
async function esp32RefreshCounter() {
  var machineCode = ESP32_MACHINE_CODES[window.LINIJA];
  if (machineCode) {
    showLoading('Osvježavanje...');
    await esp32LoadCounterStatus(machineCode);
    hideLoading();
    showMessage('Brojač osvježen', 'success');
  }
}

// Zaustavi brojač
async function esp32StopCounter() {
  if (!confirm('Jeste li sigurni da želite zaustaviti ESP32 brojač?')) return;
  
  var machineCode = ESP32_MACHINE_CODES[window.LINIJA];
  if (!machineCode) return;
  
  showLoading('Zaustavljanje...');
  try {
    var { data, error } = await initSupabase()
      .rpc('stop_machine_counter', { 
        p_machine_code: machineCode,
        p_final_count: esp32CounterData ? esp32CounterData.count : null
      });
    
    if (error) throw error;
    
    showMessage('✅ Brojač zaustavljen', 'success');
    document.getElementById('esp32CounterWidget').style.display = 'none';
    esp32CounterData = null;
  } catch (e) {
    showMessage('Greška: ' + e.message, 'error');
  } finally {
    hideLoading();
  }
}

// Pokreni brojač za trenutni RN
async function esp32StartCounter() {
  if (!tuberTrenutniRNData) {
    showMessage('Prvo odaberite radni nalog', 'warning');
    return;
  }
  
  var machineCode = ESP32_MACHINE_CODES[window.LINIJA];
  if (!machineCode) return;
  
  showLoading('Pokretanje brojača...');
  try {
    var { data, error } = await initSupabase()
      .rpc('start_machine_counter', {
        p_machine_code: machineCode,
        p_work_order_id: tuberTrenutniRNData.id,
        p_work_order_number: tuberTrenutniRNData.wo_number,
        p_target_quantity: tuberTrenutniRNData.quantity || 0
      });
    
    if (error) throw error;
    
    showMessage('✅ ESP32 brojač pokrenut za ' + tuberTrenutniRNData.wo_number, 'success');
    
    // Učitaj stanje
    await esp32LoadCounterStatus(machineCode);
  } catch (e) {
    showMessage('Greška: ' + e.message, 'error');
  } finally {
    hideLoading();
  }
}

// Cleanup kad se napusti stranica
function esp32Cleanup() {
  if (esp32Subscription) {
    esp32Subscription.unsubscribe();
    esp32Subscription = null;
  }
  if (esp32PollInterval) {
    clearInterval(esp32PollInterval);
    esp32PollInterval = null;
  }
}

// Dodaj cleanup u window unload
window.addEventListener('beforeunload', esp32Cleanup);

// Dodaj u postojeću tuberPrikaziTrenutni funkciju:
// Na kraju funkcije tuberPrikaziTrenutni, dodaj:
//   esp32Init();

// Ili modificiraj originalnu funkciju da poziva esp32Init() nakon što prikaže RN


/* ============================================
 * 4. MODIFIKACIJA POSTOJEĆE FUNKCIJE
 * ============================================
 * 
 * U funkciji tuberPrikaziTrenutni (oko linije 2897), 
 * dodaj na kraj funkcije:
 * 
 *   // ESP32 brojač
 *   esp32Init();
 * 
 * Tako će se brojač inicijalizirati kad se odabere RN.
 * ============================================ */
