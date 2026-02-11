import { startTimer } from './utils.js';

let layoutCache = {
  attention: null,
  phoneScreen: null,
  experimentPanel: null,
  colormapBlock: null,
  instructionEl: null,
  rowEl: null
};

function ensureLayout(attention) {
  const container = document.getElementById('chart-container');
  container.style.display = 'flex';

  if (layoutCache.experimentPanel && layoutCache.attention === attention) {
    return layoutCache;
  }

  container.innerHTML = '';

  const wrapper = document.createElement('div');
  wrapper.style.display = 'flex';
  wrapper.style.flexDirection = 'row';
  wrapper.style.justifyContent = 'center';
  wrapper.style.alignItems = 'center';
  wrapper.style.height = '100vh';
  wrapper.style.width = '100vw';
  wrapper.style.gap = '150px';

  let phoneScreen = null;
  if (attention === 'dual') {
    const phonePanel = document.createElement('div');
    phonePanel.className = 'attention-panel';

    const phoneFrame = document.createElement('div');
    phoneFrame.className = 'phone-frame';

    const phoneNotch = document.createElement('div');
    phoneNotch.className = 'phone-notch';

    phoneScreen = document.createElement('div');
    phoneScreen.className = 'phone-screen';

    const phoneHome = document.createElement('div');
    phoneHome.className = 'phone-home';

    phoneFrame.appendChild(phoneNotch);
    phoneFrame.appendChild(phoneScreen);
    phoneFrame.appendChild(phoneHome);
    phonePanel.appendChild(phoneFrame);
    wrapper.appendChild(phonePanel);
  }

  const experimentPanel = document.createElement('div');
  experimentPanel.className = 'experiment-panel';

  const colormapBlock = document.createElement('div');
  colormapBlock.className = 'colormap-block';

  const instructionEl = document.createElement('p');
  instructionEl.id = 'controls-instruction';
  instructionEl.className = 'colormap-instruction';
  instructionEl.textContent = 'Which side shows greater values? Respond with the left or right arrow key.';

  const rowEl = document.createElement('div');
  rowEl.className = 'colormap-row colormap-placeholder';

  colormapBlock.appendChild(instructionEl);
  colormapBlock.appendChild(rowEl);
  experimentPanel.appendChild(colormapBlock);
  wrapper.appendChild(experimentPanel);

  container.appendChild(wrapper);

  layoutCache = { attention, phoneScreen, experimentPanel, colormapBlock, instructionEl, rowEl };
  return layoutCache;
}

export function getPhoneScreen() {
  return layoutCache.phoneScreen;
}

export function displayBlankScreen({ duration, attention = 'dual', onDone }) {
  const { rowEl } = ensureLayout(attention);
  if (rowEl) {
    rowEl.className = 'colormap-row colormap-placeholder';
    rowEl.style.opacity = '1';
    rowEl.innerHTML = '';
  }

  setTimeout(() => {
    if (typeof onDone === 'function') onDone();
  }, duration);
}

export function displayHeatmapTrial({ trial, scale = 1, attention = 'dual' }) {
  const { rowEl } = ensureLayout(attention);
  if (!rowEl) return;

  rowEl.className = 'colormap-row colormap-loading';
  rowEl.style.opacity = '0';
  rowEl.innerHTML = `
    <div style="
      display: flex;
      align-items: center;
      justify-content: center;
    ">
      <img
        id="heatmap-image"
        alt="heatmap"
        style="max-width: 60vw; max-height: 70vh; object-fit: contain; transform: scale(${scale});"
      />
    </div>
    <div style="
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 8px;
    ">
      <div class="legend-label legend-label-top">${trial.legendLabelTop}</div>
      <img
        id="legend-image"
        alt="legend"
        class="legend-image"
      />
      <div class="legend-label legend-label-bottom">${trial.legendLabelBottom}</div>
    </div>
  `;

  const heatmapEl = rowEl.querySelector('#heatmap-image');
  const legendEl = rowEl.querySelector('#legend-image');

  let heatmapReady = false;
  let legendReady = false;

  function maybeShow() {
    if (heatmapReady && legendReady && rowEl) {
      rowEl.style.opacity = '1';
    }
  }

  heatmapEl.onload = () => {
    heatmapReady = true;
    maybeShow();
  };
  legendEl.onload = () => {
    legendReady = true;
    maybeShow();
  };

  heatmapEl.src = trial.heatmapSrc;
  legendEl.src = trial.legendSrc;

  startTimer();
}
