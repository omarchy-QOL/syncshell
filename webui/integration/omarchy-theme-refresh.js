(function () {
  'use strict';

  var script = document.currentScript;
  var activeVersion = script
    ? script.getAttribute('data-theme-version') || ''
    : '';
  var loadingVersion = '';

  function luminance(rgb) {
    return rgb.reduce(function (sum, value, index) {
      var linear =
        value <= 0.04045
          ? value / 12.92
          : Math.pow((value + 0.055) / 1.055, 2.4);
      return sum + linear * [0.2126, 0.7152, 0.0722][index];
    }, 0);
  }

  function semanticPair(fill, colors, palette) {
    // Everforest keeps page labels readable by lightening danger interactions.
    var pageLabels = palette === 'everforest' && fill.name === 'danger';
    var mix = colors[pageLabels ? 1 : 0];
    var bodyLabels = palette === 'osaka-jade';
    var foregrounds = pageLabels
      ? colors.slice(0, 1)
      : bodyLabels
        ? colors.slice(1, 2)
        : colors;
    // Gentler pressed darkening preserves Retro 82's page-blue warning labels.
    var pressed =
      palette === 'retro-82' && fill.name === 'warning' ? 0.85 : 0.8;
    // Finer shading retains Osaka's approved fills with its deeper body cream.
    var percentages = [];
    for (var retained = 100; retained >= 0; retained -= bodyLabels ? 5 : 10)
      percentages.push(retained);
    var latte = palette === 'catppuccin-latte';
    if (palette === 'rose-pine' || latte) {
      // Approved stronger fills need deeper text, not extra page mixing.
      percentages = [
        latte ? { success: 57.5, warning: 62.5, danger: 47.5 }[fill.name] : 75,
      ];
      var textPercentage = latte ? 20 : 30;
      foregrounds = [
        {
          css:
            'color-mix(in srgb, ' +
            colors[1].css +
            ' ' +
            textPercentage +
            '%, black)',
          rgb: colors[1].rgb.map(function (value) {
            return value * (textPercentage / 100);
          }),
        },
      ];
    }
    for (var index = 0; index < percentages.length; index++) {
      var percentage = percentages[index];
      var backgrounds = [1, 0.9, pressed].map(function (state) {
        var weight = (state * percentage) / 100;
        return luminance(
          fill.rgb.map(function (value, channel) {
            return value * weight + mix.rgb[channel] * (1 - weight);
          }),
        );
      });
      var text = foregrounds.find(function (color) {
        var foreground = luminance(color.rgb);
        return backgrounds.every(function (background) {
          return (
            (Math.max(foreground, background) + 0.05) /
              (Math.min(foreground, background) + 0.05) >=
            4.5
          );
        });
      });
      if (text)
        return {
          text: text.css,
          mix: mix.css,
          pressed: pressed * 100 + '%',
          fill:
            percentage === 100
              ? fill.css
              : 'color-mix(in srgb, ' +
                fill.css +
                ' ' +
                percentage +
                '%, ' +
                mix.css +
                ')',
        };
    }
    throw new Error('No readable Omarchy foreground for ' + fill.name);
  }

  function applySemanticColors() {
    var root = document.documentElement;
    var style = getComputedStyle(root);
    var names = [
      'page',
      'text',
      'text-strong',
      'surface-muted',
      'success',
      'warning',
      'danger',
    ];
    var palette = style.getPropertyValue('--omarchy-palette').trim();
    var colors = names.map(function (name) {
      // Native alternate swatches separate otherwise similar filled roles.
      var source = name;
      if (palette === 'lumon' && name === 'success') source = 'info';
      if (palette === 'osaka-jade' && name === 'warning')
        source = 'warning-bright';
      var css = style.getPropertyValue('--color-' + source).trim();
      if (!/^#[0-9a-f]{6}$/i.test(css))
        throw new Error('Invalid Omarchy color: ' + name);
      return {
        name: name,
        css: css,
        rgb: css
          .slice(1)
          .match(/../g)
          .map(function (hex) {
            return parseInt(hex, 16) / 255;
          }),
      };
    });
    colors.slice(-3).forEach(function (fill) {
      var pair = semanticPair(fill, colors, palette);
      root.style.setProperty('--color-' + fill.name + '-text', pair.text);
      root.style.setProperty('--color-' + fill.name + '-fill', pair.fill);
      root.style.setProperty('--color-' + fill.name + '-mix', pair.mix);
      root.style.setProperty('--color-' + fill.name + '-pressed', pair.pressed);
    });
  }

  function currentStylesheet() {
    return document.querySelector(
      'link[rel~="stylesheet"][href^="assets/css/theme.css"]',
    );
  }

  function applyTheme(version) {
    if (!version || version === activeVersion || loadingVersion) {
      return;
    }

    var current = currentStylesheet();
    if (!current || !current.parentNode) return;

    loadingVersion = version;
    var replacement = current.cloneNode();
    replacement.href = 'assets/css/theme.css?v=' + encodeURIComponent(version);
    replacement.addEventListener(
      'load',
      function () {
        activeVersion = version;
        loadingVersion = '';
        current.remove();
        applySemanticColors();
      },
      { once: true },
    );
    replacement.addEventListener(
      'error',
      function () {
        loadingVersion = '';
        replacement.remove();
      },
      { once: true },
    );
    current.parentNode.insertBefore(replacement, current.nextSibling);
  }

  function ignoreThemeCheckFailure() {
    // Theme refresh is best effort; the next poll retries transient failures.
  }

  function checkTheme() {
    if (document.hidden) return;

    fetch('/theme-assets/syncthing-omarchy/theme-version.txt', {
      cache: 'no-store',
      credentials: 'same-origin',
    })
      .then(function (response) {
        if (!response.ok) throw new Error('theme version unavailable');
        return response.text();
      })
      .then(function (value) {
        var version = value.trim();
        if (/^[A-Za-z0-9._-]+$/.test(version)) applyTheme(version);
      })
      .catch(ignoreThemeCheckFailure);
  }

  document.addEventListener('visibilitychange', checkTheme);
  window.setInterval(checkTheme, 1000);
  checkTheme();
  applySemanticColors();
})();
