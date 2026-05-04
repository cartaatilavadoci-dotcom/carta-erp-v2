/* ============================================
   CARTA ERP - Mobile Toggle
   ============================================ */

(function() {
  'use strict';

  document.addEventListener('DOMContentLoaded', initMobile);

  function initMobile() {
    createToggleButton();
    createMobileMenu();
    loadSavedMode();
  }

  // ============================================
  // TOGGLE GUMB
  // ============================================
  function createToggleButton() {
    if (document.querySelector('.mobile-toggle-btn')) return;
    
    var btn = document.createElement('button');
    btn.className = 'mobile-toggle-btn no-print';
    btn.setAttribute('aria-label', 'Toggle mobilni/desktop prikaz');
    btn.onclick = toggleMobileMode;
    document.body.appendChild(btn);
  }

  function toggleMobileMode() {
    var body = document.body;
    var screenWidth = window.innerWidth;
    
    if (screenWidth <= 768) {
      // Na malom ekranu - toggle desktop-forced
      body.classList.toggle('desktop-forced');
      body.classList.remove('mobile-mode');
      localStorage.setItem('cartaViewMode', body.classList.contains('desktop-forced') ? 'desktop' : 'auto');
    } else {
      // Na velikom ekranu - toggle mobile-mode
      body.classList.toggle('mobile-mode');
      body.classList.remove('desktop-forced');
      localStorage.setItem('cartaViewMode', body.classList.contains('mobile-mode') ? 'mobile' : 'desktop');
    }
    
    closeMobileMenu();
  }

  function loadSavedMode() {
    var saved = localStorage.getItem('cartaViewMode');
    var body = document.body;
    
    if (saved === 'mobile') {
      body.classList.add('mobile-mode');
    } else if (saved === 'desktop') {
      body.classList.add('desktop-forced');
    }
  }

  // ============================================
  // MOBILE MENU
  // ============================================
  function createMobileMenu() {
    // Hamburger gumb
    if (!document.querySelector('.mobile-menu-btn')) {
      var menuBtn = document.createElement('button');
      menuBtn.className = 'mobile-menu-btn no-print';
      menuBtn.innerHTML = '☰';
      menuBtn.onclick = toggleMobileMenu;
      document.body.appendChild(menuBtn);
    }

    // Overlay
    if (!document.querySelector('.mobile-menu-overlay')) {
      var overlay = document.createElement('div');
      overlay.className = 'mobile-menu-overlay no-print';
      overlay.id = 'mobileMenuOverlay';
      overlay.onclick = closeMobileMenu;
      document.body.appendChild(overlay);
    }

    // Side menu
    if (!document.querySelector('.mobile-side-menu')) {
      var menu = document.createElement('div');
      menu.className = 'mobile-side-menu no-print';
      menu.id = 'mobileSideMenu';
      menu.innerHTML = getMobileMenuContent();
      document.body.appendChild(menu);
    }

    // Bottom nav
    if (!document.querySelector('.mobile-bottom-nav')) {
      var nav = document.createElement('nav');
      nav.className = 'mobile-bottom-nav no-print';
      nav.innerHTML = getBottomNavContent();
      document.body.appendChild(nav);
    }
  }

  function getMobileMenuContent() {
    // Dohvati dozvoljene stavke iz Auth modula (poštuje role)
    var items = '';
    
    // Provjeri je li Auth dostupan i korisnik prijavljen
    if (typeof Auth !== 'undefined' && Auth.getUser()) {
      var allowedItems = Auth.getAllowedNavItems();
      var currentSection = null;
      
      allowedItems.forEach(function(item) {
        // Dodaj section separator ako je nova sekcija
        if (item.section && item.section !== currentSection) {
          currentSection = item.section;
          items += '<div class="mobile-menu-divider"></div>';
          items += '<div style="padding: 6px 15px; font-size: 0.7em; color: #999; text-transform: uppercase; letter-spacing: 1px;">' + item.section + '</div>';
        }
        
        // SVG ikona ako je item.icon semantic name, inace text (legacy emoji)
        var iconHtml = /^[a-z][a-z0-9-]*$/.test(item.icon)
          ? '<span class="menu-icon svg-icon svg-icon-' + item.icon + '"></span>'
          : '<span class="menu-icon">' + item.icon + '</span>';
        items += '<a href="#' + item.id + '" class="mobile-menu-item" onclick="closeMobileMenu()">' +
                 iconHtml +
                 '<span>' + item.label + '</span></a>';
      });
    }
    
    // Fallback na sidebar ako Auth nije dostupan
    if (!items) {
      var sidebar = document.querySelector('.sidebar-menu');
      if (sidebar) {
        var links = sidebar.querySelectorAll('.nav-item');
        links.forEach(function(link) {
          var viewId = link.getAttribute('data-view') || link.getAttribute('href') || '';
          viewId = viewId.replace('#', '');
          var icon = link.querySelector('.nav-icon');
          var iconText = icon ? icon.textContent : '📄';
          var text = link.textContent.replace(iconText, '').trim();
          
          items += '<a href="#' + viewId + '" class="mobile-menu-item" onclick="closeMobileMenu()">' +
                   '<span class="menu-icon">' + iconText + '</span>' +
                   '<span>' + text + '</span></a>';
        });
      }
    }

    // Ako još uvijek nema stavki, koristi default (za login screen)
    if (!items) {
      items = getDefaultMenuItems();
    }

    return '<div class="mobile-menu-header">' +
           '<h3>📋 CARTA ERP</h3>' +
           '<button class="mobile-menu-close" onclick="closeMobileMenu()">✕</button>' +
           '</div>' +
           '<div class="mobile-menu-items">' + items + '</div>';
  }

  function getDefaultMenuItems() {
    // Kompletna navigacija grupirana po sekcijama
    return '' +
           // Dashboard
           '<a href="#dashboard" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📊</span><span>Dashboard</span></a>' +
           
           // HR & Plaće
           '<div class="mobile-menu-divider"></div>' +
           '<div style="padding: 6px 15px; font-size: 0.7em; color: #999; text-transform: uppercase; letter-spacing: 1px;">HR & Plaće</div>' +
           '<a href="#djelatnici" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">👥</span><span>Djelatnici</span></a>' +
           '<a href="#place" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">💰</span><span>Plaće</span></a>' +
           '<a href="#produktivnost" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📈</span><span>Produktivnost</span></a>' +
           '<a href="#izvjestaji" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📋</span><span>Izvještaji</span></a>' +
           '<a href="#terminal" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">⏱️</span><span>Terminal</span></a>' +
           
           // Proizvodnja
           '<div class="mobile-menu-divider"></div>' +
           '<div style="padding: 6px 15px; font-size: 0.7em; color: #999; text-transform: uppercase; letter-spacing: 1px;">Proizvodnja</div>' +
           '<a href="#planiranje" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📋</span><span>Planiranje</span></a>' +
           '<a href="#artikli" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📦</span><span>Artikli</span></a>' +
           '<a href="#skladiste" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">🏭</span><span>Skladište</span></a>' +
           '<a href="#rezac" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">✂️</span><span>Rezač</span></a>' +
           '<a href="#tisak" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">🖨️</span><span>Tisak</span></a>' +
           '<a href="#tuber-wh" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">🧻</span><span>Tuber W&H</span></a>' +
           '<a href="#tuber-nli" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">🧻</span><span>Tuber NLI</span></a>' +
           '<a href="#bottomer-wh" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📦</span><span>Bottomer W&H</span></a>' +
           '<a href="#bottomer-nli" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📦</span><span>Bottomer NLI</span></a>' +
           '<a href="#bottomer-slagac" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">🏷️</span><span>Slaganje</span></a>' +
           '<a href="#bottomer-voditelj" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">🔧</span><span>Stroj</span></a>' +
           '<a href="#pvnd" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📊</span><span>PVND</span></a>' +
           '<a href="#otpreme" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">🚛</span><span>Otpreme</span></a>' +
           '<a href="#kuhinja" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">🍯</span><span>Kuhinja</span></a>' +
           
           // Upravljanje
           '<div class="mobile-menu-divider"></div>' +
           '<div style="padding: 6px 15px; font-size: 0.7em; color: #999; text-transform: uppercase; letter-spacing: 1px;">Upravljanje</div>' +
           '<a href="#raspored-nli" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📅</span><span>Raspored NLI</span></a>' +
           '<a href="#raspored-wh" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📅</span><span>Raspored WH</span></a>' +
           '<a href="#videonadzor" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">📹</span><span>Kamere</span></a>' +
           '<a href="#maintenance" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">🔧</span><span>Održavanje</span></a>' +
           '<a href="#admin" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">👥</span><span>Korisnici</span></a>' +
           '<a href="#postavke" class="mobile-menu-item" onclick="closeMobileMenu()"><span class="menu-icon">⚙️</span><span>Postavke</span></a>';
  }

  function getBottomNavContent() {
    // Za voditelj module - koristi tabove
    var voditeljTabs = document.querySelector('.voditelj-tabs');
    if (voditeljTabs) {
      return '<div class="mobile-nav-items">' +
             '<button class="mobile-nav-item active" data-tab="dashboard" onclick="if(window.switchTab)switchTab(\'dashboard\')">' +
             '<span class="nav-icon">📊</span><span>Dash</span></button>' +
             '<button class="mobile-nav-item" data-tab="prestelavanje" onclick="if(window.switchTab)switchTab(\'prestelavanje\')">' +
             '<span class="nav-icon">🔧</span><span>Prešt.</span></button>' +
             '<button class="mobile-nav-item" data-tab="artikl" onclick="if(window.switchTab)switchTab(\'artikl\')">' +
             '<span class="nav-icon">📦</span><span>Art.</span></button>' +
             '<button class="mobile-nav-item" data-tab="izvjestaj" onclick="if(window.switchTab)switchTab(\'izvjestaj\')">' +
             '<span class="nav-icon">📋</span><span>Izv.</span></button>' +
             '<button class="mobile-nav-item" onclick="toggleMobileMenu()">' +
             '<span class="nav-icon">☰</span><span>Više</span></button>' +
             '</div>';
    }

    // Default navigacija - koristi hash routing
    return '<div class="mobile-nav-items">' +
           '<a href="#dashboard" class="mobile-nav-item"><span class="nav-icon">📊</span><span>Dash</span></a>' +
           '<a href="#planiranje" class="mobile-nav-item"><span class="nav-icon">📋</span><span>Plan</span></a>' +
           '<a href="#skladiste" class="mobile-nav-item"><span class="nav-icon">🏭</span><span>Sklad.</span></a>' +
           '<a href="#artikli" class="mobile-nav-item"><span class="nav-icon">📦</span><span>Art.</span></a>' +
           '<button class="mobile-nav-item" onclick="toggleMobileMenu()"><span class="nav-icon">☰</span><span>Više</span></button>' +
           '</div>';
  }

  function toggleMobileMenu() {
    var overlay = document.getElementById('mobileMenuOverlay');
    var menu = document.getElementById('mobileSideMenu');
    if (!overlay || !menu) return;
    
    var isOpen = menu.classList.contains('active');
    if (isOpen) {
      closeMobileMenu();
    } else {
      overlay.classList.add('active');
      menu.classList.add('active');
      document.body.style.overflow = 'hidden';
    }
  }

  function closeMobileMenu() {
    var overlay = document.getElementById('mobileMenuOverlay');
    var menu = document.getElementById('mobileSideMenu');
    if (overlay) overlay.classList.remove('active');
    if (menu) menu.classList.remove('active');
    document.body.style.overflow = '';
  }

  // Globalne funkcije
  window.toggleMobileMode = toggleMobileMode;
  window.toggleMobileMenu = toggleMobileMenu;
  window.closeMobileMenu = closeMobileMenu;
  
  // Refresh mobile menu (poziva se nakon prijave)
  window.refreshMobileMenu = function() {
    var menu = document.getElementById('mobileSideMenu');
    if (menu) {
      menu.innerHTML = getMobileMenuContent();
    }
  };

  // Proširi switchTab ako postoji
  var originalSwitchTab = window.switchTab;
  window.switchTab = function(tabId) {
    if (originalSwitchTab) originalSwitchTab(tabId);
    
    // Ažuriraj mobile bottom nav
    document.querySelectorAll('.mobile-nav-item').forEach(function(item) {
      item.classList.remove('active');
      if (item.getAttribute('data-tab') === tabId) {
        item.classList.add('active');
      }
    });
    
    closeMobileMenu();
    window.scrollTo(0, 0);
  };

  // Ažuriraj aktivni item kad se promijeni hash
  window.addEventListener('hashchange', function() {
    var hash = window.location.hash.slice(1);
    document.querySelectorAll('.mobile-nav-item').forEach(function(item) {
      var href = item.getAttribute('href');
      if (href === '#' + hash) {
        item.classList.add('active');
      } else if (!item.getAttribute('data-tab')) {
        item.classList.remove('active');
      }
    });
  });

})();
