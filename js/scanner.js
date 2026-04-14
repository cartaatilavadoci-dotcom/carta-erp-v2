// ============================================
// CARTA ERP - Barcode & QR Scanner Modul
// Koristi html5-qrcode biblioteku
// ============================================

const BarcodeScanner = {
  scanner: null,
  isScanning: false,
  currentCallback: null,
  
  // ============================================
  // INICIJALIZACIJA
  // ============================================
  
  // Provjeri je li biblioteka učitana
  isLibraryLoaded: function() {
    return typeof Html5Qrcode !== 'undefined';
  },
  
  // Dinamički učitaj biblioteku ako nije
  loadLibrary: function() {
    return new Promise(function(resolve, reject) {
      if (BarcodeScanner.isLibraryLoaded()) {
        resolve();
        return;
      }
      
      var script = document.createElement('script');
      script.src = 'https://unpkg.com/html5-qrcode@2.3.8/html5-qrcode.min.js';
      script.onload = function() {
        console.log('[SCANNER] Biblioteka učitana');
        resolve();
      };
      script.onerror = function() {
        reject(new Error('Nije moguće učitati scanner biblioteku'));
      };
      document.head.appendChild(script);
    });
  },
  
  // ============================================
  // KREIRANJE MODALA
  // ============================================
  
  createModal: function() {
    // Ako modal već postoji, vrati ga
    var existing = document.getElementById('scannerModal');
    if (existing) return existing;
    
    var modal = document.createElement('div');
    modal.id = 'scannerModal';
    modal.className = 'scanner-modal';
    modal.innerHTML = `
      <div class="scanner-modal-content">
        <div class="scanner-header">
          <h3>📷 Skeniraj barkod/QR</h3>
          <button class="scanner-close" onclick="BarcodeScanner.stop()">&times;</button>
        </div>
        
        <div class="scanner-body">
          <!-- Područje za kameru -->
          <div id="scannerReader"></div>
          
          <!-- Status -->
          <div id="scannerStatus" class="scanner-status">
            Usmjerite kameru prema barkodu ili QR kodu
          </div>
          
          <!-- Rezultat -->
          <div id="scannerResult" class="scanner-result" style="display: none;">
            <div class="result-label">Skenirano:</div>
            <div id="scannerResultText" class="result-text"></div>
          </div>
          
          <!-- Ručni unos -->
          <div class="scanner-manual">
            <div class="manual-divider">
              <span>ili unesite ručno</span>
            </div>
            <div class="manual-input-group">
              <input type="text" id="scannerManualInput" placeholder="Unesite kod..." class="form-control">
              <button class="btn btn-primary" onclick="BarcodeScanner.submitManual()">OK</button>
            </div>
          </div>
        </div>
        
        <div class="scanner-footer">
          <button class="btn btn-outline" onclick="BarcodeScanner.stop()">Odustani</button>
        </div>
      </div>
    `;
    
    document.body.appendChild(modal);
    this.addStyles();
    
    return modal;
  },
  
  addStyles: function() {
    if (document.getElementById('scannerStyles')) return;
    
    var style = document.createElement('style');
    style.id = 'scannerStyles';
    style.textContent = `
      .scanner-modal {
        display: none;
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.9);
        z-index: 99999;
        justify-content: center;
        align-items: center;
      }
      .scanner-modal.active {
        display: flex;
      }
      
      .scanner-modal-content {
        background: white;
        border-radius: 16px;
        width: 95%;
        max-width: 500px;
        max-height: 90vh;
        overflow: hidden;
        display: flex;
        flex-direction: column;
      }
      
      .scanner-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 15px 20px;
        background: linear-gradient(135deg, #1e3a5f 0%, #2d5a87 100%);
        color: white;
      }
      .scanner-header h3 {
        margin: 0;
        font-size: 1.1em;
      }
      .scanner-close {
        background: rgba(255,255,255,0.2);
        border: none;
        color: white;
        font-size: 1.5em;
        width: 36px;
        height: 36px;
        border-radius: 50%;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .scanner-close:hover {
        background: rgba(255,255,255,0.3);
      }
      
      .scanner-body {
        padding: 20px;
        flex: 1;
        overflow-y: auto;
      }
      
      #scannerReader {
        width: 100%;
        min-height: 250px;
        background: #000;
        border-radius: 12px;
        overflow: hidden;
      }
      #scannerReader video {
        width: 100% !important;
        border-radius: 12px;
      }
      
      .scanner-status {
        text-align: center;
        padding: 15px;
        color: #666;
        font-size: 0.9em;
      }
      .scanner-status.success {
        color: #2e7d32;
        font-weight: 600;
      }
      .scanner-status.error {
        color: #c62828;
      }
      
      .scanner-result {
        background: #e8f5e9;
        border: 2px solid #4caf50;
        border-radius: 12px;
        padding: 15px;
        margin-top: 15px;
      }
      .result-label {
        font-size: 0.85em;
        color: #666;
        margin-bottom: 5px;
      }
      .result-text {
        font-size: 1.2em;
        font-weight: 700;
        color: #2e7d32;
        word-break: break-all;
      }
      
      .scanner-manual {
        margin-top: 20px;
      }
      .manual-divider {
        text-align: center;
        position: relative;
        margin: 15px 0;
      }
      .manual-divider::before {
        content: '';
        position: absolute;
        top: 50%;
        left: 0;
        right: 0;
        height: 1px;
        background: #ddd;
      }
      .manual-divider span {
        background: white;
        padding: 0 15px;
        color: #999;
        font-size: 0.85em;
        position: relative;
      }
      .manual-input-group {
        display: flex;
        gap: 10px;
      }
      .manual-input-group input {
        flex: 1;
        padding: 12px 15px;
        font-size: 1em;
        border: 2px solid #ddd;
        border-radius: 8px;
      }
      .manual-input-group input:focus {
        border-color: #1976d2;
        outline: none;
      }
      .manual-input-group button {
        padding: 12px 25px;
      }
      
      .scanner-footer {
        padding: 15px 20px;
        background: #f5f5f5;
        display: flex;
        justify-content: center;
      }
      
      /* Mobile optimizacije */
      @media (max-width: 480px) {
        .scanner-modal-content {
          width: 100%;
          height: 100%;
          max-height: 100%;
          border-radius: 0;
        }
        #scannerReader {
          min-height: 300px;
        }
      }
    `;
    document.head.appendChild(style);
  },
  
  // ============================================
  // SKENIRANJE
  // ============================================
  
  // Pokreni skener
  // callback(code, format) - poziva se kad se skenira kod
  // options: { formats: ['qr', 'ean13', 'code128'], title: 'Naslov' }
  start: async function(callback, options) {
    options = options || {};
    this.currentCallback = callback;
    
    try {
      // Učitaj biblioteku ako treba
      await this.loadLibrary();
      
      // Kreiraj modal
      var modal = this.createModal();
      modal.classList.add('active');
      
      // Ažuriraj naslov ako je zadan
      if (options.title) {
        modal.querySelector('.scanner-header h3').textContent = '📷 ' + options.title;
      }
      
      // Reset UI
      document.getElementById('scannerResult').style.display = 'none';
      document.getElementById('scannerStatus').textContent = 'Pokrećem kameru...';
      document.getElementById('scannerStatus').className = 'scanner-status';
      document.getElementById('scannerManualInput').value = '';
      
      // Pokreni skener
      this.scanner = new Html5Qrcode('scannerReader');
      
      var config = {
        fps: 10,
        qrbox: { width: 250, height: 250 },
        aspectRatio: 1.0
      };
      
      // Formati za skeniranje
      var formatsToSupport = [];
      if (typeof Html5QrcodeSupportedFormats !== 'undefined') {
        formatsToSupport = [
          Html5QrcodeSupportedFormats.QR_CODE,
          Html5QrcodeSupportedFormats.EAN_13,
          Html5QrcodeSupportedFormats.EAN_8,
          Html5QrcodeSupportedFormats.CODE_128,
          Html5QrcodeSupportedFormats.CODE_39,
          Html5QrcodeSupportedFormats.UPC_A,
          Html5QrcodeSupportedFormats.UPC_E
        ];
        config.formatsToSupport = formatsToSupport;
      }
      
      var self = this;
      
      await this.scanner.start(
        { facingMode: 'environment' }, // Stražnja kamera
        config,
        function(decodedText, decodedResult) {
          // Uspješno skenirano
          self.onScanSuccess(decodedText, decodedResult);
        },
        function(errorMessage) {
          // Ignoriramo greške dok skenira (normalno ponašanje)
        }
      );
      
      this.isScanning = true;
      document.getElementById('scannerStatus').textContent = 'Usmjerite kameru prema barkodu ili QR kodu';
      console.log('[SCANNER] Skeniranje pokrenuto');
      
    } catch (error) {
      console.error('[SCANNER] Greška:', error);
      document.getElementById('scannerStatus').textContent = 'Greška: ' + error.message;
      document.getElementById('scannerStatus').className = 'scanner-status error';
      
      // Ako kamera nije dostupna, fokusiraj se na ručni unos
      if (error.message && error.message.includes('Permission')) {
        document.getElementById('scannerStatus').textContent = 'Kamera nije dostupna. Koristite ručni unos.';
        document.getElementById('scannerManualInput').focus();
      }
    }
  },
  
  // Kada se uspješno skenira
  onScanSuccess: function(decodedText, decodedResult) {
    console.log('[SCANNER] Skenirano:', decodedText);
    
    // Vibriraj ako je podržano
    if (navigator.vibrate) {
      navigator.vibrate(200);
    }
    
    // Prikaži rezultat
    document.getElementById('scannerResult').style.display = 'block';
    document.getElementById('scannerResultText').textContent = decodedText;
    document.getElementById('scannerStatus').textContent = '✅ Uspješno skenirano!';
    document.getElementById('scannerStatus').className = 'scanner-status success';
    
    // Zaustavi skeniranje
    this.stopScanner();
    
    // Pozovi callback nakon kratke pauze (da korisnik vidi rezultat)
    var self = this;
    setTimeout(function() {
      self.processResult(decodedText);
    }, 500);
  },
  
  // Ručni unos
  submitManual: function() {
    var input = document.getElementById('scannerManualInput');
    var code = input.value.trim();
    
    if (!code) {
      input.focus();
      return;
    }
    
    console.log('[SCANNER] Ručni unos:', code);
    this.processResult(code);
  },
  
  // Procesiraj rezultat (poziva callback)
  processResult: function(code) {
    if (this.currentCallback) {
      this.currentCallback(code);
    }
    this.stop();
  },
  
  // Zaustavi samo skener (ne zatvara modal)
  stopScanner: async function() {
    if (this.scanner && this.isScanning) {
      try {
        await this.scanner.stop();
        this.isScanning = false;
      } catch (e) {
        console.log('[SCANNER] Stop error:', e);
      }
    }
  },
  
  // Zaustavi sve i zatvori modal
  stop: async function() {
    await this.stopScanner();
    
    var modal = document.getElementById('scannerModal');
    if (modal) {
      modal.classList.remove('active');
    }
    
    this.currentCallback = null;
    console.log('[SCANNER] Zatvoreno');
  },
  
  // ============================================
  // LOOKUP FUNKCIJE - Pretraživanje u bazi
  // ============================================
  
  // Pronađi rolu po roll_code (barkod)
  findRoll: async function(code) {
    try {
      var result = await initSupabase()
        .from('prod_inventory_rolls')
        .select('*')
        .eq('roll_code', code)
        .single();
      
      if (result.error && result.error.code !== 'PGRST116') {
        throw result.error;
      }
      
      return result.data || null;
    } catch (e) {
      console.error('[SCANNER] findRoll error:', e);
      return null;
    }
  },
  
  // Pronađi rolu po internal_id
  findRollByInternalId: async function(internalId) {
    try {
      var result = await initSupabase()
        .from('prod_inventory_rolls')
        .select('*')
        .eq('internal_id', parseInt(internalId))
        .single();
      
      if (result.error && result.error.code !== 'PGRST116') {
        throw result.error;
      }
      
      return result.data || null;
    } catch (e) {
      console.error('[SCANNER] findRollByInternalId error:', e);
      return null;
    }
  },
  
  // Pronađi paletu (GOP) po pallet_number
  findPallet: async function(palletNumber) {
    try {
      var result = await initSupabase()
        .from('prod_inventory_gop')
        .select('*')
        .eq('pallet_number', palletNumber)
        .single();
      
      if (result.error && result.error.code !== 'PGRST116') {
        throw result.error;
      }
      
      return result.data || null;
    } catch (e) {
      console.error('[SCANNER] findPallet error:', e);
      return null;
    }
  },
  
  // Pronađi traku po strip_code
  findStrip: async function(code) {
    try {
      var result = await initSupabase()
        .from('prod_inventory_strips')
        .select('*')
        .eq('strip_code', code)
        .single();
      
      if (result.error && result.error.code !== 'PGRST116') {
        throw result.error;
      }
      
      return result.data || null;
    } catch (e) {
      console.error('[SCANNER] findStrip error:', e);
      return null;
    }
  },
  
  // Pronađi otisnutu rolu po roll_code
  findPrintedRoll: async function(code) {
    try {
      var result = await initSupabase()
        .from('prod_inventory_printed')
        .select('*')
        .eq('roll_code', code)
        .single();
      
      if (result.error && result.error.code !== 'PGRST116') {
        throw result.error;
      }
      
      return result.data || null;
    } catch (e) {
      console.error('[SCANNER] findPrintedRoll error:', e);
      return null;
    }
  },
  
  // Univerzalna pretraga - traži u svim tablicama
  findAny: async function(code) {
    // Probaj prvo kao roll_code
    var roll = await this.findRoll(code);
    if (roll) return { type: 'roll', data: roll };
    
    // Probaj kao internal_id (ako je broj)
    if (/^\d+$/.test(code)) {
      roll = await this.findRollByInternalId(code);
      if (roll) return { type: 'roll', data: roll };
    }
    
    // Probaj kao paleta
    var pallet = await this.findPallet(code);
    if (pallet) return { type: 'pallet', data: pallet };
    
    // Probaj kao traka
    var strip = await this.findStrip(code);
    if (strip) return { type: 'strip', data: strip };
    
    // Probaj kao otisnuta rola
    var printed = await this.findPrintedRoll(code);
    if (printed) return { type: 'printed', data: printed };
    
    return null;
  },
  
  // ============================================
  // HELPER - Skeniraj i pronađi
  // ============================================
  
  // Skeniraj i automatski pronađi u bazi
  // type: 'roll', 'pallet', 'strip', 'printed', 'any'
  // onFound(result) - callback s pronađenim podacima
  // onNotFound(code) - callback ako nije pronađeno
  scanAndFind: function(type, onFound, onNotFound) {
    var self = this;
    var title = 'Skeniraj ';
    
    switch (type) {
      case 'roll': title += 'rolu'; break;
      case 'pallet': title += 'paletu'; break;
      case 'strip': title += 'traku'; break;
      case 'printed': title += 'otisnutu rolu'; break;
      default: title += 'barkod/QR';
    }
    
    this.start(async function(code) {
      if (typeof showLoading === 'function') showLoading('Tražim u bazi...');
      
      var result = null;
      
      try {
        switch (type) {
          case 'roll':
            result = await self.findRoll(code);
            if (!result && /^\d+$/.test(code)) {
              result = await self.findRollByInternalId(code);
            }
            break;
          case 'pallet':
            result = await self.findPallet(code);
            break;
          case 'strip':
            result = await self.findStrip(code);
            break;
          case 'printed':
            result = await self.findPrintedRoll(code);
            break;
          default:
            var found = await self.findAny(code);
            if (found) {
              result = found;
            }
        }
        
        if (typeof hideLoading === 'function') hideLoading();
        
        if (result) {
          if (typeof showMessage === 'function') {
            showMessage('✅ Pronađeno!', 'success');
          }
          if (onFound) onFound(result, code);
        } else {
          if (typeof showMessage === 'function') {
            showMessage('Kod "' + code + '" nije pronađen', 'warning');
          }
          if (onNotFound) onNotFound(code);
        }
        
      } catch (e) {
        if (typeof hideLoading === 'function') hideLoading();
        console.error('[SCANNER] scanAndFind error:', e);
        if (typeof showMessage === 'function') {
          showMessage('Greška pri pretrazi: ' + e.message, 'error');
        }
      }
      
    }, { title: title });
  }
};

// Globalna dostupnost
window.BarcodeScanner = BarcodeScanner;

// Keyboard shortcut za ručni unos (Enter)
document.addEventListener('keydown', function(e) {
  if (e.key === 'Enter') {
    var input = document.getElementById('scannerManualInput');
    if (input && document.activeElement === input) {
      BarcodeScanner.submitManual();
    }
  }
});

console.log('[SCANNER] Modul učitan');
