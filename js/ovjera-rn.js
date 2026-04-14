(function() {
  'use strict';

  // ============================================
  // STANJE
  // ============================================
  var ovjeraState = {
    nalozi: [],
    filtrirani: [],
    aktivniFilter: 'ceka',
    odabraniRN: null,
    odabraniArtikl: null
  };

  // ============================================
  // INICIJALIZACIJA
  // ============================================
  window.ovjeraInit = function() {
    // Provjera dozvola
    var user = Auth.getUser();
    if (!user || !Auth.isAdmin()) {
      if (typeof showMessage === 'function') {
        showMessage('Nemate dozvolu za pristup ovoj stranici.', 'error');
      }
      return;
    }
    ovjeraUcitaj();
  };

  // Auto-init
  if (typeof Auth !== 'undefined' && Auth.getUser()) {
    ovjeraInit();
  }

  // ============================================
  // U\u010CITAVANJE PODATAKA
  // ============================================
  window.ovjeraUcitaj = async function() {
    try {
      var result = await initSupabase()
        .from('prod_work_orders')
        .select('id, wo_number, wo_type, order_number, customer_name, article_name, article_id, article_code, quantity, status, production_line, created_at, planned_start_date, notes, created_by, created_by_user_id, created_by_name, approval_status, approved_by_user_id, approved_by_name, approved_at, rejection_reason')
        .order('created_at', { ascending: false })
        .limit(10000);

      if (result.error) throw result.error;

      ovjeraState.nalozi = result.data || [];
      ovjeraAzurirajBrojeve();
      ovjeraFiltriraj();

    } catch (e) {
      console.error('Gre\u0161ka u\u010Ditavanja naloga:', e);
      if (typeof showMessage === 'function') {
        showMessage('Gre\u0161ka pri u\u010Ditavanju naloga: ' + e.message, 'error');
      }
    }
  };

  // ============================================
  // FILTRIRANJE
  // ============================================
  window.ovjeraFilter = function(btn) {
    document.querySelectorAll('.ovjera-filter-btn').forEach(function(b) {
      b.classList.remove('active');
    });
    btn.classList.add('active');
    ovjeraState.aktivniFilter = btn.getAttribute('data-filter');
    ovjeraFiltriraj();
  };

  // Mapiranje ASCII filtera na DB vrijednosti
  var FILTER_MAP = {
    'ceka': '\u010Ceka ovjeru',
    'odobreno': 'Odobreno',
    'odbijeno': 'Odbijeno'
  };

  function ovjeraFiltriraj() {
    var filter = ovjeraState.aktivniFilter;
    if (filter === 'sve') {
      ovjeraState.filtrirani = ovjeraState.nalozi.slice();
    } else {
      var dbValue = FILTER_MAP[filter] || filter;
      ovjeraState.filtrirani = ovjeraState.nalozi.filter(function(n) {
        return n.approval_status === dbValue;
      });
    }
    ovjeraRenderLista();
  }

  function ovjeraAzurirajBrojeve() {
    var ceka = 0, odobreno = 0, odbijeno = 0;
    ovjeraState.nalozi.forEach(function(n) {
      if (n.approval_status === FILTER_MAP['ceka']) ceka++;
      else if (n.approval_status === 'Odobreno') odobreno++;
      else if (n.approval_status === 'Odbijeno') odbijeno++;
    });

    var el;
    el = document.getElementById('countCeka'); if (el) el.textContent = ceka;
    el = document.getElementById('countOdobreno'); if (el) el.textContent = odobreno;
    el = document.getElementById('countOdbijeno'); if (el) el.textContent = odbijeno;
    el = document.getElementById('countSve'); if (el) el.textContent = ovjeraState.nalozi.length;
    el = document.getElementById('footerCeka'); if (el) el.textContent = ceka;
    el = document.getElementById('footerOdobreno'); if (el) el.textContent = odobreno;
    el = document.getElementById('footerOdbijeno'); if (el) el.textContent = odbijeno;
  }

  // ============================================
  // RENDERANJE LISTE
  // ============================================
  function ovjeraRenderLista() {
    var container = document.getElementById('ovjeraLista');
    if (!container) return;

    if (ovjeraState.filtrirani.length === 0) {
      container.innerHTML = '<div class="ovjera-lista-empty">Nema naloga za prikaz</div>';
      return;
    }

    var html = '';
    ovjeraState.filtrirani.forEach(function(rn) {
      var selected = ovjeraState.odabraniRN && ovjeraState.odabraniRN.id === rn.id ? ' selected' : '';
      var badgeHtml = ovjeraGetBadge(rn.approval_status);
      var linijaClass = (rn.production_line || '').toLowerCase() === 'wh' ? 'wh' : 'nli';
      var datum = '';
      if (rn.created_at) {
        var d = new Date(rn.created_at);
        datum = String(d.getDate()).padStart(2, '0') + '.' + String(d.getMonth() + 1).padStart(2, '0') + '.' + d.getFullYear();
      }
      var kreirao = rn.created_by_name || rn.created_by || '\u2014';

      html += '<div class="ovjera-rn-card' + selected + '" onclick="ovjeraOdaberi(\'' + rn.id + '\')">';
      html += '<div class="ovjera-rn-card-header">';
      html += '<span class="ovjera-rn-number">' + escapeHtml(rn.wo_number || '') + '</span>';
      html += badgeHtml;
      html += '</div>';
      html += '<div class="ovjera-rn-card-body">';
      html += '<div class="rn-artikl">' + escapeHtml(rn.article_name || '') + '</div>';
      html += '<div>' + escapeHtml(rn.customer_name || '') + ' &middot; ' + Number(rn.quantity || 0).toLocaleString('hr-HR') + ' kom</div>';
      html += '</div>';
      html += '<div class="ovjera-rn-card-footer">';
      html += '<span class="ovjera-rn-linija ' + linijaClass + '">' + escapeHtml(rn.production_line || '') + '</span>';
      html += '<span>' + datum + '</span>';
      html += '<span>Kreirao: ' + escapeHtml(kreirao) + '</span>';
      html += '</div>';
      html += '</div>';
    });

    container.innerHTML = html;
  }

  function ovjeraGetBadge(status) {
    if (status === '\u010Ceka ovjeru') return '<span class="badge-ceka">\u010Ceka ovjeru</span>';
    if (status === 'Odobreno') return '<span class="badge-odobreno">Odobreno</span>';
    if (status === 'Odbijeno') return '<span class="badge-odbijeno">Odbijeno</span>';
    return '';
  }

  // ============================================
  // ODABIR RN-a I PRIKAZ DETALJA
  // ============================================
  window.ovjeraOdaberi = async function(rnId) {
    var rn = ovjeraState.nalozi.find(function(n) { return n.id === rnId; });
    if (!rn) return;

    ovjeraState.odabraniRN = rn;
    ovjeraRenderLista(); // Update selected state

    if (typeof showLoading === 'function') showLoading('U\u010Ditavanje detalja...');

    try {
      // Dohvati artikl
      var artiklResult = await initSupabase()
        .from('prod_articles')
        .select('*')
        .eq('id', rn.article_id)
        .maybeSingle();

      ovjeraState.odabraniArtikl = (artiklResult && artiklResult.data) ? artiklResult.data : null;
      ovjeraRenderDetalji();

    } catch (e) {
      console.error('Gre\u0161ka dohvata artikla:', e);
      ovjeraState.odabraniArtikl = null;
      ovjeraRenderDetalji();
    } finally {
      if (typeof hideLoading === 'function') hideLoading();
    }
  };

  // ============================================
  // RENDERANJE DETALJA
  // ============================================
  function ovjeraRenderDetalji() {
    var container = document.getElementById('ovjeraDetalji');
    if (!container) return;

    var rn = ovjeraState.odabraniRN;
    var art = ovjeraState.odabraniArtikl;
    if (!rn) {
      container.innerHTML = '<div class="ovjera-detalji-placeholder">Odaberite radni nalog za pregled</div>';
      return;
    }

    var html = '';

    // 1. INFO O NALOGU
    html += ovjeraRenderInfo(rn);

    // 2. SPECIFIKACIJA ARTIKLA
    html += ovjeraRenderSpec(rn, art);

    // 3. PDF GRAFI\u010CKA PRIPREMA
    html += ovjeraRenderPdf(art);

    // 4. OVJERA SEKCIJA
    html += ovjeraRenderApproval(rn);

    // 5. POVIJEST
    html += ovjeraRenderHistory(rn);

    container.innerHTML = html;
  }

  // ---------- 1. INFO ----------
  function ovjeraRenderInfo(rn) {
    var datum = rn.created_at ? formatDatumVrijeme(rn.created_at) : '\u2014';
    var planDatum = rn.planned_start_date ? formatDatum(rn.planned_start_date) : '\u2014';
    var kreirao = rn.created_by_name || rn.created_by || '\u2014';

    var h = '<div class="ovjera-card">';
    h += '<div class="ovjera-card-title info">Informacije o nalogu</div>';
    h += '<div class="ovjera-card-body">';
    h += '<div class="ovjera-info-grid">';
    h += infoItem('Broj RN', rn.wo_number || '\u2014');
    h += infoItem('Narud\u017Eba', rn.order_number || '\u2014');
    h += infoItem('Kupac', rn.customer_name || '\u2014');
    h += infoItem('Artikl', rn.article_name || '\u2014');
    h += infoItem('\u0160ifra', rn.article_code || '\u2014');
    h += infoItem('Koli\u010Dina', Number(rn.quantity || 0).toLocaleString('hr-HR') + ' kom');
    h += infoItem('Linija', rn.production_line || '\u2014');
    h += infoItem('Status', rn.status || '\u2014');
    h += infoItem('Planirani po\u010Detak', planDatum);
    h += infoItem('Kreirao', kreirao);
    h += infoItem('Datum kreiranja', datum);
    if (rn.notes) {
      h += infoItem('Napomena', rn.notes, true);
    }
    h += '</div></div></div>';
    return h;
  }

  function infoItem(label, value, fullWidth) {
    return '<div class="ovjera-info-item' + (fullWidth ? ' full-width' : '') + '">' +
      '<span class="ovjera-info-label">' + escapeHtml(label) + '</span>' +
      '<span class="ovjera-info-value">' + escapeHtml(value) + '</span>' +
      '</div>';
  }

  // ---------- 2. SPECIFIKACIJA ----------
  function ovjeraRenderSpec(rn, art) {
    var h = '<div class="ovjera-card">';
    h += '<div class="ovjera-card-title spec">Specifikacija artikla</div>';
    h += '<div class="ovjera-card-body">';

    if (!art) {
      h += '<div style="padding:20px;text-align:center;color:#999;">Artikl nije prona\u0111en u bazi</div>';
      h += '</div></div>';
      return h;
    }

    h += '<div class="ovjera-spec-layout">';

    // SVG vizualizacija
    h += '<div class="ovjera-spec-svg">';
    h += ovjeraRenderSvg(art);
    h += '</div>';

    // Detalji
    h += '<div class="ovjera-spec-details">';

    // Dimenzije
    h += '<div class="ovjera-spec-section">';
    h += '<div class="ovjera-spec-section-title">Dimenzije</div>';
    h += specRow('\u0160irina', fmtNum(art.bag_width) + ' cm');
    h += specRow('Visina', fmtNum(art.bag_length) + ' cm');
    h += specRow('Dno', fmtNum(art.bag_bottom) + ' cm');
    h += specRow('Ventil', fmtNum(art.bag_valve) + ' cm');
    h += specRow('Tip ventila', art.valve_type || '\u2014');
    h += specRow('Pozicija ventila', art.valve_position || '\u2014');

    // REZ - Izračun ovisno o vrsti ventila
    var bagLength = parseFloat(art.bag_length) || 0;
    var bagBottom = parseFloat(art.bag_bottom) || 0;
    var valveTypeStr = art.valve_type || '';
    var rezValue = 0;
    var rezFormula = '';
    if (valveTypeStr === 'OL') {
      rezValue = bagLength + (bagBottom / 2) + 2;
      rezFormula = bagLength + ' + ' + bagBottom + '/2 + 2';
    } else {
      rezValue = bagLength + bagBottom + 4;
      rezFormula = bagLength + ' + ' + bagBottom + ' + 4';
    }
    if (bagLength > 0) {
      h += specRowHtml('Rez - Izra\u010Dun', '<strong>' + rezValue + '</strong> <span style="font-size:0.85em;color:#666;">(' + rezFormula + ')</span>');
    }

    h += specRow('Duljina tuljka', fmtNum(art.tube_length) + ' cm');
    h += specRow('Tip reza', art.cut_type || '\u2014');
    h += specRow('Finger hole', art.finger_hole || '\u2014');
    h += specRow('Boja vre\u0107e', art.bag_color || '\u2014');
    h += specRow('Folija', art.has_foil || '\u2014');
    h += '</div>';

    // Slojevi papira
    h += '<div class="ovjera-spec-section">';
    h += '<div class="ovjera-spec-section-title">Slojevi papira</div>';
    h += '<table class="ovjera-layers-table">';
    h += '<tr><th>Sloj</th><th>\u0160ifra</th><th>\u0160irina</th><th>Gramatura</th></tr>';
    for (var s = 1; s <= 4; s++) {
      var code = art['paper_s' + s + '_code'];
      if (code) {
        h += '<tr>';
        h += '<td>S' + s + '</td>';
        h += '<td>' + escapeHtml(code) + '</td>';
        h += '<td>' + fmtNum(art['paper_s' + s + '_width']) + ' cm</td>';
        h += '<td>' + fmtNum(art['paper_s' + s + '_grammage']) + ' g/m\u00B2</td>';
        h += '</tr>';
      }
    }
    h += '</table>';
    h += '</div>';

    // Ventil materijal
    if (art.valve_s1_paper_code) {
      h += '<div class="ovjera-spec-section">';
      h += '<div class="ovjera-spec-section-title">Ventil materijal</div>';
      h += specRow('Perforacija ventila', art.perforation_valve || '\u2014');
      h += '<table class="ovjera-layers-table">';
      h += '<tr><th>Sloj</th><th>\u0160ifra</th><th>Boja</th><th>\u0160irina</th><th>Gram.</th><th>Duljina</th><th>Preklop</th><th>Ukupno</th></tr>';
      for (var v = 1; v <= 2; v++) {
        var vc = art['valve_s' + v + '_paper_code'];
        if (vc) {
          var vLen = parseFloat(art['valve_s' + v + '_length']) || 0;
          var vOvr = parseFloat(art['valve_s' + v + '_overlap']) || 0;
          var vTotal = vLen + vOvr;
          h += '<tr>';
          h += '<td>V' + v + '</td>';
          h += '<td>' + escapeHtml(vc) + '</td>';
          h += '<td>' + escapeHtml(art['valve_s' + v + '_paper_color'] || '\u2014') + '</td>';
          h += '<td>' + fmtNum(art['valve_s' + v + '_width']) + '</td>';
          h += '<td>' + fmtNum(art['valve_s' + v + '_grammage']) + '</td>';
          h += '<td>' + fmtNum(vLen) + '</td>';
          h += '<td>' + fmtNum(vOvr) + '</td>';
          h += '<td><strong>' + fmtNum(vTotal) + '</strong></td>';
          h += '</tr>';
        }
      }
      h += '</table>';
      if (art.perforation_valve_type) {
        h += specRow('Vrsta perforacije ventila', art.perforation_valve_type);
      }
      h += '</div>';
    }

    // Gornje dno
    if (art.top_paper_code) {
      h += '<div class="ovjera-spec-section">';
      h += '<div class="ovjera-spec-section-title">Gornje dno</div>';
      h += specRow('Dvojni preklop', art.top_double_overlap || '\u2014');
      h += specRow('\u0160ifra papira', art.top_paper_code);
      h += specRow('\u0160irina', fmtNum(art.top_width) + ' cm');
      var topLen = parseFloat(art.top_length) || 0;
      var topOvr = parseFloat(art.top_overlap) || 0;
      h += specRow('Duljina', fmtNum(topLen) + ' cm');
      h += specRow('Popre\u010Dni preklop', fmtNum(topOvr) + ' cm');
      if (topLen > 0) {
        h += specRowHtml('Ukupna duljina', '<strong>' + fmtNum(topLen + topOvr) + ' cm</strong>');
      }
      h += specRow('Gramatura', fmtNum(art.top_grammage) + ' g/m\u00B2');
      if (art.top_color_1) h += specRow('Boja 1', art.top_color_1);
      if (art.top_color_2) h += specRow('Boja 2', art.top_color_2);
      h += '</div>';
    }

    // Donje dno
    if (art.bottom_paper_code) {
      h += '<div class="ovjera-spec-section">';
      h += '<div class="ovjera-spec-section-title">Donje dno</div>';
      h += specRow('Dvojni preklop', art.bottom_double_overlap || '\u2014');
      h += specRow('\u0160ifra papira', art.bottom_paper_code);
      h += specRow('\u0160irina', fmtNum(art.bottom_width) + ' cm');
      var btmLen = parseFloat(art.bottom_length) || 0;
      var btmOvr = parseFloat(art.bottom_overlap) || 0;
      h += specRow('Duljina', fmtNum(btmLen) + ' cm');
      h += specRow('Popre\u010Dni preklop', fmtNum(btmOvr) + ' cm');
      if (btmLen > 0) {
        h += specRowHtml('Ukupna duljina', '<strong>' + fmtNum(btmLen + btmOvr) + ' cm</strong>');
      }
      h += specRow('Gramatura', fmtNum(art.bottom_grammage) + ' g/m\u00B2');
      if (art.bottom_color_1) h += specRow('Boja 1', art.bottom_color_1);
      if (art.bottom_color_2) h += specRow('Boja 2', art.bottom_color_2);
      h += '</div>';
    }

    // Folija
    if (art.foil_code || art.foil_type) {
      h += '<div class="ovjera-spec-section">';
      h += '<div class="ovjera-spec-section-title">Folija</div>';
      h += specRow('\u0160ifra', art.foil_code || '\u2014');
      h += specRow('Tip', art.foil_type || '\u2014');
      h += specRow('\u0160irina', fmtNum(art.foil_width) + ' cm');
      h += specRow('Mikroni', fmtNum(art.foil_microns));
      h += '</div>';
    }

    // Tisak
    h += '<div class="ovjera-spec-section">';
    h += '<div class="ovjera-spec-section-title">Tisak</div>';
    h += specRow('Broj boja (tuber)', art.colors_count || '\u2014');
    h += specRow('Broj boja (tisak)', fmtNum(art.print_colors_count));
    h += specRow('Debljina kli\u0161ea', fmtNum(art.cliche_thickness) + ' mm');
    h += specRow('Duplofan', fmtNum(art.duplofan_thickness) + ' mm');

    // Tuber boje
    var tuberBoje = [art.tuber_color_1, art.tuber_color_2, art.tuber_color_3, art.tuber_color_4].filter(Boolean);
    if (tuberBoje.length > 0) {
      h += '<div style="margin-top:6px;">';
      h += '<span class="label" style="color:#777;font-size:12px;">Tuber boje: </span>';
      h += '<div class="ovjera-color-chips">';
      tuberBoje.forEach(function(boja) {
        h += '<span class="ovjera-color-chip" style="background:#e8f5e9;border-color:#4caf50;">' + escapeHtml(boja) + '</span>';
      });
      h += '</div></div>';
    }

    // Tisak boje chipsevi
    var boje = [];
    for (var b = 1; b <= 6; b++) {
      var boja = art['print_color_' + b];
      if (boja) boje.push(boja);
    }
    if (boje.length > 0) {
      h += '<div style="margin-top:6px;">';
      h += '<span class="label" style="color:#777;font-size:12px;">Tisak boje: </span>';
      h += '<div class="ovjera-color-chips">';
      boje.forEach(function(boja) {
        h += '<span class="ovjera-color-chip">' + escapeHtml(boja) + '</span>';
      });
      h += '</div></div>';
    }

    // Anilox
    var aniloxArr = [];
    for (var a = 1; a <= 6; a++) {
      var an = art['anilox_' + a];
      if (an) aniloxArr.push(an);
    }
    if (aniloxArr.length > 0) {
      h += specRow('Anilox', aniloxArr.join(', '));
    }
    h += '</div>';

    // Perforacije
    var hasPerf = art.perforation_s1 || art.perforation_s2 || art.perforation_s3 || art.perforation_s4;
    if (hasPerf) {
      h += '<div class="ovjera-spec-section">';
      h += '<div class="ovjera-spec-section-title">Perforacije</div>';
      for (var p = 1; p <= 4; p++) {
        var perf = art['perforation_s' + p];
        if (perf) h += specRow('S' + p, perf);
      }
      h += '</div>';
    }

    // Pakiranje
    h += '<div class="ovjera-spec-section">';
    h += '<div class="ovjera-spec-section-title">Pakiranje</div>';
    h += specRow('Bottomer tip', art.bottomer_type || '\u2014');
    h += specRow('Kom/paket', fmtNum(art.pcs_per_package));
    h += specRow('Kom/paleta', art.pallet_quantity || art.pcs_per_pallet || '\u2014');
    h += specRow('Tip palete', art.pallet_type || '\u2014');
    h += specRow('Pakiranje', art.packaging_type || '\u2014');
    h += '</div>';

    // Napomena
    if (art.notes) {
      h += '<div class="ovjera-spec-section">';
      h += '<div class="ovjera-spec-section-title">Napomena</div>';
      h += '<div style="padding:8px 12px;background:#fff8e1;border-radius:6px;border-left:3px solid #ffa000;font-size:13px;line-height:1.5;">';
      h += escapeHtml(art.notes);
      h += '</div>';
      h += '</div>';
    }

    h += '</div>'; // spec-details
    h += '</div>'; // spec-layout
    h += '</div></div>';
    return h;
  }

  function specRow(label, value) {
    return '<div class="ovjera-spec-row">' +
      '<span class="label">' + escapeHtml(label) + '</span>' +
      '<span class="value">' + escapeHtml(String(value || '\u2014')) + '</span>' +
      '</div>';
  }

  function specRowHtml(label, htmlValue) {
    return '<div class="ovjera-spec-row">' +
      '<span class="label">' + escapeHtml(label) + '</span>' +
      '<span class="value">' + (htmlValue || '\u2014') + '</span>' +
      '</div>';
  }

  function fmtNum(val) {
    if (val === null || val === undefined || val === '') return '\u2014';
    var num = Number(val);
    if (isNaN(num)) return String(val);
    return num % 1 === 0 ? String(num) : num.toFixed(2);
  }

  // ---------- SVG VIZUALIZACIJA ----------
  function ovjeraRenderSvg(art) {
    var w = Number(art.bag_width) || 40;
    var l = Number(art.bag_length) || 60;
    var bottom = Number(art.bag_bottom) || 10;
    var valve = Number(art.bag_valve) || 0;
    var vType = art.valve_type || '';

    // Skaliranje za prikaz
    var scale = 2.2;
    var svgW = Math.max(w * scale + 80, 180);
    var svgH = l * scale + 80;
    var x0 = 40;
    var y0 = 20;
    var rw = w * scale;
    var rh = l * scale;

    // Boje ovisno o broju slojeva
    var layers = 0;
    for (var i = 1; i <= 4; i++) {
      if (art['paper_s' + i + '_code']) layers++;
    }

    var bagFill = '#f5deb3'; // default sme\u0111a
    var bagColor = (art.bag_color || '').toUpperCase();
    if (bagColor === 'B' || bagColor === 'BIJELI' || bagColor === 'W') bagFill = '#fafafa';
    if (bagColor === 'S') bagFill = '#d2b48c';

    var s = '<svg width="' + svgW + '" height="' + svgH + '" viewBox="0 0 ' + svgW + ' ' + svgH + '" xmlns="http://www.w3.org/2000/svg">';

    // Vre\u0107ica
    s += '<rect x="' + x0 + '" y="' + y0 + '" width="' + rw + '" height="' + rh + '" fill="' + bagFill + '" stroke="#8d6e63" stroke-width="2" rx="2"/>';

    // Dno (donji dio)
    var bottomH = bottom * scale;
    s += '<rect x="' + x0 + '" y="' + (y0 + rh - bottomH) + '" width="' + rw + '" height="' + bottomH + '" fill="rgba(121,85,72,0.15)" stroke="#8d6e63" stroke-width="1" stroke-dasharray="4,3"/>';
    s += '<text x="' + (x0 + rw / 2) + '" y="' + (y0 + rh - bottomH / 2 + 4) + '" text-anchor="middle" font-size="10" fill="#5d4037" font-weight="600">Dno ' + bottom + ' cm</text>';

    // Ventil (gore lijevo ili desno)
    if (valve > 0 && vType) {
      var valveH = valve * scale;
      var valveW = 20;
      s += '<rect x="' + (x0 - valveW) + '" y="' + y0 + '" width="' + valveW + '" height="' + valveH + '" fill="#ffcc80" stroke="#ef6c00" stroke-width="1.5" rx="2"/>';
      s += '<text x="' + (x0 - valveW / 2) + '" y="' + (y0 + valveH + 14) + '" text-anchor="middle" font-size="9" fill="#e65100" font-weight="600">' + escapeHtml(vType) + '</text>';
    }

    // Kotirane linije - \u0161irina (gore)
    s += '<line x1="' + x0 + '" y1="' + (y0 - 8) + '" x2="' + (x0 + rw) + '" y2="' + (y0 - 8) + '" stroke="#333" stroke-width="1" marker-start="url(#arrow)" marker-end="url(#arrow)"/>';
    s += '<text x="' + (x0 + rw / 2) + '" y="' + (y0 - 12) + '" text-anchor="middle" font-size="11" fill="#333" font-weight="700">' + w + ' cm</text>';

    // Kotirane linije - visina (desno)
    var dimX = x0 + rw + 10;
    s += '<line x1="' + dimX + '" y1="' + y0 + '" x2="' + dimX + '" y2="' + (y0 + rh) + '" stroke="#333" stroke-width="1" marker-start="url(#arrow)" marker-end="url(#arrow)"/>';
    s += '<text x="' + (dimX + 4) + '" y="' + (y0 + rh / 2) + '" font-size="11" fill="#333" font-weight="700" transform="rotate(90,' + (dimX + 4) + ',' + (y0 + rh / 2) + ')">' + l + ' cm</text>';

    // Slojevi indikator
    s += '<text x="' + (x0 + rw / 2) + '" y="' + (y0 + rh / 2 - 6) + '" text-anchor="middle" font-size="11" fill="#5d4037" font-weight="700">' + layers + ' sloj' + (layers > 1 ? 'a' : '') + '</text>';
    s += '<text x="' + (x0 + rw / 2) + '" y="' + (y0 + rh / 2 + 10) + '" text-anchor="middle" font-size="9" fill="#8d6e63">' + escapeHtml(art.has_foil === 'DA' ? 'S folijom' : 'Bez folije') + '</text>';

    // Arrow marker
    s += '<defs><marker id="arrow" markerWidth="6" markerHeight="6" refX="3" refY="3" orient="auto"><path d="M0,0 L6,3 L0,6 Z" fill="#333"/></marker></defs>';

    s += '</svg>';
    return s;
  }

  // ---------- 3. PDF ----------
  function ovjeraRenderPdf(art) {
    var h = '<div class="ovjera-card">';
    h += '<div class="ovjera-card-title pdf">Grafi\u010Dka priprema (PDF)</div>';
    h += '<div class="ovjera-card-body">';

    var url = art ? art.print_preparation_url : null;
    if (url) {
      h += '<iframe class="ovjera-pdf-frame" src="' + escapeHtml(url) + '" allow="autoplay" loading="lazy"></iframe>';
      // Link za otvaranje u novom tabu
      var viewUrl = url.replace('/preview', '/view');
      h += '<a href="' + escapeHtml(viewUrl) + '" target="_blank" class="ovjera-pdf-link">Otvori u novom tabu &#x2197;</a>';
    } else {
      h += '<div class="ovjera-pdf-placeholder">Grafi\u010Dka priprema nije u\u010Ditana za ovaj artikl</div>';
    }

    h += '</div></div>';
    return h;
  }

  // ---------- 4. OVJERA ----------
  function ovjeraRenderApproval(rn) {
    var user = Auth.getUser();
    var h = '<div class="ovjera-card">';
    h += '<div class="ovjera-card-title approval">Ovjera</div>';
    h += '<div class="ovjera-card-body">';

    // Info o kreatoru
    var kreirao = rn.created_by_name || rn.created_by || 'Nepoznato';
    var datumKreiran = rn.created_at ? formatDatumVrijeme(rn.created_at) : '\u2014';
    h += '<div class="ovjera-approval-info">';
    h += 'Kreirao: <span class="creator">' + escapeHtml(kreirao) + '</span><br>';
    h += 'Datum: ' + escapeHtml(datumKreiran);
    h += '</div>';

    if (rn.approval_status === FILTER_MAP['ceka']) {
      // Four-eyes provjera
      var isSameUser = rn.created_by_user_id && user && rn.created_by_user_id === user.id;

      if (isSameUser) {
        h += '<div class="ovjera-approval-warning">';
        h += '&#x26A0; Ne mo\u017Eete odobriti nalog koji ste sami kreirali (four-eyes princip)';
        h += '</div>';
      }

      h += '<div class="ovjera-approval-actions">';
      h += '<button class="ovjera-btn-odobri" onclick="ovjeraOdobri(\'' + rn.id + '\')"' + (isSameUser ? ' disabled title="Ne mo\u017Eete odobriti vlastiti nalog"' : '') + '>&#x2705; ODOBRI</button>';
      h += '<button class="ovjera-btn-odbij" onclick="ovjeraOdbijToggle()">&#x274C; ODBIJ</button>';
      h += '</div>';

      // Textarea za razlog odbijanja (skriveno)
      h += '<div class="ovjera-reject-area" id="ovjeraRejectArea" style="display:none;">';
      h += '<div class="ovjera-reject-label">Razlog odbijanja (obavezno):</div>';
      h += '<textarea id="ovjeraRejectReason" placeholder="Unesite razlog odbijanja..."></textarea>';
      h += '<button class="ovjera-btn-odbij" style="margin-top:8px;width:100%;" onclick="ovjeraOdbij(\'' + rn.id + '\')">Potvrdi odbijanje</button>';
      h += '</div>';

    } else if (rn.approval_status === 'Odobreno') {
      h += '<div class="ovjera-result-box odobreno">';
      h += '<strong>&#x2705; Odobreno</strong>';
      if (rn.approved_by_name) h += 'Odobrio: ' + escapeHtml(rn.approved_by_name) + '<br>';
      if (rn.approved_at) h += 'Datum: ' + formatDatumVrijeme(rn.approved_at);
      h += '</div>';

    } else if (rn.approval_status === 'Odbijeno') {
      h += '<div class="ovjera-result-box odbijeno">';
      h += '<strong>&#x274C; Odbijeno</strong>';
      if (rn.approved_by_name) h += 'Odbio: ' + escapeHtml(rn.approved_by_name) + '<br>';
      if (rn.approved_at) h += 'Datum: ' + formatDatumVrijeme(rn.approved_at) + '<br>';
      if (rn.rejection_reason) h += 'Razlog: ' + escapeHtml(rn.rejection_reason);
      h += '</div>';

      h += '<button class="ovjera-btn-resubmit" style="margin-top:12px;" onclick="ovjeraResubmit(\'' + rn.id + '\')">&#x1F504; Ponovo po\u0161alji na ovjeru</button>';
    }

    h += '</div></div>';
    return h;
  }

  // ---------- 5. POVIJEST ----------
  function ovjeraRenderHistory(rn) {
    var h = '<div class="ovjera-card">';
    h += '<div class="ovjera-card-title history">Povijest ovjere</div>';
    h += '<div class="ovjera-card-body">';
    h += '<div class="ovjera-timeline">';

    // Kreiran
    var kreirao = rn.created_by_name || rn.created_by || 'Nepoznato';
    var datumKreiran = rn.created_at ? formatDatumVrijeme(rn.created_at) : '\u2014';
    h += '<div class="ovjera-timeline-item">';
    h += '<div class="ovjera-timeline-dot created"></div>';
    h += '<div class="ovjera-timeline-text"><strong>Kreiran</strong> od ' + escapeHtml(kreirao) + ' <span class="time">' + escapeHtml(datumKreiran) + '</span></div>';
    h += '</div>';

    // Odobren/Odbijen
    if (rn.approval_status === 'Odobreno' && rn.approved_by_name) {
      h += '<div class="ovjera-timeline-item">';
      h += '<div class="ovjera-timeline-dot approved"></div>';
      h += '<div class="ovjera-timeline-text"><strong>Odobren</strong> od ' + escapeHtml(rn.approved_by_name) + ' <span class="time">' + (rn.approved_at ? formatDatumVrijeme(rn.approved_at) : '') + '</span></div>';
      h += '</div>';
    }

    if (rn.approval_status === 'Odbijeno' && rn.approved_by_name) {
      h += '<div class="ovjera-timeline-item">';
      h += '<div class="ovjera-timeline-dot rejected"></div>';
      h += '<div class="ovjera-timeline-text"><strong>Odbijen</strong> od ' + escapeHtml(rn.approved_by_name);
      if (rn.rejection_reason) h += ' \u2014 ' + escapeHtml(rn.rejection_reason);
      h += ' <span class="time">' + (rn.approved_at ? formatDatumVrijeme(rn.approved_at) : '') + '</span></div>';
      h += '</div>';
    }

    h += '</div>'; // timeline
    h += '</div></div>';
    return h;
  }

  // ============================================
  // AKCIJE
  // ============================================

  // Toggle reject area
  window.ovjeraOdbijToggle = function() {
    var area = document.getElementById('ovjeraRejectArea');
    if (area) {
      area.style.display = area.style.display === 'none' ? 'block' : 'none';
      if (area.style.display === 'block') {
        var ta = document.getElementById('ovjeraRejectReason');
        if (ta) ta.focus();
      }
    }
  };

  // ODOBRI
  window.ovjeraOdobri = async function(rnId) {
    var user = Auth.getUser();
    if (!user) return;

    if (!confirm('Jeste li sigurni da \u017Eelite odobriti ovaj radni nalog?')) return;

    if (typeof showLoading === 'function') showLoading('Odobravanje...');

    try {
      var result = await initSupabase().rpc('approve_work_order', {
        p_work_order_id: rnId,
        p_approver_user_id: user.id,
        p_approver_name: user.name
      });

      if (result.error) throw result.error;

      var data = result.data;
      if (data && data.success === false) {
        if (typeof showMessage === 'function') showMessage(data.error || 'Gre\u0161ka', 'error');
        return;
      }

      if (typeof showMessage === 'function') showMessage('Radni nalog odobren!', 'success');
      await ovjeraUcitaj();

      // Ponovo odaberi isti RN
      if (ovjeraState.odabraniRN) {
        var refreshed = ovjeraState.nalozi.find(function(n) { return n.id === rnId; });
        if (refreshed) {
          ovjeraState.odabraniRN = refreshed;
          ovjeraRenderDetalji();
        }
      }

    } catch (e) {
      console.error('Gre\u0161ka odobravanja:', e);
      if (typeof showMessage === 'function') showMessage('Gre\u0161ka: ' + e.message, 'error');
    } finally {
      if (typeof hideLoading === 'function') hideLoading();
    }
  };

  // ODBIJ
  window.ovjeraOdbij = async function(rnId) {
    var user = Auth.getUser();
    if (!user) return;

    var razlog = (document.getElementById('ovjeraRejectReason') || {}).value;
    if (!razlog || !razlog.trim()) {
      if (typeof showMessage === 'function') showMessage('Razlog odbijanja je obavezan!', 'warning');
      return;
    }

    if (!confirm('Jeste li sigurni da \u017Eelite odbiti ovaj radni nalog?')) return;

    if (typeof showLoading === 'function') showLoading('Odbijanje...');

    try {
      var result = await initSupabase().rpc('reject_work_order', {
        p_work_order_id: rnId,
        p_rejector_user_id: user.id,
        p_rejector_name: user.name,
        p_reason: razlog.trim()
      });

      if (result.error) throw result.error;

      var data = result.data;
      if (data && data.success === false) {
        if (typeof showMessage === 'function') showMessage(data.error || 'Gre\u0161ka', 'error');
        return;
      }

      if (typeof showMessage === 'function') showMessage('Radni nalog odbijen.', 'success');
      await ovjeraUcitaj();

      if (ovjeraState.odabraniRN) {
        var refreshed = ovjeraState.nalozi.find(function(n) { return n.id === rnId; });
        if (refreshed) {
          ovjeraState.odabraniRN = refreshed;
          ovjeraRenderDetalji();
        }
      }

    } catch (e) {
      console.error('Gre\u0161ka odbijanja:', e);
      if (typeof showMessage === 'function') showMessage('Gre\u0161ka: ' + e.message, 'error');
    } finally {
      if (typeof hideLoading === 'function') hideLoading();
    }
  };

  // PONOVO PO\u0160ALJI
  window.ovjeraResubmit = async function(rnId) {
    if (!confirm('Ponovo poslati nalog na ovjeru?')) return;

    if (typeof showLoading === 'function') showLoading('Slanje na ovjeru...');

    try {
      var result = await initSupabase().rpc('resubmit_work_order', {
        p_work_order_id: rnId
      });

      if (result.error) throw result.error;

      var data = result.data;
      if (data && data.success === false) {
        if (typeof showMessage === 'function') showMessage(data.error || 'Gre\u0161ka', 'error');
        return;
      }

      if (typeof showMessage === 'function') showMessage('Nalog ponovo poslan na ovjeru.', 'success');
      await ovjeraUcitaj();

      if (ovjeraState.odabraniRN) {
        var refreshed = ovjeraState.nalozi.find(function(n) { return n.id === rnId; });
        if (refreshed) {
          ovjeraState.odabraniRN = refreshed;
          ovjeraRenderDetalji();
        }
      }

    } catch (e) {
      console.error('Gre\u0161ka resubmit:', e);
      if (typeof showMessage === 'function') showMessage('Gre\u0161ka: ' + e.message, 'error');
    } finally {
      if (typeof hideLoading === 'function') hideLoading();
    }
  };

})();
