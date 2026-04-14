// ============================================
// CARTA ERP - Utility funkcije
// ============================================

// ============================================
// PROIZVODNI DATUM (dan počinje u 06:00, ne u 00:00)
// ============================================
// U proizvodnji smjene idu:
// - 1. smjena: 06:00 - 14:00
// - 2. smjena: 14:00 - 22:00
// - 3. smjena: 22:00 - 06:00 (sljedeći kalendarski dan)
// Dakle ako je 03:00 ujutro 20.1., to je još uvijek proizvodni dan 19.1.

/**
 * Vraća proizvodni datum (YYYY-MM-DD format)
 * Ako je prije 06:00, vraća jučerašnji datum
 * @param {Date} date - Datum za provjeru (default: sada)
 * @returns {string} - Datum u formatu YYYY-MM-DD
 */
function getProductionDate(date = new Date()) {
  const d = new Date(date);
  // Ako je prije 06:00 LOKALNO, vrati jučerašnji datum
  if (d.getHours() < 6) {
    d.setDate(d.getDate() - 1);
  }
  // Vrati LOKALNI datum (ne UTC!)
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Vraća jučerašnji proizvodni datum
 * @returns {string} - Datum u formatu YYYY-MM-DD
 */
function getYesterdayProductionDate() {
  const d = new Date();
  // Ako je prije 06:00, "jučer" je zapravo prekjučer
  if (d.getHours() < 6) {
    d.setDate(d.getDate() - 2);
  } else {
    d.setDate(d.getDate() - 1);
  }
  // Vrati LOKALNI datum (ne UTC!)
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Vraća trenutnu proizvodnu smjenu (1, 2 ili 3)
 * @returns {number} - Broj smjene
 */
function getCurrentShiftNumber() {
  const hour = new Date().getHours();
  if (hour >= 6 && hour < 14) return 1;
  if (hour >= 14 && hour < 22) return 2;
  return 3; // 22:00 - 06:00
}

/**
 * Vraća proizvodni datum iz timestamp stringa
 * Koristi se za ispravno grupiranje podataka koji imaju kalendarski datum
 * VAŽNO: Vraća LOKALNI datum, ne UTC!
 * @param {string} timestamp - ISO timestamp (npr. "2026-01-20T02:43:12+00")
 * @returns {string} - Proizvodni datum u formatu YYYY-MM-DD
 */
function getProductionDateFromTimestamp(timestamp) {
  if (!timestamp) return null;
  const d = new Date(timestamp);
  if (isNaN(d)) return null;
  // Ako je prije 06:00 LOKALNO, vrati jučerašnji datum
  if (d.getHours() < 6) {
    d.setDate(d.getDate() - 1);
  }
  // Vrati LOKALNI datum (ne UTC!)
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Vraća ISO timestamp string za početak proizvodnog dana (za SQL upite)
 * VAŽNO: Vraća UTC ISO string koji odgovara lokalnom 06:00!
 * @param {string} dateStr - Datum u formatu YYYY-MM-DD (default: danas)
 * @returns {string} - UTC ISO timestamp
 */
function getProductionDayStartISO(dateStr) {
  const d = dateStr || getProductionDate();
  // ISPRAVNO: Eksplicitno kreiraj Date u lokalnom vremenu
  // new Date(year, month-1, day, hour) UVIJEK koristi lokalno vrijeme
  const parts = d.split('-');
  const localDate = new Date(parseInt(parts[0]), parseInt(parts[1])-1, parseInt(parts[2]), 6, 0, 0);
  // Vrati UTC ISO string
  return localDate.toISOString();
}

/**
 * Vraća ISO timestamp string za kraj proizvodnog dana (za SQL upite)
 * VAŽNO: Vraća UTC ISO string koji odgovara lokalnom 06:00 sljedećeg dana!
 * @param {string} dateStr - Datum u formatu YYYY-MM-DD (default: danas)
 * @returns {string} - UTC ISO timestamp
 */
function getProductionDayEndISO(dateStr) {
  const d = dateStr || getProductionDate();
  // ISPRAVNO: Eksplicitno kreiraj Date u lokalnom vremenu
  const parts = d.split('-');
  // Dodaj 1 dan za kraj proizvodnog dana
  const localDate = new Date(parseInt(parts[0]), parseInt(parts[1])-1, parseInt(parts[2]) + 1, 6, 0, 0);
  // Vrati UTC ISO string
  return localDate.toISOString();
}

// ============================================
// FORMATIRANJE BROJEVA I DATUMA
// ============================================

// Formatiranje brojeva (hr-HR)
function formatBroj(broj, decimale = 2) {
  if (broj === null || broj === undefined) return '-';
  return Number(broj).toLocaleString('hr-HR', {
    minimumFractionDigits: decimale,
    maximumFractionDigits: decimale
  });
}

// Formatiranje valute
function formatValuta(iznos) {
  if (iznos === null || iznos === undefined) return '-';
  return Number(iznos).toLocaleString('hr-HR', {
    style: 'currency',
    currency: 'EUR'
  });
}

// Formatiranje datuma
function formatDatum(datum, format = 'short') {
  if (!datum) return '-';
  const d = new Date(datum);
  if (isNaN(d)) return '-';
  
  const options = format === 'long' 
    ? { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }
    : { day: '2-digit', month: '2-digit', year: 'numeric' };
  
  return d.toLocaleDateString('hr-HR', options);
}

// Formatiranje vremena
function formatVrijeme(datum) {
  if (!datum) return '-';
  const d = new Date(datum);
  if (isNaN(d)) return '-';
  return d.toLocaleTimeString('hr-HR', { hour: '2-digit', minute: '2-digit' });
}

// Formatiranje datum + vrijeme
function formatDatumVrijeme(datum) {
  if (!datum) return '-';
  return `${formatDatum(datum)} ${formatVrijeme(datum)}`;
}

// Toast poruke
function showMessage(text, type = 'info') {
  let container = document.getElementById('toastContainer');
  if (!container) {
    container = document.createElement('div');
    container.id = 'toastContainer';
    container.className = 'toast-container';
    document.body.appendChild(container);
  }
  
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.innerHTML = `
    <span class="toast-icon">${type === 'success' ? '✓' : type === 'error' ? '✕' : type === 'warning' ? '⚠' : 'ℹ'}</span>
    <span class="toast-text">${text}</span>
  `;
  container.appendChild(toast);
  
  setTimeout(() => {
    toast.classList.add('fade-out');
    setTimeout(() => toast.remove(), 300);
  }, 3000);
}

// Loading overlay
function showLoading(text = 'Učitavanje...') {
  let overlay = document.getElementById('loadingOverlay');
  if (!overlay) {
    overlay = document.createElement('div');
    overlay.id = 'loadingOverlay';
    overlay.className = 'loading-overlay';
    overlay.innerHTML = `
      <div class="loading-content">
        <div class="spinner"></div>
        <p id="loadingText">${text}</p>
      </div>
    `;
    document.body.appendChild(overlay);
  }
  document.getElementById('loadingText').textContent = text;
  overlay.style.display = 'flex';
}

function hideLoading() {
  const overlay = document.getElementById('loadingOverlay');
  if (overlay) overlay.style.display = 'none';
}

// Modal functions
function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) modal.style.display = 'flex';
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) modal.style.display = 'none';
}

// Close modal on outside click
document.addEventListener('click', (e) => {
  if (e.target.classList.contains('modal')) {
    e.target.style.display = 'none';
  }
});

// Debounce
function debounce(func, wait) {
  let timeout;
  return function executedFunction(...args) {
    const later = () => {
      clearTimeout(timeout);
      func(...args);
    };
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
  };
}

// Escape HTML
function escapeHtml(text) {
  if (!text) return '';
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Generate UUID
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Get current month/year
function getCurrentMonth() {
  return new Date().getMonth() + 1;
}

function getCurrentYear() {
  return new Date().getFullYear();
}

// Croatian month names
const MJESECI = [
  'Siječanj', 'Veljača', 'Ožujak', 'Travanj', 'Svibanj', 'Lipanj',
  'Srpanj', 'Kolovoz', 'Rujan', 'Listopad', 'Studeni', 'Prosinac'
];

// Populate year select
function populateYearSelect(selectId, startYear = 2020) {
  const select = document.getElementById(selectId);
  if (!select) return;
  
  const currentYear = getCurrentYear();
  select.innerHTML = '';
  
  for (let year = currentYear + 1; year >= startYear; year--) {
    const option = document.createElement('option');
    option.value = year;
    option.textContent = year;
    if (year === currentYear) option.selected = true;
    select.appendChild(option);
  }
}

// Populate month select
function populateMonthSelect(selectId) {
  const select = document.getElementById(selectId);
  if (!select) return;
  
  const currentMonth = getCurrentMonth();
  select.innerHTML = '';
  
  MJESECI.forEach((naziv, index) => {
    const option = document.createElement('option');
    option.value = index + 1;
    option.textContent = naziv;
    if (index + 1 === currentMonth) option.selected = true;
    select.appendChild(option);
  });
}

// Build sidebar navigation
function buildSidebar() {
  var menu = document.getElementById('sidebarMenu');
  if (!menu) return;

  var navItems = Auth.getAllowedNavItems();
  var currentSection = null;
  var html = '';

  navItems.forEach(function(item) {
    // Add section separator if new section
    if (item.section && item.section !== currentSection) {
      currentSection = item.section;
      html += '<div class="nav-separator">' + item.section + '</div>';
    }

    html += '<a href="#' + item.id + '" class="nav-item" data-view="' + item.id + '">' +
            '<span class="nav-icon">' + item.icon + '</span>' +
            '<span class="nav-text">' + item.label + '</span>' +
            '</a>';
  });

  menu.innerHTML = html;

  // Update user info
  var user = Auth.getUser();
  if (user) {
    var nameEl = document.getElementById('userName');
    var roleEl = document.getElementById('userRole');
    if (nameEl) nameEl.textContent = user.name;
    if (roleEl) roleEl.textContent = user.role;
    
    // Prikaži gumb za promjenu lozinke samo za admin/superadmin
    var isAdmin = user.role === 'admin' || user.role === 'superadmin';
    var btnPassword = document.getElementById('btnChangePassword');
    var btnPasswordMobile = document.getElementById('btnChangePasswordMobile');
    
    if (btnPassword) {
      btnPassword.style.display = isAdmin ? 'inline-block' : 'none';
    }
    if (btnPasswordMobile) {
      btnPasswordMobile.style.display = isAdmin ? 'inline-block' : 'none';
    }
  }
  
  // Refresh mobile menu s istim dozvolama
  if (typeof window.refreshMobileMenu === 'function') {
    window.refreshMobileMenu();
  }
}

// Initialize app
async function initApp() {
  // Učitaj uloge iz baze
  if (Auth.checkSession()) {
    await Auth.loadRoles();
    buildSidebar();

    // Notifikacije - pokreni tek nakon valjane sesije
    if (typeof Notifications !== 'undefined') {
      Notifications.init();
    }
  }

  // Start router
  Router.init();
}
