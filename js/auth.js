// ============================================
// CARTA ERP - Autentifikacija (PIN + Lozinka)
// ============================================

const Auth = {
  currentUser: null,
  rolesCache: null,

  // ============================================
  // LOGIN S PIN-om (za obične korisnike)
  // ============================================
  async loginWithPin(pin) {
    try {
      console.log('Auth.loginWithPin - attempting');
      
      var result = await initSupabase()
        .from('prod_users')
        .select('*')
        .eq('pin_code', pin)
        .eq('aktivan', true)
        .single();
      
      if (result.error || !result.data) {
        throw new Error('Neispravan PIN');
      }
      
      var user = result.data;
      
      // Admin/superadmin ne mogu koristiti PIN
      if (user.uloga === 'admin' || user.uloga === 'superadmin') {
        throw new Error('Admin korisnici moraju koristiti lozinku');
      }

      return this._completeLogin(user);
    } catch (error) {
      console.error('PIN login error:', error);
      throw error;
    }
  },

  // ============================================
  // LOGIN S LOZINKOM (za admin/superadmin)
  // ============================================
  async loginWithPassword(email, password) {
    try {
      console.log('Auth.loginWithPassword - attempting for:', email);
      
      var result = await initSupabase()
        .from('prod_users')
        .select('*')
        .eq('email', email)
        .eq('aktivan', true)
        .single();
      
      if (result.error || !result.data) {
        throw new Error('Korisnik nije pronađen');
      }
      
      var user = result.data;
      
      // Samo admin/superadmin mogu koristiti lozinku
      if (user.uloga !== 'admin' && user.uloga !== 'superadmin') {
        throw new Error('Samo admin korisnici mogu koristiti lozinku');
      }
      
      // Provjeri lozinku
      if (!user.password || user.password !== password) {
        throw new Error('Neispravna lozinka');
      }

      return this._completeLogin(user);
    } catch (error) {
      console.error('Password login error:', error);
      throw error;
    }
  },

  // ============================================
  // STARA LOGIN METODA (backward compatibility)
  // ============================================
  async login(pin) {
    return this.loginWithPin(pin);
  },

  // ============================================
  // ZAJEDNIČKA LOGIKA ZA ZAVRŠETAK PRIJAVE
  // ============================================
  async _completeLogin(user) {
    // Učitaj uloge ako nisu učitane
    if (!this.rolesCache) {
      await this.loadRoles();
    }

    // Spremi sesiju
    this.currentUser = {
      id: user.id,
      email: user.email,
      name: user.ime,
      role: user.uloga,
      loginTime: Date.now()
    };

    // Ažuriraj last_login
    initSupabase()
      .from('prod_users')
      .update({ last_login: new Date().toISOString() })
      .eq('id', user.id)
      .then(function() {});

    localStorage.setItem(CONFIG.SESSION_KEY, JSON.stringify(this.currentUser));
    console.log('Auth login success, user:', this.currentUser.name, 'role:', this.currentUser.role);
    return this.currentUser;
  },

  // ============================================
  // PROMJENA LOZINKE
  // ============================================
  async changePassword(currentPassword, newPassword) {
    var user = this.getUser();
    if (!user) throw new Error('Niste prijavljeni');
    
    // Dohvati korisnika i provjeri trenutnu lozinku
    var result = await initSupabase()
      .from('prod_users')
      .select('password')
      .eq('id', user.id)
      .single();
    
    if (result.error || !result.data) {
      throw new Error('Greška pri dohvatu korisnika');
    }
    
    if (result.data.password !== currentPassword) {
      throw new Error('Trenutna lozinka nije ispravna');
    }
    
    // Ažuriraj lozinku
    var updateResult = await initSupabase()
      .from('prod_users')
      .update({ password: newPassword })
      .eq('id', user.id);
    
    if (updateResult.error) {
      throw new Error('Greška pri spremanju nove lozinke');
    }
    
    return true;
  },

  // Učitaj uloge iz baze
  async loadRoles() {
    try {
      var result = await initSupabase()
        .from('prod_roles')
        .select('naziv, dozvole')
        .eq('aktivan', true);
      
      if (result.error) throw result.error;
      
      this.rolesCache = {};
      (result.data || []).forEach(function(role) {
        try {
          Auth.rolesCache[role.naziv] = JSON.parse(role.dozvole);
        } catch (e) {
          Auth.rolesCache[role.naziv] = role.dozvole || [];
        }
      });
      
      console.log('Roles loaded:', Object.keys(this.rolesCache));
    } catch (e) {
      console.error('Error loading roles:', e);
      this.rolesCache = CONFIG.DEFAULT_ROLES;
    }
  },

  // Logout
  logout() {
    this.currentUser = null;
    localStorage.removeItem(CONFIG.SESSION_KEY);
    Router.navigate('login');
  },

  // Provjeri sesiju
  checkSession() {
    var stored = localStorage.getItem(CONFIG.SESSION_KEY);
    if (!stored) return false;

    try {
      var session = JSON.parse(stored);
      var elapsed = Date.now() - session.loginTime;
      
      if (elapsed > CONFIG.SESSION_DURATION) {
        this.logout();
        return false;
      }

      this.currentUser = session;
      return true;
    } catch (e) {
      this.logout();
      return false;
    }
  },

  // Dohvati trenutnog korisnika
  getUser() {
    if (!this.currentUser) {
      this.checkSession();
    }
    return this.currentUser;
  },

  // Provjeri ima li pristup stranici
  canAccess(pageId) {
    var user = this.getUser();
    if (!user) return false;

    var roles = this.rolesCache || CONFIG.DEFAULT_ROLES;
    var permissions = roles[user.role];
    
    if (!permissions) return false;

    // Superadmin ima pristup svemu
    if (permissions.includes('*')) return true;

    return permissions.includes(pageId);
  },

  // Je li superadmin
  isSuperAdmin() {
    var user = this.getUser();
    return user && user.role === 'superadmin';
  },

  // Je li admin ili superadmin
  isAdmin() {
    var user = this.getUser();
    return user && (user.role === 'superadmin' || user.role === 'admin');
  },

  // Dohvati dozvoljene nav items
  getAllowedNavItems() {
    var user = this.getUser();
    if (!user) return [];

    var self = this;
    return CONFIG.NAV_ITEMS.filter(function(item) {
      if (item.superadminOnly && !self.isSuperAdmin()) {
        return false;
      }
      return self.canAccess(item.id);
    });
  }
};
