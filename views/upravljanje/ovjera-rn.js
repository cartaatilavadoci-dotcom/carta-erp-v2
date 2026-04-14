// ============================================
// CARTA ERP - Ovjera radnih naloga
// Four-eyes principle: RN mora biti ovjeren
// od drugog admin/superadmin korisnika
// ============================================

(function() {
  'use strict';

  // ============================================
  // VARIJABLE
  // ============================================
  var allData = [];
  var currentFilter = 'ceka';
  var selectedRN = null;
  var selectedArticle = null;

  // FILTER_MAP - ASCII vrijednosti (baza koristi ASCII, ne Unicode)
  var FILTER_MAP = {
    'ceka': 'Ceka ovjeru',
    'odobreno': 'Odobreno',
    'odbijeno': 'Odbijeno'
  };

  // ============================================
  // HELPER FUNKCIJE
  // ============================================

  function esc(str) {
    if (!str) return '';
    var div = document.createElement('div');
    div.textContent = String(str);
    return div.innerHTML;
  }

  function formatDatum(dateStr) {
    if (!dateStr) return '-';
    try {
      var d = new Date(dateStr);
      return d.toLocaleDateString('hr-HR');
    } catch(e) {
      return dateStr;
    }
  }

  function formatDatumVrijeme(dateStr) {
    if (!dateStr) return '-';
    try {
      var d = new Date(dateStr);
      return d.toLocaleDateString('hr-HR') + ' ' + d.toLocaleTimeString('hr-HR', { hour: '2-digit', minute: '2-digit' });
    } catch(e) {
      return dateStr;
    }
  }

  function formatBroj(num) {
    if (num === null || num === undefined) return '-';
    return Number(num).toLocaleString('hr-HR');
  }

  // ============================================
  // INICIJALIZACIJA
  // ============================================

  async function init() {
    console.log('Ovjera RN: Inicijalizacija...');

    // Provjera autorizacije
    if (typeof Auth === 'undefined' || !Auth.isAdmin || !Auth.isAdmin()) {
      if (typeof showMessage === 'function') {
        showMessage('Nemate pristup ovoj stranici', 'error');
      }
      window.location.hash = '#dashboard';
      return;
    }

    // Inicijalni load
    await load('ceka');
  }

  // ============================================
  // LOAD PODATAKA
  // ============================================

  async function load(filter) {
    if (typeof showLoading === 'function') showLoading();

    try {
      currentFilter = filter || 'ceka';

      // Dohvat svih RN-ova
      var query = initSupabase()
        .from('prod_work_orders')
        .select('*')
        .eq('wo_type', 'Glavni')
        .order('created_at', { ascending: false })
        .limit(500);

      var result = await query;

      if (result.error) {
        console.error('Greska pri dohvatu:', result.error);
        if (typeof showMessage === 'function') {
          showMessage('Greska pri dohvatu podataka: ' + result.error.message, 'error');
        }
        return;
      }

      allData = result.data || [];
      console.log('Ovjera RN: Ucitano', allData.length, 'naloga');

      // Update brojaca
      updateCounts();

      // Filtriraj i renderaj listu
      var filtered = filterData(currentFilter);
      renderList(filtered);

      // Update aktivnog filtera
      updateActiveFilter(currentFilter);

    } catch(err) {
      console.error('Ovjera RN greska:', err);
      if (typeof showMessage === 'function') {
        showMessage('Greska: ' + err.message, 'error');
      }
    } finally {
      if (typeof hideLoading === 'function') hideLoading();
    }
  }

  function filterData(filter) {
    if (filter === 'sve') {
      return allData;
    }
    var status = FILTER_MAP[filter];
    if (!status) return allData;
    return allData.filter(function(rn) {
      return rn.approval_status === status;
    });
  }

  function updateCounts() {
    var countCeka = 0;
    var countOdobreno = 0;
    var countOdbijeno = 0;

    allData.forEach(function(rn) {
      if (rn.approval_status === 'Ceka ovjeru') countCeka++;
      else if (rn.approval_status === 'Odobreno') countOdobreno++;
      else if (rn.approval_status === 'Odbijeno') countOdbijeno++;
    });

    var elCeka = document.getElementById('countCeka');
    var elOdobreno = document.getElementById('countOdobreno');
    var elOdbijeno = document.getElementById('countOdbijeno');
    var elSve = document.getElementById('countSve');

    if (elCeka) elCeka.textContent = countCeka;
    if (elOdobreno) elOdobreno.textContent = countOdobreno;
    if (elOdbijeno) elOdbijeno.textContent = countOdbijeno;
    if (elSve) elSve.textContent = allData.length;

    // Footer
    var footerCeka = document.getElementById('footerCeka');
    var footerOdobreno = document.getElementById('footerOdobreno');
    var footerOdbijeno = document.getElementById('footerOdbijeno');

    if (footerCeka) footerCeka.textContent = countCeka;
    if (footerOdobreno) footerOdobreno.textContent = countOdobreno;
    if (footerOdbijeno) footerOdbijeno.textContent = countOdbijeno;
  }

  function updateActiveFilter(filter) {
    var btns = document.querySelectorAll('.ovjera-filter-btn');
    btns.forEach(function(btn) {
      btn.classList.remove('active');
      if (btn.getAttribute('data-filter') === filter) {
        btn.classList.add('active');
      }
    });
  }

  // ============================================
  // RENDERIRANJE LISTE
  // ============================================

  function renderList(items) {
    var container = document.getElementById('ovjeraLista');
    if (!container) return;

    if (!items || items.length === 0) {
      container.innerHTML = '<div class="ovjera-lista-empty">Nema radnih naloga za prikaz</div>';
      return;
    }

    var html = '';
    items.forEach(function(rn) {
      var statusClass = '';
      var statusBadge = '';

      if (rn.approval_status === 'Ceka ovjeru') {
        statusClass = 'ceka';
        statusBadge = '<span class="badge-ceka">Ceka</span>';
      } else if (rn.approval_status === 'Odobreno') {
        statusClass = 'odobreno';
        statusBadge = '<span class="badge-odobreno">Odobreno</span>';
      } else if (rn.approval_status === 'Odbijeno') {
        statusClass = 'odbijeno';
        statusBadge = '<span class="badge-odbijeno">Odbijeno</span>';
      }

      var linijaClass = (rn.production_line || '').toLowerCase().indexOf('wh') >= 0 ? 'wh' : 'nli';
      var selectedClass = selectedRN && selectedRN.id === rn.id ? 'selected' : '';

      html += '<div class="ovjera-rn-card ' + selectedClass + '" onclick="ovjeraSelectRN(\'' + rn.id + '\')">';
      html += '  <div class="ovjera-rn-card-header">';
      html += '    <span class="ovjera-rn-number">' + esc(rn.wo_number) + '</span>';
      html += '    ' + statusBadge;
      html += '  </div>';
      html += '  <div class="ovjera-rn-card-body">';
      html += '    <div class="rn-artikl">' + esc(rn.article_name || rn.article_code || '-') + '</div>';
      html += '    <div>' + esc(rn.customer_name || '-') + ' | ' + formatBroj(rn.quantity) + ' kom</div>';
      html += '  </div>';
      html += '  <div class="ovjera-rn-card-footer">';
      html += '    <span class="ovjera-rn-linija ' + linijaClass + '">' + esc(rn.production_line || '-') + '</span>';
      html += '    <span>' + formatDatum(rn.created_at) + '</span>';
      html += '  </div>';
      html += '</div>';
    });

    container.innerHTML = html;
  }

  // ============================================
  // ODABIR RN-a
  // ============================================

  async function selectRN(id) {
    if (typeof showLoading === 'function') showLoading();

    try {
      // Pronadi RN u listi
      var rn = allData.find(function(r) { return r.id === id; });
      if (!rn) {
        if (typeof showMessage === 'function') {
          showMessage('Radni nalog nije pronaden', 'error');
        }
        return;
      }

      selectedRN = rn;

      // Dohvat artikla ako ima article_id
      selectedArticle = null;
      if (rn.article_id) {
        var artResult = await initSupabase()
          .from('prod_articles')
          .select('*')
          .eq('id', rn.article_id)
          .single();

        if (!artResult.error && artResult.data) {
          selectedArticle = artResult.data;
        }
      }

      // Renderaj detalje
      renderDetalji(rn, selectedArticle);

      // Update selekcije u listi
      var cards = document.querySelectorAll('.ovjera-rn-card');
      cards.forEach(function(card) {
        card.classList.remove('selected');
      });
      var selectedCard = document.querySelector('.ovjera-rn-card[onclick*="' + id + '"]');
      if (selectedCard) {
        selectedCard.classList.add('selected');
      }

    } catch(err) {
      console.error('Greska pri odabiru RN:', err);
      if (typeof showMessage === 'function') {
        showMessage('Greska: ' + err.message, 'error');
      }
    } finally {
      if (typeof hideLoading === 'function') hideLoading();
    }
  }

  // ============================================
  // RENDERIRANJE DETALJA
  // ============================================

  function renderDetalji(rn, article) {
    var container = document.getElementById('ovjeraDetalji');
    if (!container) return;

    var html = '';

    // Dohvati kupca iz artikla ako nema na RN-u
    var kupacName = rn.customer_name || (article ? article.customer_name : null) || '-';
    var linijaName = rn.production_line || '-';

    // 1. INFO O NALOGU
    html += '<div class="ovjera-card">';
    html += '  <div class="ovjera-card-title info">Informacije o nalogu</div>';
    html += '  <div class="ovjera-card-body">';
    html += '    <div class="ovjera-info-grid">';
    html += '      <div class="ovjera-info-item"><div class="ovjera-info-label">Broj naloga</div><div class="ovjera-info-value">' + esc(rn.wo_number) + '</div></div>';
    html += '      <div class="ovjera-info-item"><div class="ovjera-info-label">Narudzba</div><div class="ovjera-info-value">' + esc(rn.order_number || '-') + '</div></div>';
    html += '      <div class="ovjera-info-item"><div class="ovjera-info-label">Kupac</div><div class="ovjera-info-value">' + esc(kupacName) + '</div></div>';
    html += '      <div class="ovjera-info-item"><div class="ovjera-info-label">Linija</div><div class="ovjera-info-value">' + esc(linijaName) + '</div></div>';
    html += '      <div class="ovjera-info-item"><div class="ovjera-info-label">Artikl</div><div class="ovjera-info-value">' + esc(rn.article_name || rn.article_code || (article ? article.name : '-')) + '</div></div>';
    html += '      <div class="ovjera-info-item"><div class="ovjera-info-label">Kolicina</div><div class="ovjera-info-value">' + formatBroj(rn.quantity) + ' kom</div></div>';
    html += '      <div class="ovjera-info-item"><div class="ovjera-info-label">Status</div><div class="ovjera-info-value">' + esc(rn.status || '-') + '</div></div>';
    html += '      <div class="ovjera-info-item"><div class="ovjera-info-label">Planirani pocetak</div><div class="ovjera-info-value">' + formatDatum(rn.planned_start_date) + '</div></div>';
    if (rn.notes) {
      html += '      <div class="ovjera-info-item full-width"><div class="ovjera-info-label">Napomena</div><div class="ovjera-info-value">' + esc(rn.notes) + '</div></div>';
    }
    html += '    </div>';
    html += '  </div>';
    html += '</div>';

    // 2. SPECIFIKACIJA ARTIKLA
    if (article) {
      html += '<div class="ovjera-card">';
      html += '  <div class="ovjera-card-title spec">Specifikacija artikla</div>';
      html += '  <div class="ovjera-card-body">';
      html += '    <div class="ovjera-spec-layout">';
      html += '      <div class="ovjera-spec-svg">' + renderSVG(article) + '</div>';
      html += '      <div class="ovjera-spec-details">' + renderSpecifikacija(article) + '</div>';
      html += '    </div>';
      html += '  </div>';
      html += '</div>';
    }

    // 3. PDF GRAFICKA PRIPREMA
    html += '<div class="ovjera-card">';
    html += '<div class="ovjera-card-title pdf">Graficka priprema (PDF)</div>';
    html += '<div class="ovjera-card-body">';

    // Provjeri print_preparation_url - moze biti na artiklu ili RN-u
    var pdfUrl = null;
    if (article && article.print_preparation_url) {
      pdfUrl = article.print_preparation_url;
    } else if (rn.print_preparation_url) {
      pdfUrl = rn.print_preparation_url;
    }

    console.log('PDF URL:', pdfUrl, 'Article:', article ? article.id : 'none');

    if (pdfUrl && pdfUrl.length > 5) {
      // Google Drive ne dopusta iframe (X-Frame-Options), prikazujemo samo link
      var isGoogleDrive = pdfUrl.indexOf('drive.google.com') >= 0 || pdfUrl.indexOf('docs.google.com') >= 0;
      console.log('Is Google Drive:', isGoogleDrive);

      if (isGoogleDrive) {
        html += '<div class="ovjera-pdf-placeholder">';
        html += '<div style="font-size:56px;margin-bottom:20px;">📄</div>';
        html += '<div style="margin-bottom:20px;color:#444;font-size:15px;">Graficka priprema je pohranjena na Google Drive</div>';
        html += '<a href="' + pdfUrl + '" target="_blank" rel="noopener" class="ovjera-pdf-open-btn">Otvori PDF u novom tabu</a>';
        html += '</div>';
      } else {
        html += '<iframe class="ovjera-pdf-frame" src="' + pdfUrl + '"></iframe>';
        html += '<a class="ovjera-pdf-link" href="' + pdfUrl + '" target="_blank">Otvori u novom tabu</a>';
      }
    } else {
      html += '<div class="ovjera-pdf-placeholder">';
      html += '<div style="font-size:56px;margin-bottom:16px;opacity:0.4;">📋</div>';
      html += '<div style="color:#888;">Nema graficke pripreme za ovaj artikl</div>';
      html += '</div>';
    }
    html += '</div>';
    html += '</div>';

    // 4. OVJERA SEKCIJA
    html += renderOvjera(rn);

    container.innerHTML = html;
  }

  // ============================================
  // SVG VIZUALIZACIJA
  // ============================================

  function renderSVG(article) {
    if (!article) return '';

    var w = article.bag_width || 100;
    var h = article.bag_length || 200;
    var b = article.bag_bottom || 30;

    // Skaliraj za prikaz
    var scale = 0.8;
    var svgW = Math.min(w * scale, 120);
    var svgH = Math.min(h * scale, 180);
    var svgB = Math.min(b * scale, 40);

    var svg = '<svg width="' + (svgW + 40) + '" height="' + (svgH + svgB + 30) + '" viewBox="0 0 ' + (svgW + 40) + ' ' + (svgH + svgB + 30) + '">';

    // Tijelo vrecice
    svg += '<rect x="20" y="10" width="' + svgW + '" height="' + svgH + '" fill="#f5f5f5" stroke="#333" stroke-width="2"/>';

    // Dno (trapez)
    svg += '<polygon points="20,' + (svgH + 10) + ' ' + (svgW + 20) + ',' + (svgH + 10) + ' ' + (svgW + 10) + ',' + (svgH + svgB + 10) + ' 30,' + (svgH + svgB + 10) + '" fill="#e0e0e0" stroke="#333" stroke-width="2"/>';

    // Dimenzije
    svg += '<text x="' + (svgW/2 + 20) + '" y="' + (svgH + svgB + 25) + '" text-anchor="middle" font-size="10" fill="#666">' + w + ' x ' + h + ' x ' + b + '</text>';

    svg += '</svg>';
    return svg;
  }

  // ============================================
  // SPECIFIKACIJA
  // ============================================

  // Helper za formatiranje brojeva u specifikaciji
  function fmtNum(val) {
    if (val === null || val === undefined || val === '') return '\u2014';
    var num = Number(val);
    if (isNaN(num)) return String(val);
    return num % 1 === 0 ? String(num) : num.toFixed(2);
  }

  function specRow(label, value) {
    return '<div class="ovjera-spec-row"><span class="label">' + esc(label) + '</span><span class="value">' + esc(String(value || '\u2014')) + '</span></div>';
  }

  function specRowHtml(label, htmlValue) {
    return '<div class="ovjera-spec-row"><span class="label">' + esc(label) + '</span><span class="value">' + (htmlValue || '\u2014') + '</span></div>';
  }

  function specRowHighlight(label, htmlValue) {
    return '<div class="ovjera-spec-row highlight"><span class="label">' + esc(label) + '</span><span class="value">' + (htmlValue || '\u2014') + '</span></div>';
  }

  function renderSpecifikacija(article) {
    if (!article) return '<div>Nema podataka o artiklu</div>';

    var html = '';
    var art = article;

    // Prebrojimo slojeve za naslov
    var layerCount = 0;
    for (var sc = 1; sc <= 4; sc++) { if (art['paper_s' + sc + '_code']) layerCount++; }

    // ==========================================
    // 1. DIMENZIJE VRECE (lijevo)
    // ==========================================
    html += '<div class="ovjera-spec-section">';
    html += '<div class="ovjera-spec-section-title">\uD83C\uDFF7\uFE0F Dimenzije Vre\u0107e</div>';
    html += specRow('\u0160irina (cm)', fmtNum(art.bag_width));
    html += specRow('Du\u017eina (cm)', fmtNum(art.bag_length));
    html += specRow('Dno (cm)', fmtNum(art.bag_bottom));
    html += specRow('Ventil (cm)', fmtNum(art.bag_valve));
    html += specRow('Tip ventila', art.valve_type || '\u2014');
    html += specRow('Pozicija ventila', art.valve_position || '\u2014');

    // REZ - Izracun
    var bagLength = parseFloat(art.bag_length) || 0;
    var bagBottom = parseFloat(art.bag_bottom) || 0;
    var valveTypeStr = art.valve_type || '';
    if (bagLength > 0) {
      var rezValue = 0;
      var rezFormula = '';
      if (valveTypeStr === 'OL') {
        rezValue = bagLength + (bagBottom / 2) + 2;
        rezFormula = bagLength + ' + ' + bagBottom + '/2 + 2';
      } else {
        rezValue = bagLength + bagBottom + 4;
        rezFormula = bagLength + ' + ' + bagBottom + ' + 4';
      }
      html += specRowHighlight('Rez - Izra\u010Dun', '<strong>' + rezValue + '</strong> <span style="font-size:0.85em;color:#666;">(' + rezFormula + ')</span>');
    }
    html += specRow('Boja vre\u0107e', art.bag_color || '\u2014');
    html += '</div>';

    // ==========================================
    // 2. SLOJEVI PAPIRA (desno)
    // ==========================================
    html += '<div class="ovjera-spec-section">';
    html += '<div class="ovjera-spec-section-title">\uD83D\uDCC4 Papir - ' + layerCount + ' Sloja</div>';
    html += '<table class="ovjera-layers-table">';
    html += '<tr><th>Sloj</th><th>\u0160ifra</th><th>\u0160irina</th><th>Gramatura</th></tr>';
    var hasLayers = false;
    for (var s = 1; s <= 4; s++) {
      var code = art['paper_s' + s + '_code'];
      if (code) {
        hasLayers = true;
        html += '<tr>';
        html += '<td>S' + s + '</td>';
        html += '<td>' + esc(code) + '</td>';
        html += '<td>' + fmtNum(art['paper_s' + s + '_width']) + ' cm</td>';
        html += '<td>' + fmtNum(art['paper_s' + s + '_grammage']) + ' g/m\u00B2</td>';
        html += '</tr>';
      }
    }
    if (!hasLayers) {
      html += '<tr><td colspan="4" style="color:#999;text-align:center;padding:12px;">Nema podataka</td></tr>';
    }
    html += '</table>';
    html += '</div>';

    // ==========================================
    // 3. VENTIL MATERIJAL
    // ==========================================
    if (art.valve_s1_paper_code) {
      html += '<div class="ovjera-spec-section full-width">';
      html += '<div class="ovjera-spec-section-title">\uD83D\uDD27 Ventil Materijal</div>';
      if (art.perforation_valve) {
        html += specRow('Perforacija ventila', art.perforation_valve);
        if (art.perforation_valve_type) {
          html += specRow('Vrsta perforacije', art.perforation_valve_type);
        }
      }
      html += '<table class="ovjera-layers-table">';
      html += '<tr><th>Sloj</th><th>\u0160ifra</th><th>Boja</th><th>\u0160irina</th><th>Gram.</th><th>Du\u017eina</th><th>Preklop</th><th>Ukupno</th></tr>';
      for (var v = 1; v <= 2; v++) {
        var vc = art['valve_s' + v + '_paper_code'];
        if (vc) {
          var vLen = parseFloat(art['valve_s' + v + '_length']) || 0;
          var vOvr = parseFloat(art['valve_s' + v + '_overlap']) || 0;
          var vTotal = vLen + vOvr;
          html += '<tr>';
          html += '<td>V' + v + '</td>';
          html += '<td>' + esc(vc) + '</td>';
          html += '<td>' + esc(art['valve_s' + v + '_paper_color'] || '\u2014') + '</td>';
          html += '<td>' + fmtNum(art['valve_s' + v + '_width']) + '</td>';
          html += '<td>' + fmtNum(art['valve_s' + v + '_grammage']) + '</td>';
          html += '<td>' + fmtNum(vLen) + '</td>';
          html += '<td>' + fmtNum(vOvr) + '</td>';
          html += '<td><strong>' + fmtNum(vTotal) + '</strong></td>';
          html += '</tr>';
        }
      }
      html += '</table>';
      html += '</div>';
    }

    // ==========================================
    // 4. GORNJE DNO (lijevo)
    // ==========================================
    if (art.top_paper_code) {
      html += '<div class="ovjera-spec-section">';
      html += '<div class="ovjera-spec-section-title">\u2B06\uFE0F Gornje Dno</div>';
      html += specRow('\u0160ifra papira', art.top_paper_code);
      html += specRow('Dvojni preklop', art.top_double_overlap || '\u2014');
      html += specRow('\u0160irina', fmtNum(art.top_width) + ' cm');
      html += specRow('Gramatura', fmtNum(art.top_grammage) + ' g/m\u00B2');
      var topLen = parseFloat(art.top_length) || 0;
      var topOvr = parseFloat(art.top_overlap) || 0;
      html += specRow('Du\u017eina', fmtNum(topLen) + ' cm');
      html += specRow('Preklop', fmtNum(topOvr) + ' cm');
      if (topLen > 0) {
        html += specRowHighlight('Ukupna du\u017eina', '<strong>' + fmtNum(topLen + topOvr) + ' cm</strong>');
      }
      if (art.top_color_1) html += specRow('Boja 1', art.top_color_1);
      if (art.top_color_2) html += specRow('Boja 2', art.top_color_2);
      html += '</div>';
    }

    // ==========================================
    // 5. DONJE DNO (desno)
    // ==========================================
    if (art.bottom_paper_code) {
      html += '<div class="ovjera-spec-section">';
      html += '<div class="ovjera-spec-section-title">\u2B07\uFE0F Donje Dno</div>';
      html += specRow('\u0160ifra papira', art.bottom_paper_code);
      html += specRow('Dvojni preklop', art.bottom_double_overlap || '\u2014');
      html += specRow('\u0160irina', fmtNum(art.bottom_width) + ' cm');
      html += specRow('Gramatura', fmtNum(art.bottom_grammage) + ' g/m\u00B2');
      var btmLen = parseFloat(art.bottom_length) || 0;
      var btmOvr = parseFloat(art.bottom_overlap) || 0;
      html += specRow('Du\u017eina', fmtNum(btmLen) + ' cm');
      html += specRow('Preklop', fmtNum(btmOvr) + ' cm');
      if (btmLen > 0) {
        html += specRowHighlight('Ukupna du\u017eina', '<strong>' + fmtNum(btmLen + btmOvr) + ' cm</strong>');
      }
      if (art.bottom_color_1) html += specRow('Boja 1', art.bottom_color_1);
      if (art.bottom_color_2) html += specRow('Boja 2', art.bottom_color_2);
      html += '</div>';
    }

    // ==========================================
    // 6. FOLIJA
    // ==========================================
    if (art.foil_code || art.foil_type) {
      html += '<div class="ovjera-spec-section">';
      html += '<div class="ovjera-spec-section-title">\uD83D\uDCE6 Folija</div>';
      html += specRow('\u0160ifra', art.foil_code || '\u2014');
      html += specRow('Tip', art.foil_type || '\u2014');
      html += specRow('\u0160irina', fmtNum(art.foil_width) + ' cm');
      html += specRow('Mikroni', fmtNum(art.foil_microns));
      html += '</div>';
    }

    // ==========================================
    // 7. TUBER SPECIFIKACIJE (lijevo)
    // ==========================================
    html += '<div class="ovjera-spec-section">';
    html += '<div class="ovjera-spec-section-title">\uD83D\uDEE0\uFE0F Tuber Specifikacije</div>';
    html += specRow('Duljina tuljka', fmtNum(art.tube_length) + ' cm');
    html += specRow('Vrsta reza', art.cut_type || '\u2014');
    html += specRow('Prstohvat', art.finger_hole || '\u2014');
    html += specRow('Broj boja', art.colors_count || '\u2014');
    html += specRow('Folija', art.has_foil || '\u2014');
    // Tuber boje
    var tuberBoje = [art.tuber_color_1, art.tuber_color_2, art.tuber_color_3, art.tuber_color_4].filter(Boolean);
    if (tuberBoje.length > 0) {
      html += '<div class="ovjera-color-chips">';
      tuberBoje.forEach(function(b) {
        html += '<span class="ovjera-color-chip">' + esc(b) + '</span>';
      });
      html += '</div>';
    }
    html += '</div>';

    // ==========================================
    // 8. PERFORACIJE (desno)
    // ==========================================
    html += '<div class="ovjera-spec-section">';
    html += '<div class="ovjera-spec-section-title">\uD83D\uDCC1 Perforacije</div>';
    var hasPerf = false;
    for (var p = 1; p <= 4; p++) {
      var perf = art['perforation_s' + p];
      if (perf) {
        hasPerf = true;
        html += specRow('Perforacija S' + p, perf);
      }
    }
    if (art.perforation_valve) {
      hasPerf = true;
      html += specRow('Perf. ventila', art.perforation_valve);
      if (art.perforation_valve_type) {
        html += specRow('Vrsta perf.', art.perforation_valve_type);
      }
    }
    if (!hasPerf) {
      html += '<div style="color:#999;font-size:13px;padding:10px 12px;">Nema perforacija</div>';
    }
    html += '</div>';

    // ==========================================
    // 9. TISAK (lijevo)
    // ==========================================
    html += '<div class="ovjera-spec-section">';
    html += '<div class="ovjera-spec-section-title">\uD83C\uDFA8 Tisak</div>';
    html += specRow('Broj boja (tisak)', fmtNum(art.print_colors_count));
    html += specRow('Debljina kli\u0161ea', fmtNum(art.cliche_thickness) + ' mm');
    html += specRow('Duplofan', fmtNum(art.duplofan_thickness) + ' mm');
    // Tisak boje
    var tiskBoje = [];
    for (var b = 1; b <= 6; b++) {
      var boja = art['print_color_' + b];
      if (boja) tiskBoje.push(boja);
    }
    if (tiskBoje.length > 0) {
      html += '<div class="ovjera-color-chips">';
      tiskBoje.forEach(function(b) {
        html += '<span class="ovjera-color-chip" style="background:#e3f2fd;border-color:#64b5f6;color:#1565c0;">' + esc(b) + '</span>';
      });
      html += '</div>';
    }
    // Anilox
    var aniloxArr = [];
    for (var a = 1; a <= 6; a++) {
      var an = art['anilox_' + a];
      if (an) aniloxArr.push(an);
    }
    if (aniloxArr.length > 0) {
      html += specRow('Anilox', aniloxArr.join(', '));
    }
    html += '</div>';

    // ==========================================
    // 10. PAKIRANJE (desno)
    // ==========================================
    html += '<div class="ovjera-spec-section">';
    html += '<div class="ovjera-spec-section-title">\uD83D\uDCE5 Pakiranje</div>';
    html += specRow('Bottomer', art.bottomer_type || '\u2014');
    html += specRow('Kom/paket', fmtNum(art.pcs_per_package));
    html += specRow('Kom/paleta', art.pallet_quantity || art.pcs_per_pallet || '\u2014');
    html += specRow('Paleta', art.pallet_type || '\u2014');
    html += specRow('Pakiranje', art.packaging_type || '\u2014');
    html += '</div>';

    // ==========================================
    // 11. NAPOMENA (full width)
    // ==========================================
    if (art.notes) {
      html += '<div class="ovjera-spec-section full-width">';
      html += '<div class="ovjera-spec-section-title" style="background:linear-gradient(135deg,#ef6c00,#e65100);">\u270D\uFE0F Napomena</div>';
      html += '<div style="font-size:14px;line-height:1.6;color:#5d4037;padding:10px 12px;">';
      html += esc(art.notes);
      html += '</div>';
      html += '</div>';
    }

    return html;
  }

  // ============================================
  // OVJERA SEKCIJA
  // ============================================

  function renderOvjera(rn) {
    var html = '<div class="ovjera-card">';
    html += '  <div class="ovjera-card-title approval">Ovjera</div>';
    html += '  <div class="ovjera-card-body">';

    // Info o kreatoru - provjeri vise polja
    var kreator = rn.created_by_name || rn.created_by || rn.operator || 'System';
    html += '  <div class="ovjera-approval-info">';
    html += '    <div>Kreirao: <span class="creator">' + esc(kreator) + '</span></div>';
    html += '    <div>Datum: ' + formatDatumVrijeme(rn.created_at) + '</div>';
    html += '  </div>';

    var currentUser = (typeof Auth !== 'undefined' && Auth.getUser) ? Auth.getUser() : null;
    var currentUserId = currentUser ? currentUser.id : null;
    var isCreator = rn.created_by_user_id && currentUserId && rn.created_by_user_id === currentUserId;

    if (rn.approval_status === 'Ceka ovjeru') {
      // Four-eyes upozorenje
      if (isCreator) {
        html += '  <div class="ovjera-approval-warning">Ne mozete odobriti nalog koji ste sami kreirali (four-eyes principle)</div>';
      }

      // Akcijski gumbi
      html += '  <div class="ovjera-approval-actions">';
      html += '    <button class="ovjera-btn-odobri" onclick="ovjeraApprove()"' + (isCreator ? ' disabled' : '') + '>ODOBRI</button>';
      html += '    <button class="ovjera-btn-odbij" onclick="document.getElementById(\'rejectArea\').style.display=\'block\'">ODBIJ</button>';
      html += '  </div>';

      // Textarea za razlog odbijanja
      html += '  <div class="ovjera-reject-area" id="rejectArea" style="display:none;">';
      html += '    <div class="ovjera-reject-label">Razlog odbijanja (obavezno):</div>';
      html += '    <textarea id="rejectReason" placeholder="Unesite razlog odbijanja..."></textarea>';
      html += '    <button class="ovjera-btn-odbij" onclick="ovjeraReject()" style="margin-top:8px;">POTVRDI ODBIJANJE</button>';
      html += '  </div>';

    } else if (rn.approval_status === 'Odobreno') {
      html += '  <div class="ovjera-result-box odobreno">';
      html += '    <strong>ODOBRENO</strong>';
      html += '    <div>Odobrio: ' + esc(rn.approved_by_name || '-') + '</div>';
      html += '    <div>Datum: ' + formatDatumVrijeme(rn.approved_at) + '</div>';
      html += '  </div>';

    } else if (rn.approval_status === 'Odbijeno') {
      html += '  <div class="ovjera-result-box odbijeno">';
      html += '    <strong>ODBIJENO</strong>';
      html += '    <div>Odbio: ' + esc(rn.approved_by_name || '-') + '</div>';
      html += '    <div>Datum: ' + formatDatumVrijeme(rn.approved_at) + '</div>';
      if (rn.rejection_reason) {
        html += '    <div style="margin-top:8px;"><strong>Razlog:</strong> ' + esc(rn.rejection_reason) + '</div>';
      }
      html += '  </div>';
      html += '  <button class="ovjera-btn-resubmit" onclick="ovjeraResubmit()" style="margin-top:12px;">Ponovo posalji na ovjeru</button>';
    }

    html += '  </div>';
    html += '</div>';

    return html;
  }

  // ============================================
  // AKCIJE: ODOBRI / ODBIJ / RESUBMIT
  // ============================================

  async function approve() {
    if (!selectedRN) {
      if (typeof showMessage === 'function') {
        showMessage('Nema odabranog naloga', 'error');
      }
      return;
    }

    var currentUser = (typeof Auth !== 'undefined' && Auth.getUser) ? Auth.getUser() : null;
    if (!currentUser) {
      if (typeof showMessage === 'function') {
        showMessage('Greska: Korisnik nije prijavljen', 'error');
      }
      return;
    }

    if (typeof showLoading === 'function') showLoading();

    try {
      // SB.rpc auto-throws na error + auto-toast
      var data = await SB.rpc('approve_work_order', {
        p_work_order_id: selectedRN.id,
        p_approver_user_id: currentUser.id,
        p_approver_name: currentUser.name || currentUser.username || 'Admin'
      });

      if (data && data.success === false) {
        throw new Error(data.error || 'Nepoznata greska');
      }

      if (typeof showMessage === 'function') {
        showMessage(data.message || 'Nalog odobren', 'success');
      }

      // Refresh
      await load(currentFilter);
      if (selectedRN) {
        await selectRN(selectedRN.id);
      }

    } catch(err) {
      console.error('Greska pri odobravanju:', err);
      if (typeof showMessage === 'function') {
        showMessage('Greska: ' + err.message, 'error');
      }
    } finally {
      if (typeof hideLoading === 'function') hideLoading();
    }
  }

  async function reject() {
    if (!selectedRN) {
      if (typeof showMessage === 'function') {
        showMessage('Nema odabranog naloga', 'error');
      }
      return;
    }

    var reasonEl = document.getElementById('rejectReason');
    var reason = reasonEl ? reasonEl.value.trim() : '';

    if (!reason) {
      if (typeof showMessage === 'function') {
        showMessage('Razlog odbijanja je obavezan', 'error');
      }
      return;
    }

    var currentUser = (typeof Auth !== 'undefined' && Auth.getUser) ? Auth.getUser() : null;
    if (!currentUser) {
      if (typeof showMessage === 'function') {
        showMessage('Greska: Korisnik nije prijavljen', 'error');
      }
      return;
    }

    if (typeof showLoading === 'function') showLoading();

    try {
      var data = await SB.rpc('reject_work_order', {
        p_work_order_id: selectedRN.id,
        p_rejector_user_id: currentUser.id,
        p_rejector_name: currentUser.name || currentUser.username || 'Admin',
        p_reason: reason
      });

      if (data && data.success === false) {
        throw new Error(data.error || 'Nepoznata greska');
      }

      if (typeof showMessage === 'function') {
        showMessage(data.message || 'Nalog odbijen', 'success');
      }

      // Refresh
      await load(currentFilter);
      if (selectedRN) {
        await selectRN(selectedRN.id);
      }

    } catch(err) {
      console.error('Greska pri odbijanju:', err);
      if (typeof showMessage === 'function') {
        showMessage('Greska: ' + err.message, 'error');
      }
    } finally {
      if (typeof hideLoading === 'function') hideLoading();
    }
  }

  async function resubmit() {
    if (!selectedRN) {
      if (typeof showMessage === 'function') {
        showMessage('Nema odabranog naloga', 'error');
      }
      return;
    }

    if (typeof showLoading === 'function') showLoading();

    try {
      var data = await SB.rpc('resubmit_work_order', {
        p_work_order_id: selectedRN.id
      });

      if (data && data.success === false) {
        throw new Error(data.error || 'Nepoznata greska');
      }

      if (typeof showMessage === 'function') {
        showMessage(data.message || 'Nalog ponovo poslan na ovjeru', 'success');
      }

      // Refresh
      await load('ceka');
      if (selectedRN) {
        await selectRN(selectedRN.id);
      }

    } catch(err) {
      console.error('Greska pri ponovnom slanju:', err);
      if (typeof showMessage === 'function') {
        showMessage('Greska: ' + err.message, 'error');
      }
    } finally {
      if (typeof hideLoading === 'function') hideLoading();
    }
  }

  // ============================================
  // EXPOSE TO WINDOW
  // ============================================

  window.ovjeraFilter = function(btn) {
    var filter = btn.getAttribute('data-filter');
    if (filter) {
      currentFilter = filter;
      var filtered = filterData(filter);
      renderList(filtered);
      updateActiveFilter(filter);
    }
  };

  window.ovjeraSelectRN = selectRN;
  window.ovjeraApprove = approve;
  window.ovjeraReject = reject;
  window.ovjeraResubmit = resubmit;
  window.ovjeraUcitaj = function() { load(currentFilter); };
  window.ovjeraRefresh = function() { load(currentFilter); };

  // ============================================
  // INIT
  // ============================================
  init();

})();
