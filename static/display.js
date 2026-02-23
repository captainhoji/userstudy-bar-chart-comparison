import { startTimer } from './utils.js';

let layoutCache = {
  attention: null,
  phoneScreen: null,
  experimentPanel: null,
  colormapBlock: null,
  instructionEl: null,
  feedbackEl: null,
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

    const phoneInstructionEl = document.createElement('p');
    phoneInstructionEl.className = 'phone-task-instruction';
    phoneInstructionEl.textContent = 'Press the spacebar when you see a message about a pet.';

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
    phonePanel.appendChild(phoneInstructionEl);
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
  instructionEl.innerHTML = 'Are there more animals early (left) or late (right) in the day?<br>Respond with the left or right arrow key.';

  const feedbackEl = document.createElement('div');
  feedbackEl.id = 'colormap-feedback';
  feedbackEl.className = 'colormap-feedback';

  const rowEl = document.createElement('div');
  rowEl.className = 'colormap-row colormap-placeholder';

  colormapBlock.appendChild(instructionEl);
  colormapBlock.appendChild(feedbackEl);
  colormapBlock.appendChild(rowEl);
  experimentPanel.appendChild(colormapBlock);
  wrapper.appendChild(experimentPanel);

  container.appendChild(wrapper);

  layoutCache = { attention, phoneScreen, experimentPanel, colormapBlock, instructionEl, feedbackEl, rowEl };
  return layoutCache;
}

export function getPhoneScreen() {
  return layoutCache.phoneScreen;
}

export function displayBlankScreen({ duration, attention = 'dual', onDone }) {
  const { rowEl, feedbackEl } = ensureLayout(attention);
  if (rowEl) {
    rowEl.className = 'colormap-row colormap-placeholder';
    rowEl.style.opacity = '1';
    rowEl.innerHTML = '';
  }
  if (feedbackEl) feedbackEl.textContent = '';

  setTimeout(() => {
    if (typeof onDone === 'function') onDone();
  }, duration);
}

export function displayHeatmapTrial({ trial, scale = 1, attention = 'dual' }) {
  const { rowEl, feedbackEl } = ensureLayout(attention);
  if (!rowEl) return;
  const scaleValue = Number(scale) > 0 ? Number(scale) : 1;
  const maxWidthVw = 60 * scaleValue;
  const maxHeightVh = 70 * scaleValue;

  if (feedbackEl) feedbackEl.textContent = '';

  rowEl.className = 'colormap-row colormap-loading';
  rowEl.style.opacity = '0';
  rowEl.innerHTML = `
    <div class="heatmap-wrapper" style="
      display: flex;
      align-items: center;
      justify-content: center;
    ">
      <img
        id="heatmap-image"
        alt="heatmap"
        style="max-width: ${maxWidthVw}vw; max-height: ${maxHeightVh}vh; object-fit: contain; display: block;"
      />
    </div>
    <div class="legend-column" style="
      display: flex;
      flex-direction: column;
      align-items: center;
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

  function applyLegendSizing() {
    const heatmapHeight = heatmapEl.getBoundingClientRect().height;
    if (!heatmapHeight || !rowEl) return;

    // Keep legend and labels at a fixed proportion of the rendered heatmap size.
    const legendHeight = Math.round(heatmapHeight * 0.65);
    // Keep labels readable but prevent oversized text on large displays.
    const labelSize = Math.round(legendHeight * 0.09);
    const gapSize = Math.max(4, Math.round(labelSize * 0.4));
    const padX = Math.max(4, Math.round(legendHeight * 0.08));

    rowEl.style.setProperty('--legend-height', `${legendHeight}px`);
    rowEl.style.setProperty('--legend-label-size', `${labelSize}px`);
    rowEl.style.setProperty('--legend-gap', `${gapSize}px`);
    rowEl.style.setProperty('--legend-pad-x', `${padX}px`);
  }

  function maybeShow() {
    if (heatmapReady && legendReady && rowEl) {
      applyLegendSizing();
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
