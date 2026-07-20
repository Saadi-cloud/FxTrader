// OLX Trade shared behavior
document.addEventListener('DOMContentLoaded', function () {
  var toggle = document.querySelector('.menu-toggle');
  var sidebar = document.querySelector('.sidebar');
  var overlay = document.querySelector('.sidebar-overlay');

  function closeSidebar() {
    sidebar && sidebar.classList.remove('open');
    overlay && overlay.classList.remove('show');
  }

  if (toggle && sidebar) {
    toggle.addEventListener('click', function () {
      sidebar.classList.toggle('open');
      overlay && overlay.classList.toggle('show');
    });
  }
  if (overlay) overlay.addEventListener('click', closeSidebar);

  // Flag-enabled country dropdown on the registration form
  document.querySelectorAll('[data-country-select]').forEach(function (wrapper) {
    var nativeSelect = wrapper.querySelector('[data-country-native]');
    var trigger = wrapper.querySelector('[data-country-trigger]');
    var menu = wrapper.querySelector('[data-country-menu]');
    var selectedText = wrapper.querySelector('[data-country-selected-text]');
    var selectedFlag = wrapper.querySelector('[data-country-selected-flag]');
    var selectedFlagWrap = wrapper.querySelector('[data-country-selected-flag-wrap]');
    var options = wrapper.querySelectorAll('[data-country-option]');

    if (!nativeSelect || !trigger || !menu) return;
    wrapper.classList.add('is-enhanced');

    function updateSelected(value) {
      var matchingOption = Array.prototype.find.call(nativeSelect.options, function (option) {
        return option.value === value;
      });
      var flag = matchingOption ? matchingOption.getAttribute('data-flag') : '';

      selectedText.textContent = matchingOption && matchingOption.value ? matchingOption.textContent : 'Select country';
      if (flag) {
        selectedFlag.src = flag;
        selectedFlag.alt = matchingOption.textContent + ' flag';
        selectedFlagWrap.hidden = false;
      } else {
        selectedFlag.src = '';
        selectedFlag.alt = '';
        selectedFlagWrap.hidden = true;
      }

      options.forEach(function (option) {
        option.setAttribute('aria-selected', option.getAttribute('data-country-value') === value ? 'true' : 'false');
      });
    }

    function closeCountryMenu() {
      wrapper.classList.remove('is-open');
      trigger.setAttribute('aria-expanded', 'false');
    }

    trigger.addEventListener('click', function () {
      var willOpen = !wrapper.classList.contains('is-open');
      document.querySelectorAll('[data-country-select].is-open').forEach(function (openWrapper) {
        if (openWrapper !== wrapper) {
          openWrapper.classList.remove('is-open');
          var openTrigger = openWrapper.querySelector('[data-country-trigger]');
          if (openTrigger) openTrigger.setAttribute('aria-expanded', 'false');
        }
      });
      wrapper.classList.toggle('is-open', willOpen);
      trigger.setAttribute('aria-expanded', willOpen ? 'true' : 'false');
      if (willOpen) {
        var selectedOption = menu.querySelector('[aria-selected="true"]') || menu.querySelector('[data-country-option]');
        if (selectedOption) selectedOption.focus();
      }
    });

    options.forEach(function (option) {
      option.addEventListener('click', function () {
        nativeSelect.value = option.getAttribute('data-country-value') || '';
        nativeSelect.dispatchEvent(new Event('change', { bubbles: true }));
        updateSelected(nativeSelect.value);
        closeCountryMenu();
        trigger.focus();
      });
    });

    nativeSelect.addEventListener('change', function () { updateSelected(nativeSelect.value); });
    wrapper.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') {
        closeCountryMenu();
        trigger.focus();
      }
    });
    document.addEventListener('click', function (event) {
      if (!wrapper.contains(event.target)) closeCountryMenu();
    });

    updateSelected(nativeSelect.value);
  });

  // Password show/hide toggle on login page
  document.querySelectorAll('.pass-toggle').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var input = btn.parentElement.querySelector('input');
      if (!input) return;
      input.type = input.type === 'password' ? 'text' : 'password';
      btn.classList.toggle('is-visible');
    });
  });

  // Filter chip toggling (history / statement pages)
  document.querySelectorAll('.filter-chips').forEach(function (group) {
    group.querySelectorAll('.chip-filter').forEach(function (chip) {
      chip.addEventListener('click', function () {
        group.querySelectorAll('.chip-filter').forEach(function (c) { c.classList.remove('active'); });
        chip.classList.add('active');
      });
    });
  });

  // Tabs row toggling (statement page: All / Deposit / Withdraw)
  document.querySelectorAll('.tabs-row').forEach(function (group) {
    var tabs = group.querySelectorAll('.tab-btn');
    tabs.forEach(function (tab) {
      tab.addEventListener('click', function () {
        tabs.forEach(function (t) { t.classList.remove('active'); });
        tab.classList.add('active');
        var target = tab.getAttribute('data-target');
        document.querySelectorAll('[data-row-type]').forEach(function (row) {
          if (target === 'all' || row.getAttribute('data-row-type') === target) {
            row.style.display = '';
          } else {
            row.style.display = 'none';
          }
        });
      });
    });
  });

  // Payment / payout method card selection
  document.querySelectorAll('.method-grid').forEach(function (grid) {
    var cards = grid.querySelectorAll('.method-card');
    cards.forEach(function (card) {
      card.addEventListener('click', function () {
        cards.forEach(function (c) { c.classList.remove('active'); });
        card.classList.add('active');
        var targetId = card.getAttribute('data-method');
        document.querySelectorAll('.pay-detail-panel').forEach(function (panel) {
          panel.classList.toggle('show', panel.getAttribute('data-method-panel') === targetId);
        });
      });
    });
  });

  // Copy-to-clipboard buttons
  document.querySelectorAll('.copy-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var field = btn.closest('.copy-field');
      var valueEl = field ? field.querySelector('.copy-field-value') : null;
      var text = valueEl ? valueEl.textContent.trim() : '';
      var restoreLabel = btn.querySelector('.copy-btn-label') ? btn.querySelector('.copy-btn-label').textContent : 'Copy';

      function showCopied() {
        btn.classList.add('copied');
        var label = btn.querySelector('.copy-btn-label');
        if (label) label.textContent = 'Copied';
        setTimeout(function () {
          btn.classList.remove('copied');
          if (label) label.textContent = restoreLabel;
        }, 1500);
      }

      if (navigator.clipboard && text) {
        navigator.clipboard.writeText(text).then(showCopied).catch(showCopied);
      } else {
        showCopied();
      }
    });
  });

  // Quick amount buttons fill the amount input
  document.querySelectorAll('.quick-amount-row').forEach(function (row) {
    var input = row.parentElement.querySelector('.field-input');
    row.querySelectorAll('.quick-amount-btn').forEach(function (btn) {
      btn.addEventListener('click', function () {
        if (input) input.value = btn.getAttribute('data-amount');
      });
    });
  });

  // Withdraw destination tabs (Bank / JazzCash / EasyPaisa / Crypto)
  document.querySelectorAll('.withdraw-method-tabs').forEach(function (group) {
    var tabs = group.querySelectorAll('.tab-btn');
    tabs.forEach(function (tab) {
      tab.addEventListener('click', function () {
        tabs.forEach(function (t) { t.classList.remove('active'); });
        tab.classList.add('active');
        var target = tab.getAttribute('data-target');
        document.querySelectorAll('[data-withdraw-fields]').forEach(function (panel) {
          panel.style.display = (panel.getAttribute('data-withdraw-fields') === target) ? '' : 'none';
        });
      });
    });
  });
});


  // Compact UID copy button. The dashboard displays digits only but copies the full USR reference.
  document.querySelectorAll('[data-copy-value]').forEach(function (button) {
    button.addEventListener('click', async function () {
      var value = button.getAttribute('data-copy-value') || '';
      if (!value) return;
      var label = button.querySelector('.uid-copy-label');
      var original = label ? label.textContent : '';
      try {
        await navigator.clipboard.writeText(value);
        button.classList.add('copied');
        if (label) label.textContent = 'Copied';
      } catch (error) {
        var textarea = document.createElement('textarea');
        textarea.value = value;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        textarea.remove();
        button.classList.add('copied');
        if (label) label.textContent = 'Copied';
      }
      window.setTimeout(function () {
        button.classList.remove('copied');
        if (label) label.textContent = original || 'Copy';
      }, 1600);
    });
  });

// Premium dashboard interactions and referral sharing
(function () {
  function initTradeDashboard() {
    var hero = document.getElementById('tradeHero');
    if (hero) {
      hero.addEventListener('mousemove', function (event) {
        if (window.innerWidth < 900) return;
        var rect = hero.getBoundingClientRect();
        var x = (event.clientX - rect.left) / rect.width - 0.5;
        var y = (event.clientY - rect.top) / rect.height - 0.5;
        hero.style.transform = 'perspective(1100px) rotateX(' + (y * -1.5) + 'deg) rotateY(' + (x * 1.8) + 'deg)';
      });
      hero.addEventListener('mouseleave', function () { hero.style.transform = ''; });
    }

    document.querySelectorAll('[data-native-share]').forEach(function (button) {
      button.addEventListener('click', async function () {
        var shareData = {
          title: button.getAttribute('data-share-title') || 'OLX Trade Referral',
          text: button.getAttribute('data-share-text') || 'Join OLX Trade with my referral.',
          url: button.getAttribute('data-share-url') || window.location.href
        };
        if (navigator.share) {
          try { await navigator.share(shareData); return; } catch (error) { if (error && error.name === 'AbortError') return; }
        }
        var fallback = 'https://wa.me/?text=' + encodeURIComponent(shareData.text + ' ' + shareData.url);
        window.open(fallback, '_blank', 'noopener');
      });
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initTradeDashboard);
  else initTradeDashboard();
})();
