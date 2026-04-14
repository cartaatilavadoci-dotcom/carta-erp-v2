/* ============================================
   CARTA AI - Chat Widget
   Integrira se u CARTA ERP
   Server: http://192.168.1.199:3002
   ============================================ */

(function() {
  'use strict';

  // ============================================
  // PROMIJENI OVO AKO SE PROMIJENI IP MACA
  // ============================================
  var CARTA_AI_URL = 'http://192.168.1.199:3002/api';

  var CartaAI = {
    state: {
      isOpen: false,
      pendingRolls: null
    },

    init: function() {
      this.injectStyles();
      this.createWidget();
      this.bindEvents();
      console.log('🤖 CARTA AI Widget loaded (server: ' + CARTA_AI_URL + ')');
    },

    // ============================================
    // INJECT CSS
    // ============================================
    injectStyles: function() {
      if (document.getElementById('carta-ai-styles')) return;

      var style = document.createElement('style');
      style.id = 'carta-ai-styles';
      style.textContent = `
        .carta-ai-fab {
          position: fixed;
          bottom: 80px;
          right: 20px;
          width: 56px;
          height: 56px;
          border-radius: 50%;
          background: linear-gradient(135deg, #1565c0, #0d47a1);
          border: none;
          cursor: pointer;
          font-size: 28px;
          display: flex;
          align-items: center;
          justify-content: center;
          box-shadow: 0 4px 12px rgba(0,0,0,0.3);
          z-index: 10000;
          transition: transform 0.2s;
          color: white;
          font-family: sans-serif;
        }
        .carta-ai-fab:hover { transform: scale(1.1); box-shadow: 0 6px 20px rgba(0,0,0,0.4); }
        .carta-ai-fab.active { transform: scale(0.9); opacity: 0.7; }

        .carta-ai-panel {
          position: fixed;
          bottom: 146px;
          right: 20px;
          width: 380px;
          height: 520px;
          background: #fff;
          border-radius: 16px;
          box-shadow: 0 8px 32px rgba(0,0,0,0.2);
          display: none;
          flex-direction: column;
          z-index: 10001;
          overflow: hidden;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        }
        .carta-ai-panel.active { display: flex; }

        .carta-ai-header {
          background: linear-gradient(135deg, #1565c0, #0d47a1);
          color: white;
          padding: 14px 16px;
          display: flex;
          justify-content: space-between;
          align-items: center;
          font-weight: 600;
          font-size: 15px;
        }

        .carta-ai-close {
          background: none;
          border: none;
          color: white;
          font-size: 22px;
          cursor: pointer;
          padding: 0 4px;
          line-height: 1;
        }

        .carta-ai-messages {
          flex: 1;
          overflow-y: auto;
          padding: 12px;
          display: flex;
          flex-direction: column;
          gap: 8px;
          background: #f5f5f5;
        }

        .carta-ai-msg {
          max-width: 85%;
          padding: 10px 14px;
          border-radius: 14px;
          font-size: 13px;
          line-height: 1.5;
          word-break: break-word;
        }
        .carta-ai-msg.bot {
          background: white;
          align-self: flex-start;
          border: 1px solid #e0e0e0;
          border-bottom-left-radius: 4px;
        }
        .carta-ai-msg.user {
          background: #1565c0;
          color: white;
          align-self: flex-end;
          border-bottom-right-radius: 4px;
        }
        .carta-ai-msg.bot strong { color: #1565c0; }

        .carta-ai-typing span {
          animation: cartaAiDots 1.4s infinite;
          display: inline-block;
          font-size: 20px;
          line-height: 0.5;
        }
        .carta-ai-typing span:nth-child(2) { animation-delay: 0.2s; }
        .carta-ai-typing span:nth-child(3) { animation-delay: 0.4s; }
        @keyframes cartaAiDots {
          0%, 20% { opacity: 0.2; }
          50% { opacity: 1; }
          100% { opacity: 0.2; }
        }

        .carta-ai-input-area {
          display: flex;
          gap: 6px;
          padding: 10px;
          border-top: 1px solid #e0e0e0;
          background: white;
        }

        .carta-ai-input-area input[type="text"] {
          flex: 1;
          padding: 10px 14px;
          border: 1px solid #ddd;
          border-radius: 20px;
          font-size: 13px;
          outline: none;
        }
        .carta-ai-input-area input[type="text"]:focus {
          border-color: #1565c0;
        }

        .carta-ai-upload-btn,
        .carta-ai-send-btn {
          width: 38px;
          height: 38px;
          border-radius: 50%;
          border: none;
          cursor: pointer;
          font-size: 16px;
          display: flex;
          align-items: center;
          justify-content: center;
          transition: background 0.2s;
        }
        .carta-ai-upload-btn {
          background: #f0f0f0;
        }
        .carta-ai-upload-btn:hover { background: #e0e0e0; }
        .carta-ai-send-btn {
          background: #1565c0;
          color: white;
        }
        .carta-ai-send-btn:hover { background: #0d47a1; }

        .carta-ai-confirm-btns {
          display: flex;
          gap: 8px;
          margin-top: 8px;
        }
        .carta-ai-confirm-btns button {
          padding: 6px 16px;
          border-radius: 12px;
          border: none;
          cursor: pointer;
          font-size: 12px;
          font-weight: 600;
        }
        .carta-ai-btn-yes {
          background: #2e7d32;
          color: white;
        }
        .carta-ai-btn-no {
          background: #e0e0e0;
          color: #333;
        }

        .carta-ai-source {
          font-size: 10px;
          opacity: 0.5;
          margin-top: 4px;
          display: block;
        }

        /* Mobile */
        @media (max-width: 480px) {
          .carta-ai-panel {
            bottom: 0;
            right: 0;
            width: 100%;
            height: 100%;
            border-radius: 0;
          }
          .carta-ai-fab {
            bottom: 130px;
          }
        }

        /* Kad je mobile-mode aktivan, pomakni FAB iznad bottom nav */
        .mobile-mode .carta-ai-fab {
          bottom: 130px;
        }
      `;
      document.head.appendChild(style);
    },

    // ============================================
    // KREIRANJE WIDGETA
    // ============================================
    createWidget: function() {
      // FAB button
      var fab = document.createElement('button');
      fab.id = 'cartaAiFab';
      fab.className = 'carta-ai-fab no-print';
      fab.innerHTML = '<svg viewBox="0 0 24 24" width="28" height="28" fill="white" xmlns="http://www.w3.org/2000/svg"><path d="M12 2a2 2 0 012 2c0 .74-.4 1.39-1 1.73V7h1a7 7 0 017 7h1a1 1 0 110 2h-1.07A7.001 7.001 0 0113 22h-2a7.001 7.001 0 01-6.93-6H3a1 1 0 110-2h1a7 7 0 017-7h1V5.73c-.6-.34-1-.99-1-1.73a2 2 0 012-2zm0 7a5 5 0 00-5 5 5 5 0 005 5h0a5 5 0 005-5 5 5 0 00-5-5zm-2 4a1.5 1.5 0 110 3 1.5 1.5 0 010-3zm4 0a1.5 1.5 0 110 3 1.5 1.5 0 010-3z"/></svg>';
      fab.title = 'CARTA AI Asistent (Ctrl+K)';
      fab.onclick = function() { CartaAI.toggle(); };
      document.body.appendChild(fab);

      // Chat panel
      var panel = document.createElement('div');
      panel.id = 'cartaAiPanel';
      panel.className = 'carta-ai-panel no-print';
      panel.innerHTML =
        '<div class="carta-ai-header">' +
          '<span>🤖 CARTA AI</span>' +
          '<button class="carta-ai-close" onclick="CartaAI.toggle()">&times;</button>' +
        '</div>' +
        '<div class="carta-ai-messages" id="cartaAiMessages">' +
          '<div class="carta-ai-msg bot">' +
            'Bok! Ja sam CARTA AI asistent.<br>Upiši <strong>pomoć</strong> za listu naredbi ili uploadaj PDF/Excel datoteku.' +
          '</div>' +
        '</div>' +
        '<div class="carta-ai-input-area">' +
          '<input type="file" id="cartaAiFile" accept=".pdf,.xlsx,.xls,.csv" style="display:none" onchange="CartaAI.handleFile(this)">' +
          '<button class="carta-ai-upload-btn" onclick="document.getElementById(\'cartaAiFile\').click()" title="Upload PDF/Excel">📎</button>' +
          '<input type="text" id="cartaAiInput" placeholder="Pitaj me nešto..." onkeydown="if(event.key===\'Enter\')CartaAI.send()">' +
          '<button class="carta-ai-send-btn" onclick="CartaAI.send()" title="Pošalji">➤</button>' +
        '</div>';
      document.body.appendChild(panel);
    },

    // ============================================
    // EVENTS
    // ============================================
    bindEvents: function() {
      // Ctrl+K ili Cmd+K za toggle
      document.addEventListener('keydown', function(e) {
        if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
          e.preventDefault();
          CartaAI.toggle();
        }
        // Escape za zatvaranje
        if (e.key === 'Escape' && CartaAI.state.isOpen) {
          CartaAI.toggle();
        }
      });
    },

    // ============================================
    // TOGGLE PANEL
    // ============================================
    toggle: function() {
      this.state.isOpen = !this.state.isOpen;
      var panel = document.getElementById('cartaAiPanel');
      var fab = document.getElementById('cartaAiFab');
      if (this.state.isOpen) {
        panel.classList.add('active');
        fab.classList.add('active');
        document.getElementById('cartaAiInput').focus();
      } else {
        panel.classList.remove('active');
        fab.classList.remove('active');
      }
    },

    // ============================================
    // PORUKE
    // ============================================
    addMessage: function(text, isBot, sourceLabel) {
      var container = document.getElementById('cartaAiMessages');
      var msg = document.createElement('div');
      msg.className = 'carta-ai-msg ' + (isBot ? 'bot' : 'user');

      // Jednostavan markdown
      var html = text
        .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
        .replace(/\n/g, '<br>');

      if (isBot && sourceLabel) {
        html += '<span class="carta-ai-source">' + sourceLabel + '</span>';
      }

      msg.innerHTML = html;
      container.appendChild(msg);
      container.scrollTop = container.scrollHeight;
      return msg;
    },

    showTyping: function() {
      var container = document.getElementById('cartaAiMessages');
      var typing = document.createElement('div');
      typing.className = 'carta-ai-msg bot carta-ai-typing';
      typing.id = 'cartaAiTyping';
      typing.innerHTML = '<span>.</span><span>.</span><span>.</span>';
      container.appendChild(typing);
      container.scrollTop = container.scrollHeight;
    },

    hideTyping: function() {
      var el = document.getElementById('cartaAiTyping');
      if (el) el.remove();
    },

    // ============================================
    // POŠALJI PORUKU
    // ============================================
    send: function() {
      var input = document.getElementById('cartaAiInput');
      var message = input.value.trim();
      if (!message) return;

      // Provjeri potvrdu unosa rola
      if (this.state.pendingRolls && (message.toLowerCase() === 'da' || message.toLowerCase() === 'yes')) {
        this.addMessage(message, false);
        input.value = '';
        this.confirmImport();
        return;
      }
      if (this.state.pendingRolls && (message.toLowerCase() === 'ne' || message.toLowerCase() === 'no')) {
        this.addMessage(message, false);
        input.value = '';
        this.state.pendingRolls = null;
        this.addMessage('OK, unos otkazan.', true);
        return;
      }

      this.addMessage(message, false);
      input.value = '';
      this.showTyping();

      var self = this;
      fetch(CARTA_AI_URL + '/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: message })
      })
      .then(function(response) { return response.json(); })
      .then(function(data) {
        self.hideTyping();
        if (data.error) {
          self.addMessage('❌ ' + data.error, true);
        } else {
          var source = data.source === 'faq' ? '📚 FAQ' :
                       data.source === 'ollama' ? '🏠 Lokalni AI' :
                       data.source === 'claude' ? '☁️ Cloud AI' : '';
          self.addMessage(data.answer, true, source);
        }
      })
      .catch(function(error) {
        self.hideTyping();
        self.addMessage('❌ Server nije dostupan. Provjeri je li CARTA AI pokrenut na ' + CARTA_AI_URL, true);
      });
    },

    // ============================================
    // FILE UPLOAD
    // ============================================
    handleFile: function(input) {
      if (!input.files || !input.files[0]) return;

      var file = input.files[0];
      this.addMessage('📄 Uploadam: ' + file.name, false);
      this.showTyping();

      var formData = new FormData();
      formData.append('file', file);

      var self = this;
      fetch(CARTA_AI_URL + '/upload', {
        method: 'POST',
        body: formData
      })
      .then(function(response) { return response.json(); })
      .then(function(data) {
        self.hideTyping();
        if (data.error) {
          self.addMessage('❌ ' + data.error, true);
        } else if (data.success) {
          var msg = '✅ **' + data.document_type + '**\n';
          msg += 'Pronađeno: **' + data.rolls_count + ' rola** (' + data.total_kg + ' kg)\n';
          if (data.paper_type) msg += 'Tip: ' + data.paper_type + '\n';
          if (data.grammage) msg += 'Gramatura: ' + data.grammage + ' g/m²\n';
          if (data.invoice_number) msg += 'Invoice: ' + data.invoice_number + '\n';
          msg += '\nŽeliš li unijeti ove role u skladište? Upiši **da** ili **ne**.';

          self.addMessage(msg, true);
          self.state.pendingRolls = data.rolls;
        } else {
          self.addMessage('⚠️ Nisam uspio prepoznati podatke iz datoteke. Pokušaj s drugim formatom.', true);
        }
      })
      .catch(function(error) {
        self.hideTyping();
        self.addMessage('❌ Greška pri uploadu: ' + error.message, true);
      });

      input.value = '';
    },

    // ============================================
    // POTVRDI IMPORT ROLA
    // ============================================
    confirmImport: function() {
      if (!this.state.pendingRolls) return;

      this.showTyping();
      var rolls = this.state.pendingRolls;
      this.state.pendingRolls = null;

      var self = this;
      fetch(CARTA_AI_URL + '/import/rolls', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ rolls: rolls })
      })
      .then(function(response) { return response.json(); })
      .then(function(data) {
        self.hideTyping();
        if (data.success) {
          self.addMessage('✅ ' + data.message, true, '📦 Skladište');
        } else {
          self.addMessage('❌ Greška: ' + (data.error || 'Nepoznata greška'), true);
        }
      })
      .catch(function(error) {
        self.hideTyping();
        self.addMessage('❌ Greška pri unosu: ' + error.message, true);
      });
    }
  };

  // Globalna dostupnost
  window.CartaAI = CartaAI;

  // Auto-init kad je DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() { CartaAI.init(); });
  } else {
    CartaAI.init();
  }
})();
