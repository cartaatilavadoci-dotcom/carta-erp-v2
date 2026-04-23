// ============================================
// CARTA ERP - Konfiguracija
// ============================================

const CONFIG = {
  SUPABASE_URL: 'https://gusudzydgofdcywmvwbh.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd1c3VkenlkZ29mZGN5d212d2JoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU2OTg5ODEsImV4cCI6MjA4MTI3NDk4MX0.nvaFFyJcyNKWI2Yg2TpynDX-NsPdfzg3Cp87ur_E5qU',
  
  APP_NAME: 'Carta ERP',
  VERSION: '2.0.0',
  SESSION_KEY: 'carta_erp_session',
  SESSION_DURATION: 8 * 60 * 60 * 1000,

  // ============================================
  // CAMERA PROXY - promijeni IP kad instaliras proxy na drugo racunalo
  // ============================================
  CAMERA_PROXY_URL: 'http://192.168.1.199:3001',

  // Uloge se ucitavaju dinamicki iz prod_roles tablice
  // Ovo je fallback ako baza nije dostupna
  DEFAULT_ROLES: {
    'superadmin': ['*'],
    'admin': ['dashboard', 'djelatnici', 'place', 'produktivnost', 'izvjestaji', 'terminal', 'planiranje', 'artikli', 'skladiste', 'rezac', 'tisak', 'tuber', 'bottomer-wh', 'bottomer-nli', 'bottomer-slagac', 'bottomer-voditelj', 'pvnd', 'otpreme', 'kuhinja', 'oee', 'produktivnost-strojara', 'raspored-nli', 'raspored-wh', 'raspored-tisak', 'maintenance', 'videonadzor', 'ovjera-rn', 'krediti'],
    'racunovodstvo': ['dashboard', 'djelatnici', 'place', 'produktivnost', 'izvjestaji', 'planiranje'],
    'uprava': ['dashboard', 'planiranje', 'ovjera-rn', 'artikli', 'pvnd', 'otpreme', 'izvjestaji', 'oee', 'produktivnost-strojara', 'raspored-nli', 'raspored-wh', 'raspored-tisak', 'videonadzor'],
    'koordinator-proizvodnje': ['dashboard', 'planiranje', 'ovjera-rn', 'artikli', 'skladiste', 'otpreme', 'oee', 'produktivnost-strojara', 'raspored-nli', 'raspored-wh', 'raspored-tisak', 'pvnd', 'videonadzor'],
    'voditelj-odrzavanja': ['dashboard', 'maintenance', 'skladiste', 'videonadzor'],
    'tuber-nli': ['dashboard', 'tuber', 'terminal'],
    'tuber-wh': ['dashboard', 'tuber', 'terminal'],
    'bottomer-nli': ['dashboard', 'bottomer-nli', 'bottomer-slagac', 'bottomer-voditelj', 'terminal'],
    'bottomer-wh': ['dashboard', 'bottomer-wh', 'bottomer-slagac', 'bottomer-voditelj', 'terminal'],
    'rezac': ['dashboard', 'rezac', 'terminal'],
    'skladiste': ['dashboard', 'skladiste', 'terminal'],
    'tisak': ['dashboard', 'tisak', 'raspored-tisak', 'terminal']
  },

  NAV_ITEMS: [
    { id: 'dashboard', icon: '📊', label: 'Pregled', section: null },
    // HR & Place
    { id: 'djelatnici', icon: '👥', label: 'Djelatnici', section: 'HR & Place' },
    { id: 'place', icon: '💰', label: 'Place', section: 'HR & Place' },
    { id: 'produktivnost', icon: '📈', label: 'Produktivnost', section: 'HR & Place' },
    { id: 'izvjestaji', icon: '📋', label: 'Izvjestaji', section: 'HR & Place' },
    { id: 'terminal', icon: '⏱️', label: 'Terminal', section: 'HR & Place' },
    // Proizvodnja
    { id: 'planiranje', icon: '📋', label: 'Planiranje', section: 'Proizvodnja' },
    { id: 'ovjera-rn', icon: '✅', label: 'Ovjera RN', section: 'Proizvodnja' },
    { id: 'artikli', icon: '📦', label: 'Artikli i Kupci', section: 'Proizvodnja' },
    { id: 'skladiste', icon: '🏭', label: 'Skladiste', section: 'Proizvodnja' },
    { id: 'rezac', icon: '✂️', label: 'Rezac', section: 'Proizvodnja' },
    { id: 'tisak', icon: '🖨️', label: 'Tisak', section: 'Proizvodnja' },
    { id: 'tuber', icon: '🧻', label: 'Tuber', section: 'Proizvodnja' },
    { id: 'bottomer-slagac', icon: '🏷️', label: 'Bottomer Slaganje', section: 'Proizvodnja' },
    { id: 'bottomer-voditelj', icon: '🔧', label: 'Bottomer Stroj', section: 'Proizvodnja' },
    { id: 'pvnd', icon: '📊', label: 'PVND', section: 'Proizvodnja' },
    { id: 'otpreme', icon: '🚛', label: 'Otpreme', section: 'Proizvodnja' },
    { id: 'kuhinja', icon: '🍯', label: 'Kuhinja ljepila', section: 'Proizvodnja' },
    { id: 'oee', icon: '⚡', label: 'OEE', section: 'Proizvodnja' },
    { id: 'produktivnost-strojara', icon: '👷', label: 'Produktivnost Strojara', section: 'Proizvodnja' },
    // Upravljanje
    { id: 'raspored-nli', icon: '📅', label: 'Raspored NLI', section: 'Upravljanje' },
    { id: 'raspored-wh', icon: '📅', label: 'Raspored WH', section: 'Upravljanje' },
    { id: 'raspored-tisak', icon: '🎨', label: 'Raspored Tisak', section: 'Upravljanje' },
    { id: 'videonadzor', icon: '📹', label: 'Videonadzor', section: 'Upravljanje' },
    { id: 'maintenance', icon: '🔧', label: 'Odrzavanje', section: 'Upravljanje' },
    { id: 'krediti', icon: '🏦', label: 'Krediti', section: 'Upravljanje' },
    { id: 'postavke', icon: '⚙️', label: 'Postavke', section: 'Upravljanje', superadminOnly: true }
  ]
};

Object.freeze(CONFIG);
