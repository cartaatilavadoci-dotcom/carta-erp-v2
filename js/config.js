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
    'admin': ['dashboard', 'djelatnici', 'place', 'produktivnost', 'izvjestaji', 'terminal', 'planiranje', 'artikli', 'skladiste', 'rezac', 'tisak', 'tuber', 'bottomer-wh', 'bottomer-nli', 'bottomer-slagac', 'bottomer-voditelj', 'pvnd', 'otpreme', 'kuhinja', 'oee', 'produktivnost-strojara', 'raspored-nli', 'raspored-wh', 'raspored-tisak', 'maintenance', 'videonadzor', 'ovjera-rn', 'krediti', 'iso-pregled', 'iso-dokumenti', 'iso-nesukladnosti', 'iso-capa', 'iso-ciljevi', 'iso-procesi', 'iso-rizici', 'iso-auditi', 'iso-dobavljaci', 'iso-osposobljavanje', 'iso-mjerna-oprema', 'iso-reklamacije', 'iso-ocjena-uprave'],
    'racunovodstvo': ['dashboard', 'djelatnici', 'place', 'produktivnost', 'izvjestaji', 'planiranje', 'oee', 'iso-pregled', 'iso-dokumenti', 'iso-ciljevi', 'iso-ocjena-uprave', 'iso-osposobljavanje'],
    'uprava': ['dashboard', 'planiranje', 'ovjera-rn', 'artikli', 'pvnd', 'otpreme', 'izvjestaji', 'oee', 'produktivnost-strojara', 'raspored-nli', 'raspored-wh', 'raspored-tisak', 'videonadzor', 'iso-pregled', 'iso-dokumenti', 'iso-nesukladnosti', 'iso-capa', 'iso-ciljevi', 'iso-procesi', 'iso-rizici', 'iso-auditi', 'iso-dobavljaci', 'iso-osposobljavanje', 'iso-mjerna-oprema', 'iso-reklamacije', 'iso-ocjena-uprave'],
    'koordinator-proizvodnje': ['dashboard', 'planiranje', 'ovjera-rn', 'artikli', 'skladiste', 'otpreme', 'oee', 'produktivnost-strojara', 'raspored-nli', 'raspored-wh', 'raspored-tisak', 'pvnd', 'videonadzor', 'iso-pregled', 'iso-nesukladnosti', 'iso-capa', 'iso-procesi', 'iso-ciljevi', 'iso-rizici', 'iso-reklamacije', 'iso-dokumenti', 'iso-mjerna-oprema'],
    'voditelj-odrzavanja': ['dashboard', 'maintenance', 'skladiste', 'videonadzor', 'oee', 'iso-pregled', 'iso-mjerna-oprema', 'iso-nesukladnosti', 'iso-capa', 'iso-rizici', 'iso-dokumenti'],
    'koordinator-odrzavanja': ['dashboard', 'maintenance', 'skladiste', 'videonadzor', 'oee', 'iso-pregled', 'iso-mjerna-oprema', 'iso-nesukladnosti', 'iso-capa', 'iso-rizici', 'iso-dokumenti', 'iso-osposobljavanje'],
    'tuber-nli': ['dashboard', 'tuber', 'terminal', 'oee'],
    'tuber-wh': ['dashboard', 'tuber', 'terminal', 'oee'],
    'bottomer-nli': ['dashboard', 'bottomer-nli', 'bottomer-slagac', 'bottomer-voditelj', 'terminal', 'oee'],
    'bottomer-wh': ['dashboard', 'bottomer-wh', 'bottomer-slagac', 'bottomer-voditelj', 'terminal', 'oee'],
    'rezac': ['dashboard', 'rezac', 'terminal', 'oee'],
    'skladiste': ['dashboard', 'skladiste', 'terminal', 'oee'],
    'tisak': ['dashboard', 'tisak', 'raspored-tisak', 'terminal', 'oee']
  },

  // NAV_ITEMS — icon polje je naziv SVG ikone (vidi css/icons.css). Render
  // u js/utils.js buildSidebar() i js/mobile.js radi kao <span class="svg-icon
  // svg-icon-{icon}"></span>. NE koristi emoji — Pravilo 25 + ujednačen stil.
  NAV_ITEMS: [
    { id: 'dashboard', icon: 'dashboard', label: 'Pregled', section: null },
    // HR & Place
    { id: 'djelatnici', icon: 'users', label: 'Djelatnici', section: 'HR & Place' },
    { id: 'place', icon: 'wallet', label: 'Place', section: 'HR & Place' },
    { id: 'produktivnost', icon: 'trending-up', label: 'Produktivnost', section: 'HR & Place' },
    { id: 'izvjestaji', icon: 'file-text', label: 'Izvjestaji', section: 'HR & Place' },
    { id: 'terminal', icon: 'clock', label: 'Terminal', section: 'HR & Place' },
    // Proizvodnja
    { id: 'planiranje', icon: 'clipboard-list', label: 'Planiranje', section: 'Proizvodnja' },
    { id: 'ovjera-rn', icon: 'check-square', label: 'Ovjera RN', section: 'Proizvodnja' },
    { id: 'artikli', icon: 'package', label: 'Artikli i Kupci', section: 'Proizvodnja' },
    { id: 'skladiste', icon: 'warehouse', label: 'Skladiste', section: 'Proizvodnja' },
    { id: 'rezac', icon: 'scissors', label: 'Rezac', section: 'Proizvodnja' },
    { id: 'tisak', icon: 'printer', label: 'Tisak', section: 'Proizvodnja' },
    { id: 'tuber', icon: 'cylinder', label: 'Tuber', section: 'Proizvodnja' },
    { id: 'bottomer-slagac', icon: 'layers', label: 'Bottomer Slaganje', section: 'Proizvodnja' },
    { id: 'bottomer-voditelj', icon: 'cog', label: 'Bottomer Stroj', section: 'Proizvodnja' },
    { id: 'pvnd', icon: 'bar-chart-2', label: 'PVND', section: 'Proizvodnja' },
    { id: 'otpreme', icon: 'truck', label: 'Otpreme', section: 'Proizvodnja' },
    { id: 'kuhinja', icon: 'droplet', label: 'Kuhinja ljepila', section: 'Proizvodnja' },
    { id: 'oee', icon: 'zap', label: 'OEE', section: 'Proizvodnja' },
    { id: 'produktivnost-strojara', icon: 'hard-hat', label: 'Produktivnost Strojara', section: 'Proizvodnja' },
    // Upravljanje
    { id: 'raspored-nli', icon: 'calendar', label: 'Raspored NLI', section: 'Upravljanje' },
    { id: 'raspored-wh', icon: 'calendar', label: 'Raspored WH', section: 'Upravljanje' },
    { id: 'raspored-tisak', icon: 'palette', label: 'Raspored Tisak', section: 'Upravljanje' },
    { id: 'videonadzor', icon: 'video', label: 'Videonadzor', section: 'Upravljanje' },
    { id: 'maintenance', icon: 'wrench', label: 'Odrzavanje', section: 'Upravljanje' },
    { id: 'krediti', icon: 'landmark', label: 'Krediti', section: 'Upravljanje' },
    // ISO 9001 — Sustav kvalitete
    { id: 'iso-pregled', icon: 'shield-check', label: 'ISO Pregled', section: 'ISO 9001' },
    { id: 'iso-dokumenti', icon: 'file-text', label: 'Dokumenti', section: 'ISO 9001' },
    { id: 'iso-nesukladnosti', icon: 'alert-triangle', label: 'Nesukladnosti', section: 'ISO 9001' },
    { id: 'iso-capa', icon: 'refresh-cw', label: 'CAPA radnje', section: 'ISO 9001' },
    { id: 'iso-ciljevi', icon: 'target', label: 'Ciljevi kvalitete', section: 'ISO 9001' },
    { id: 'iso-procesi', icon: 'workflow', label: 'Procesi', section: 'ISO 9001' },
    { id: 'iso-rizici', icon: 'globe', label: 'Registar rizika', section: 'ISO 9001' },
    { id: 'iso-auditi', icon: 'search', label: 'Interni auditi', section: 'ISO 9001' },
    { id: 'iso-dobavljaci', icon: 'building-2', label: 'Ocjena dobavljača', section: 'ISO 9001' },
    { id: 'iso-osposobljavanje', icon: 'graduation-cap', label: 'Osposobljavanja', section: 'ISO 9001' },
    { id: 'iso-mjerna-oprema', icon: 'ruler', label: 'Mjerna oprema', section: 'ISO 9001' },
    { id: 'iso-reklamacije', icon: 'mail-warning', label: 'Reklamacije kupaca', section: 'ISO 9001' },
    { id: 'iso-ocjena-uprave', icon: 'briefcase', label: 'Ocjena uprave', section: 'ISO 9001' },
    { id: 'postavke', icon: 'settings', label: 'Postavke', section: 'Upravljanje', superadminOnly: true }
  ]
};

Object.freeze(CONFIG);
