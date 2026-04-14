// ============================================
// CARTA ERP - SPA Router
// ============================================

const Router = {
  currentView: null,
  viewCache: {},
  activeTimers: [], // Track active timers for cleanup

  // Register timer for cleanup
  registerTimer(timerId) {
    this.activeTimers.push(timerId);
    return timerId;
  },

  // Cleanup all timers
  cleanup() {
    this.activeTimers.forEach(id => {
      clearTimeout(id);
      clearInterval(id);
    });
    this.activeTimers = [];
    
    // Call view-specific cleanup if exists
    if (typeof window.cleanupCurrentView === 'function') {
      try { window.cleanupCurrentView(); } catch(e) {}
    }
    window.cleanupCurrentView = null;
  },

  // Inicijalizacija
  init() {
    console.log('Router init');
    window.addEventListener('hashchange', () => {
      console.log('Hash changed to:', window.location.hash);
      this.handleRoute();
    });
    this.handleRoute();
  },

  // Navigacija
  navigate(viewId) {
    console.log('Navigate to:', viewId);
    window.location.hash = viewId;
  },

  // Handle route change
  async handleRoute() {
    let hash = window.location.hash.slice(1) || 'login';
    // Remove leading slash if present
    hash = hash.replace(/^\//, '');
    
    console.log('handleRoute - raw hash:', window.location.hash, '-> parsed:', hash);
    
    // Provjera autentifikacije
    if (hash !== 'login' && !Auth.checkSession()) {
      console.log('handleRoute - not authenticated, redirecting to login');
      this.navigate('login');
      return;
    }

    // Interni moduli koji nasljeđuju pristup od parent modula
    // (ne trebaju vlastitu dozvolu u prod_roles)
    const interniModuli = {
      'tuber-materijal': 'tuber',
      'slagac-pomocnik': 'bottomer-slagac'
    };

    // Provjera pristupa - koristi parent modul ako je interni
    const checkHash = interniModuli[hash] || hash;
    if (hash !== 'login' && !Auth.canAccess(checkHash)) {
      console.log('handleRoute - access denied for:', hash);
      showMessage('Nemate pristup ovoj stranici', 'error');
      this.navigate('dashboard');
      return;
    }

    console.log('handleRoute - proceeding with:', hash);

    // Toggle sidebar visibility
    const sidebar = document.getElementById('sidebar');
    const mainContent = document.getElementById('mainContent');
    if (hash === 'login') {
      if (sidebar) sidebar.style.display = 'none';
      if (mainContent) {
        mainContent.style.marginLeft = '0';
        mainContent.style.background = 'linear-gradient(135deg, #2c3e50 0%, #2a4d75 100%)';
      }
    } else {
      if (sidebar) sidebar.style.display = 'flex';
      if (mainContent) {
        mainContent.style.marginLeft = '';
        mainContent.style.background = '';
      }
    }

    await this.loadView(hash);
  },

  // Ucitaj view
  async loadView(viewId) {
    const container = document.getElementById('app-content');
    if (!container) {
      console.error('Container #app-content not found!');
      return;
    }

    // Cleanup previous view
    this.cleanup();

    console.log('Loading view:', viewId);
    showLoading();

    try {
      // Determine view path
      let viewPath;
      if (viewId === 'login') {
        viewPath = 'views/login.html';
      } else if (viewId === 'dashboard') {
        viewPath = 'views/dashboard.html';
      } else if (['djelatnici', 'place', 'produktivnost', 'izvjestaji', 'terminal', 'raspored-hr'].includes(viewId)) {
        viewPath = `views/hr/${viewId}.html`;
      } else if (['planiranje', 'artikli', 'skladiste', 'rezac', 'tisak', 'tuber', 'tuber-materijal', 'bottomer-wh', 'bottomer-nli', 'bottomer-slagac', 'bottomer-voditelj', 'pvnd', 'otpreme', 'kuhinja', 'oee', 'produktivnost-strojara', 'raspored-nli', 'raspored-wh', 'raspored-tisak', 'maintenance', 'videonadzor', 'slagac-pomocnik'].includes(viewId)) {
        viewPath = `views/proizvodnja/${viewId}.html`;
      } else if (['ovjera-rn'].includes(viewId)) {
        viewPath = `views/upravljanje/${viewId}.html`;
      } else if (['postavke', 'admin'].includes(viewId)) {
        viewPath = `views/admin/${viewId}.html`;
      } else {
        viewPath = 'views/404.html';
      }

      // Fetch view
      console.log('Fetching:', viewPath);
      const response = await fetch(viewPath);
      if (!response.ok) {
        console.error('Fetch failed:', response.status, response.statusText);
        throw new Error('View not found');
      }
      
      const html = await response.text();
      console.log('View loaded, length:', html.length);
      container.innerHTML = html;
      this.currentView = viewId;
      
      // Execute scripts in loaded HTML
      const scripts = container.querySelectorAll('script');
      scripts.forEach(oldScript => {
        const newScript = document.createElement('script');
        if (oldScript.src) {
          newScript.src = oldScript.src;
        } else {
          newScript.textContent = oldScript.textContent;
        }
        oldScript.parentNode.replaceChild(newScript, oldScript);
      });

      // Update sidebar active state
      this.updateSidebarActive(viewId);

      // Update page title
      const navItem = CONFIG.NAV_ITEMS.find(item => item.id === viewId);
      document.title = navItem ? `${navItem.label} | ${CONFIG.APP_NAME}` : CONFIG.APP_NAME;

      // Initialize view if has init function
      if (typeof window[`init${this.capitalize(viewId)}View`] === 'function') {
        await window[`init${this.capitalize(viewId)}View`]();
      }

    } catch (error) {
      console.error('Error loading view:', error);
      container.innerHTML = `
        <div class="card">
          <div class="card-header">Greska</div>
          <div class="card-body">
            <p>Nije moguce ucitati stranicu: ${viewId}</p>
            <button class="btn btn-primary" onclick="Router.navigate('dashboard')">
              Povratak na Dashboard
            </button>
          </div>
        </div>
      `;
    } finally {
      hideLoading();
    }
  },

  // Update sidebar active
  updateSidebarActive(viewId) {
    document.querySelectorAll('.nav-item').forEach(item => {
      item.classList.remove('active');
      if (item.dataset.view === viewId) {
        item.classList.add('active');
      }
    });
  },

  // Helper
  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1).replace(/-./g, x => x[1].toUpperCase());
  }
};
