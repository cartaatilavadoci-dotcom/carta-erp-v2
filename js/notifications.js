// ============================================
// CARTA ERP - Notifikacijski sustav
// ============================================
// Prikazuje prod_notifications za target_roles trenutnog korisnika.
// Bell icon u sidebaru → klik → dropdown lista.
// Polling svakih 60s (može se nadograditi u realtime subscribe).
//
// Schema napomena: is_read je GLOBAL (per-notifikacija), ne per-user.
// Prvi korisnik koji otvori notifikaciju označava je read za sve u
// target_roles. To je po postojećem DB dizajnu.
// ============================================

const Notifications = {
  _all: [],
  _pollTimer: null,
  _realtimeChannel: null,

  async init() {
    await this.load();
    this.subscribeRealtime();
    this.startPolling();  // fallback ako realtime padne
  },

  // Realtime subscription na prod_notifications
  subscribeRealtime() {
    if (this._realtimeChannel) return;
    try {
      var sb = initSupabase();
      if (!sb.channel) return;  // stari Supabase klijent bez realtime

      this._realtimeChannel = sb.channel('notifications-channel')
        .on('postgres_changes',
            { event: '*', schema: 'public', table: 'prod_notifications' },
            function(payload) {
              console.log('🔔 Realtime notif event:', payload.eventType);
              // Bilo koji INSERT/UPDATE/DELETE — refresh liste
              Notifications.load();
            })
        .subscribe(function(statusName) {
          if (statusName === 'SUBSCRIBED') {
            console.log('🔔 Notifications realtime: povezano');
          } else if (statusName === 'CLOSED' || statusName === 'CHANNEL_ERROR') {
            console.warn('🔔 Notifications realtime:', statusName, '- polling ostaje aktivan');
          }
        });
    } catch (e) {
      console.warn('Realtime subscribe failed (polling fallback radi):', e);
    }
  },

  async load() {
    var user = (typeof Auth !== 'undefined') ? Auth.getUser() : null;
    if (!user || !user.role) return;

    try {
      // Neoznačene notifikacije za moju ulogu
      // (superadmin vidi sve)
      var query = initSupabase()
        .from('prod_notifications')
        .select('*')
        .eq('is_read', false)
        .order('created_at', { ascending: false })
        .limit(50);

      if (user.role !== 'superadmin') {
        query = query.overlaps('target_roles', [user.role]);
      }

      var result = await query;
      if (result.error) {
        console.warn('Notifications load error:', result.error.message);
        return;
      }

      this._all = result.data || [];
      this.render();
    } catch (e) {
      console.warn('Notifications load exception:', e);
    }
  },

  render() {
    var badge = document.getElementById('notifBadge');
    var list = document.getElementById('notifList');
    if (!badge || !list) return;

    var count = this._all.length;
    if (count > 0) {
      badge.textContent = count > 99 ? '99+' : count;
      badge.style.display = 'inline-flex';
    } else {
      badge.style.display = 'none';
    }

    if (count === 0) {
      list.innerHTML = '<div style="padding: 20px; text-align: center; color: #999;">Nema novih obavijesti</div>';
      return;
    }

    var html = this._all.map(function(n) {
      var icon = Notifications._iconForType(n.notification_type);
      var vrijeme = Notifications._formatTime(n.created_at);
      return '<div class="notif-item" data-id="' + n.id + '" ' +
             'data-related-type="' + (n.related_type || '') + '" ' +
             'data-related-id="' + (n.related_id || '') + '">' +
             '<div class="notif-icon">' + icon + '</div>' +
             '<div class="notif-body">' +
             '<div class="notif-title">' + Notifications._esc(n.title) + '</div>' +
             '<div class="notif-message">' + Notifications._esc(n.message || '') + '</div>' +
             '<div class="notif-meta">' + Notifications._esc(n.created_by || '-') + ' · ' + vrijeme + '</div>' +
             '</div></div>';
    }).join('');

    list.innerHTML = html;

    // Bind click handlers
    list.querySelectorAll('.notif-item').forEach(function(el) {
      el.addEventListener('click', function() {
        Notifications.handleClick(
          el.dataset.id,
          el.dataset.relatedType,
          el.dataset.relatedId
        );
      });
    });
  },

  async handleClick(id, relatedType, relatedId) {
    await this.markRead(id);

    // Navigate based on related_type
    var routeMap = {
      'dispatch': 'otpreme',
      'work_order': 'planiranje',
      'maintenance': 'maintenance',
      'roll': 'skladiste'
    };
    var route = routeMap[relatedType];
    if (route) {
      this.toggle(false);
      if (typeof Router !== 'undefined') Router.navigate(route);
    }
  },

  async markRead(id) {
    var user = Auth.getUser();
    try {
      var res = await initSupabase()
        .from('prod_notifications')
        .update({
          is_read: true,
          read_by: user ? user.name : null,
          read_at: new Date().toISOString()
        })
        .eq('id', id);

      if (res.error) {
        console.warn('markRead error:', res.error.message);
        return;
      }

      this._all = this._all.filter(function(n) { return n.id !== id; });
      this.render();
    } catch (e) {
      console.warn('markRead exception:', e);
    }
  },

  async markAllRead() {
    if (this._all.length === 0) return;
    var user = Auth.getUser();
    var ids = this._all.map(function(n) { return n.id; });

    try {
      await initSupabase()
        .from('prod_notifications')
        .update({
          is_read: true,
          read_by: user ? user.name : null,
          read_at: new Date().toISOString()
        })
        .in('id', ids);

      this._all = [];
      this.render();
    } catch (e) {
      console.warn('markAllRead exception:', e);
    }
  },

  toggle(forceOpen) {
    var panel = document.getElementById('notifPanel');
    if (!panel) return;
    var isOpen = panel.style.display === 'block';
    var shouldOpen = typeof forceOpen === 'boolean' ? forceOpen : !isOpen;
    panel.style.display = shouldOpen ? 'block' : 'none';
    if (shouldOpen) this.load();  // refresh na otvaranju
  },

  startPolling() {
    // Polling kao fallback ako realtime padne - rjeđe (2 min) jer je realtime primarni
    if (this._pollTimer) clearInterval(this._pollTimer);
    this._pollTimer = setInterval(function() { Notifications.load(); }, 120000);
  },

  // ----- helpers -----
  _iconForType(type) {
    var map = {
      'dispatch_ready': '🚛',
      'dispatch_sent': '✅',
      'work_order_approved': '✔️',
      'work_order_rejected': '❌',
      'maintenance_alert': '🔧',
      'stock_low': '📦',
      'quality_alert': '⚠️'
    };
    return map[type] || '📌';
  },

  _formatTime(iso) {
    if (!iso) return '-';
    var d = new Date(iso);
    var now = new Date();
    var diffMs = now - d;
    var diffMin = Math.floor(diffMs / 60000);
    if (diffMin < 1) return 'sada';
    if (diffMin < 60) return diffMin + ' min';
    var diffH = Math.floor(diffMin / 60);
    if (diffH < 24) return diffH + 'h';
    var diffD = Math.floor(diffH / 24);
    if (diffD < 7) return diffD + 'd';
    return d.toLocaleDateString('hr-HR');
  },

  _esc(s) {
    if (s == null) return '';
    return String(s)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }
};

window.Notifications = Notifications;
