// ============================================
// CARTA ERP - Zamjene članova postave
// Uključi ovu datoteku u svaki proizvodni modul
// ============================================

var ZamjenePostave = {
  data: {
    postava_broj: null,
    clanovi: [],
    zamjene: [],
    sviDjelatnici: [],
    linija: null,
    stroj_tip: null,
    smjena: null
  },

  // Marker za odsutne (bolovanje bez zamjene)
  ODSUTAN_MARKER: '[ODSUTAN]',

  // Inicijalizacija za određeni modul
  // smjenaOverride - opcionalno, za module koji imaju drugačiji broj smjena
  async init(linija, strojTip, smjenaOverride) {
    this.data.linija = linija;
    this.data.stroj_tip = strojTip;
    this.data.clanovi = [];
    this.data.zamjene = [];
    
    var sad = new Date();
    var sat = sad.getHours();
    var smjenaBroj;
    
    if (smjenaOverride) {
      // Koristi proslijeđenu smjenu
      smjenaBroj = smjenaOverride;
    } else {
      // Standardna 3-smjenska logika
      smjenaBroj = sat >= 6 && sat < 14 ? 1 : (sat >= 14 && sat < 22 ? 2 : 3);
    }
    
    this.data.smjena = smjenaBroj;
    var today = sad.toISOString().split('T')[0];
    
    console.log('🔍 ZamjenePostave init:', linija, strojTip, 'smjena:', smjenaBroj);
    
    try {
      // 1. Dohvati postava_broj iz prod_schedules
      var schedResult = await initSupabase()
        .from('prod_schedules')
        .select('postava_broj')
        .eq('datum', today)
        .eq('smjena', smjenaBroj)
        .eq('linija', linija)
        .maybeSingle();
      
      if (!schedResult.data || !schedResult.data.postava_broj) {
        console.log('Nema rasporeda za', linija);
        return null;
      }
      
      this.data.postava_broj = schedResult.data.postava_broj;
      console.log('📅 Postava broj:', this.data.postava_broj);
      
      // 2. Dohvati članove tima - koristi djelatnik_ime i employee_id
      var teamResult = await initSupabase()
        .from('prod_schedule_teams')
        .select('id, naziv_tima, prod_schedule_members(id, employee_id, djelatnik_ime, aktivan)')
        .eq('postava_broj', this.data.postava_broj)
        .eq('stroj_tip', strojTip)
        .eq('status', 'Aktivan')
        .maybeSingle();
      
      if (teamResult.error) {
        console.error('Greška dohvata tima:', teamResult.error);
      }
      
      if (teamResult.data && teamResult.data.prod_schedule_members) {
        this.data.clanovi = teamResult.data.prod_schedule_members
          .filter(function(m) { return m.aktivan !== false && m.djelatnik_ime; })
          .map(function(m) {
            return {
              member_id: m.id,
              employee_id: m.employee_id,
              djelatnik_ime: m.djelatnik_ime,
              puno_ime: m.djelatnik_ime,
              zamijenjen: false,
              odsutan: false,  // NOVO: za bolovanje bez zamjene
              zamjena_employee_id: null,
              zamjena_ime: null
            };
          });
        console.log('👥 Članovi:', this.data.clanovi.length);
      }
      
      // 3. Dohvati zamjene za danas
      await this.loadZamjene(today, smjenaBroj);
      
      return this.data;
      
    } catch (e) {
      console.error('ZamjenePostave init error:', e);
      return null;
    }
  },

  async loadZamjene(datum, smjena) {
    try {
      var result = await initSupabase()
        .from('prod_shift_substitutions')
        .select('*')
        .eq('datum', datum)
        .eq('smjena', smjena)
        .eq('linija', this.data.linija)
        .eq('stroj_tip', this.data.stroj_tip);
      
      if (result.error) {
        console.log('Tablica zamjena ne postoji ili greška:', result.error.message);
        return;
      }
      
      if (result.data && result.data.length > 0) {
        var self = this;
        this.data.zamjene = result.data;
        
        result.data.forEach(function(z) {
          // Traži po employee_id ili original_ime
          var clan = self.data.clanovi.find(function(c) {
            return (z.original_employee_id && c.employee_id === z.original_employee_id) ||
                   (z.original_ime && c.puno_ime === z.original_ime);
          });
          if (clan) {
            // Provjeri je li odsutan (marker) ili ima zamjenu
            if (z.zamjena_ime === self.ODSUTAN_MARKER) {
              clan.odsutan = true;
              clan.zamijenjen = false;
            } else {
              clan.zamijenjen = true;
              clan.odsutan = false;
              clan.zamjena_employee_id = z.zamjena_employee_id;
              clan.zamjena_ime = z.zamjena_ime || 'Nepoznato';
            }
          }
        });
        console.log('🔄 Zamjene učitane:', result.data.length);
      }
    } catch (e) {
      console.log('loadZamjene error:', e.message);
    }
  },

  // Formatiraj ime (npr. "DRAGO POPOVIĆ" -> "D. Popović")
  formatIme: function(ime) {
    if (!ime) return '';
    var parts = ime.split(' ');
    if (parts.length >= 2) {
      return parts[0].charAt(0) + '. ' + parts.slice(1).map(function(p) { 
        return p.charAt(0) + p.slice(1).toLowerCase(); 
      }).join(' ');
    }
    return ime;
  },

  // Renderaj članove s zamjenama kao tekst
  renderClanoviText: function() {
    var self = this;
    if (!this.data.clanovi || this.data.clanovi.length === 0) {
      return 'Nema članova';
    }
    
    // Filtriraj samo aktivne članove (nisu odsutni)
    var aktivniClanovi = this.data.clanovi.filter(function(c) {
      return !c.odsutan;
    });
    
    if (aktivniClanovi.length === 0) {
      return '<span style="color:#d32f2f;">Svi članovi odsutni</span>';
    }
    
    return aktivniClanovi.map(function(c) {
      if (c.zamijenjen) {
        return '<s style="opacity:0.5;">' + self.formatIme(c.puno_ime).split('.')[0] + '.</s>→' + self.formatIme(c.zamjena_ime);
      }
      return self.formatIme(c.puno_ime);
    }).join(', ');
  },

  // Renderaj članove s punim statusom (za voditelja - prikazuje i odsutne)
  renderClanoviTextFull: function() {
    var self = this;
    if (!this.data.clanovi || this.data.clanovi.length === 0) {
      return 'Nema članova';
    }
    
    return this.data.clanovi.map(function(c) {
      if (c.odsutan) {
        return '<s style="opacity:0.4; color:#d32f2f;">' + self.formatIme(c.puno_ime) + '</s> <span style="color:#d32f2f; font-size:0.85em;">🏥</span>';
      }
      if (c.zamijenjen) {
        return '<s style="opacity:0.5;">' + self.formatIme(c.puno_ime).split('.')[0] + '.</s>→' + self.formatIme(c.zamjena_ime);
      }
      return self.formatIme(c.puno_ime);
    }).join(', ');
  },

  // Otvori modal za zamjene (read-only verzija za slagača)
  async otvoriModalReadOnly(modalId, tbodyId) {
    var tbody = document.getElementById(tbodyId);
    if (!tbody) {
      console.error('Tbody element not found:', tbodyId);
      return;
    }
    
    var html = '';
    var self = this;
    
    if (this.data.clanovi.length === 0) {
      html = '<tr><td colspan="2" style="padding:20px; text-align:center; color:#666;">Nema članova u postavi</td></tr>';
    } else {
      this.data.clanovi.forEach(function(clan) {
        html += '<tr>';
        html += '<td style="padding:10px; border-bottom:1px solid #eee;">';
        if (clan.odsutan) {
          html += '<s style="opacity:0.5;">' + clan.puno_ime + '</s>';
        } else {
          html += '<strong>' + clan.puno_ime + '</strong>';
        }
        html += '</td>';
        html += '<td style="padding:10px; border-bottom:1px solid #eee;">';
        if (clan.odsutan) {
          html += '<span style="background:#ffebee; color:#d32f2f; padding:3px 8px; border-radius:10px; font-size:0.75em; font-weight:600;">🏥 Odsutan</span>';
        } else if (clan.zamijenjen) {
          html += '<span style="background:#fff3e0; color:#e65100; padding:3px 8px; border-radius:10px; font-size:0.75em; font-weight:600;">→ ' + clan.zamjena_ime + '</span>';
        } else {
          html += '<span style="background:#e8f5e9; color:#2e7d32; padding:3px 8px; border-radius:10px; font-size:0.75em; font-weight:600;">✓ Aktivan</span>';
        }
        html += '</td>';
        html += '</tr>';
      });
    }
    
    tbody.innerHTML = html;
    
    if (typeof openModal === 'function') {
      openModal(modalId);
    } else {
      var modal = document.getElementById(modalId);
      if (modal) modal.classList.add('active');
    }
  },

  // Otvori modal za zamjene (edit verzija za voditelja)
  async otvoriModal(modalId, tbodyId) {
    var tbody = document.getElementById(tbodyId);
    if (!tbody) {
      console.error('Tbody element not found:', tbodyId);
      return;
    }
    
    var html = '';
    var self = this;
    
    if (this.data.clanovi.length === 0) {
      html = '<tr><td colspan="4" style="padding:20px; text-align:center; color:#666;">Nema članova u postavi</td></tr>';
    } else {
      this.data.clanovi.forEach(function(clan) {
        var zamjenaValue = clan.zamijenjen ? clan.zamjena_ime : '';
        var isOdsutan = clan.odsutan;
        
        html += '<tr data-member-row="' + clan.member_id + '">';
        html += '<td style="padding:10px; border-bottom:1px solid #eee;"><strong>' + clan.puno_ime + '</strong></td>';
        html += '<td style="padding:10px; border-bottom:1px solid #eee;">';
        html += '<input type="text" class="zamjena-input" ';
        html += 'data-employee-id="' + (clan.employee_id || '') + '" ';
        html += 'data-member-id="' + clan.member_id + '" ';
        html += 'data-original-ime="' + clan.puno_ime + '" ';
        html += 'value="' + zamjenaValue + '" ';
        html += 'placeholder="Upiši ime zamjene..." ';
        html += (isOdsutan ? 'disabled ' : '');
        html += 'style="padding:8px; width:100%; border:1px solid #ddd; border-radius:4px; font-size:14px;' + (isOdsutan ? ' background:#f5f5f5; opacity:0.5;' : '') + '">';
        html += '</td>';
        html += '<td style="padding:10px; border-bottom:1px solid #eee; text-align:center;">';
        html += '<label style="display:flex; align-items:center; gap:5px; cursor:pointer; font-size:0.85em;" title="Bolovanje bez zamjene">';
        html += '<input type="checkbox" class="odsutan-checkbox" ';
        html += 'data-member-id="' + clan.member_id + '" ';
        html += (isOdsutan ? 'checked ' : '');
        html += 'onchange="ZamjenePostave.toggleOdsutan(this)" ';
        html += 'style="width:18px; height:18px;">';
        html += ' 🏥';
        html += '</label>';
        html += '</td>';
        html += '<td style="padding:10px; border-bottom:1px solid #eee;">';
        if (isOdsutan) {
          html += '<span style="background:#ffebee; color:#d32f2f; padding:3px 8px; border-radius:10px; font-size:0.75em; font-weight:600;">Odsutan</span>';
        } else if (clan.zamijenjen) {
          html += '<span style="background:#fff3e0; color:#e65100; padding:3px 8px; border-radius:10px; font-size:0.75em; font-weight:600;">Zamijenjen</span>';
        } else {
          html += '<span style="background:#e8f5e9; color:#2e7d32; padding:3px 8px; border-radius:10px; font-size:0.75em; font-weight:600;">Aktivan</span>';
        }
        html += '</td>';
        html += '</tr>';
      });
    }
    
    tbody.innerHTML = html;
    
    if (typeof openModal === 'function') {
      openModal(modalId);
    } else {
      var modal = document.getElementById(modalId);
      if (modal) modal.classList.add('active');
    }
  },

  // Toggle odsutan checkbox - disable/enable zamjena input
  toggleOdsutan: function(checkbox) {
    var memberId = checkbox.dataset.memberId;
    var row = checkbox.closest('tr');
    var input = row.querySelector('.zamjena-input');
    var statusCell = row.querySelector('td:last-child');
    
    if (checkbox.checked) {
      // Odsutan - disable input, clear value
      input.disabled = true;
      input.value = '';
      input.style.background = '#f5f5f5';
      input.style.opacity = '0.5';
      statusCell.innerHTML = '<span style="background:#ffebee; color:#d32f2f; padding:3px 8px; border-radius:10px; font-size:0.75em; font-weight:600;">Odsutan</span>';
    } else {
      // Aktivan - enable input
      input.disabled = false;
      input.style.background = '';
      input.style.opacity = '';
      statusCell.innerHTML = '<span style="background:#e8f5e9; color:#2e7d32; padding:3px 8px; border-radius:10px; font-size:0.75em; font-weight:600;">Aktivan</span>';
    }
  },

  // Spremi zamjene
  async spremiZamjene(callback) {
    var inputs = document.querySelectorAll('.zamjena-input');
    var checkboxes = document.querySelectorAll('.odsutan-checkbox');
    var today = new Date().toISOString().split('T')[0];
    var self = this;
    
    if (typeof showLoading === 'function') showLoading('Spremanje zamjena...');
    
    try {
      for (var i = 0; i < inputs.length; i++) {
        var input = inputs[i];
        var originalId = input.dataset.employeeId;
        var memberId = input.dataset.memberId;
        var zamjenaIme = input.value.trim();
        var originalIme = input.dataset.originalIme;
        
        // Pronađi checkbox za ovaj član
        var checkbox = document.querySelector('.odsutan-checkbox[data-member-id="' + memberId + '"]');
        var isOdsutan = checkbox && checkbox.checked;
        
        // Pronađi člana
        var clan = this.data.clanovi.find(function(c) { 
          return c.employee_id === originalId || c.member_id == memberId; 
        });
        
        if (!clan) continue;
        
        // Provjeri postojeću zamjenu za ovog člana
        var postojecaZamjena = this.data.zamjene.find(function(z) {
          return z.original_employee_id === originalId || z.original_ime === originalIme;
        });
        
        // Određi što treba spremiti
        var finalZamjenaIme = null;
        if (isOdsutan) {
          finalZamjenaIme = this.ODSUTAN_MARKER;
        } else if (zamjenaIme) {
          finalZamjenaIme = zamjenaIme;
        }
        
        if (finalZamjenaIme && !postojecaZamjena) {
          // Nova zamjena ili odsutan
          await initSupabase().from('prod_shift_substitutions').insert({
            datum: today,
            smjena: this.data.smjena,
            linija: this.data.linija,
            stroj_tip: this.data.stroj_tip,
            postava_broj: this.data.postava_broj,
            original_employee_id: originalId || null,
            original_ime: originalIme,
            zamjena_ime: finalZamjenaIme
          });
        } else if (finalZamjenaIme && postojecaZamjena) {
          // Update zamjene
          await initSupabase().from('prod_shift_substitutions')
            .update({ zamjena_ime: finalZamjenaIme })
            .eq('id', postojecaZamjena.id);
        } else if (!finalZamjenaIme && postojecaZamjena) {
          // Ukloni zamjenu
          await initSupabase().from('prod_shift_substitutions').delete()
            .eq('id', postojecaZamjena.id);
        }
      }
      
      // Reset i reload
      this.data.clanovi.forEach(function(c) {
        c.zamijenjen = false;
        c.odsutan = false;
        c.zamjena_employee_id = null;
        c.zamjena_ime = null;
      });
      this.data.zamjene = [];
      
      await this.loadZamjene(today, this.data.smjena);
      
      if (typeof showMessage === 'function') showMessage('✅ Zamjene spremljene!', 'success');
      
      if (callback) callback();
      
    } catch (e) {
      console.error('spremiZamjene error:', e);
      if (typeof showMessage === 'function') showMessage('❌ Greška: ' + e.message, 'error');
    } finally {
      if (typeof hideLoading === 'function') hideLoading();
    }
  },

  // Dohvati aktivne članove (uključuje zamjene, isključuje odsutne)
  getAktivniClanovi: function() {
    return this.data.clanovi
      .filter(function(clan) {
        // Filtriraj odsutne
        return !clan.odsutan;
      })
      .map(function(clan) {
        if (clan.zamijenjen) {
          return {
            employee_id: clan.zamjena_employee_id,
            ime: clan.zamjena_ime,
            original_id: clan.employee_id,
            original_ime: clan.puno_ime
          };
        }
        return {
          employee_id: clan.employee_id,
          ime: clan.puno_ime,
          original_id: null,
          original_ime: null
        };
      });
  },

  // Dohvati broj odsutnih članova
  getBrojOdsutnih: function() {
    return this.data.clanovi.filter(function(c) { return c.odsutan; }).length;
  }
};

// Globalna dostupnost
window.ZamjenePostave = ZamjenePostave;
