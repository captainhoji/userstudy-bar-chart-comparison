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

function getTaskPrompt(stimuliMode = 'colormap') {
  if (stimuliMode === 'barchart') {
    return 'You will see two bar charts. Use the left or right arrow key to choose the correct chart.';
  }
  if (stimuliMode === 'linechart') {
    return 'Across categories, are values higher early (left) or late (right)?<br>Respond with the left or right arrow key.';
  }
  return 'Are there more animals early (left) or late (right) in the day?<br>Respond with the left or right arrow key.';
}

function ensureLayout(attention, stimuliMode = 'colormap') {
  const container = document.getElementById('chart-container');
  container.style.display = 'flex';

  if (layoutCache.experimentPanel && layoutCache.attention === attention) {
    // Keep existing instruction text while layout is reused.
    // (In linechart mode we control text per-trial in displayHeatmapTrial.)
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
  instructionEl.innerHTML = getTaskPrompt(stimuliMode);

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

export function displayBlankScreen({ duration, attention = 'dual', stimuliMode = 'colormap', onDone }) {
  const { rowEl, feedbackEl, instructionEl } = ensureLayout(attention, stimuliMode);
  if (rowEl) {
    // Keep the same row footprint during blank intervals so the phone panel
    // does not shift horizontally between trials in linechart mode.
    rowEl.className = (stimuliMode === 'linechart' || stimuliMode === 'barchart')
      ? 'colormap-row linechart-row colormap-placeholder'
      : 'colormap-row colormap-placeholder';
    rowEl.style.opacity = '1';
    rowEl.innerHTML = '';
  }
  if (feedbackEl) feedbackEl.textContent = '';
  // In linechart mode, keep the in-between-trial period text-free.
  if (instructionEl && (stimuliMode === 'linechart' || stimuliMode === 'barchart')) instructionEl.innerHTML = '';

  setTimeout(() => {
    if (typeof onDone === 'function') onDone();
  }, duration);
}

export function displayHeatmapTrial({ trial, scale = 1, attention = 'dual', onDisplayed = null }) {
  const mode = (trial?.type === 'linechart' || trial?.type === 'barchart') ? trial.type : 'colormap';
  const { rowEl, feedbackEl, instructionEl } = ensureLayout(attention, mode);
  if (!rowEl) return;
  const scaleValue = Number(scale) > 0 ? Number(scale) : 1;
  const maxWidthVw = 60 * scaleValue;
  const maxHeightVh = 70 * scaleValue;

  if (feedbackEl) feedbackEl.textContent = '';
  // Update prompt text per-trial in linechart mode (statement verification task).
  if (instructionEl && (trial?.type === 'linechart' || trial?.type === 'barchart') && trial?.statementText) {
    const a = trial?.categoryA || '';
    const b = trial?.categoryB || '';
    let statementHtml = trial.statementText || '';
    // Swap generic "value" wording with the chart's y-label (e.g., Views, Streams).
    if (trial?.yLabel) {
      const yWord = trial.yLabel.toLowerCase();
      statementHtml = statementHtml.replace(/\boverall value\b/gi, `overall ${yWord}`);
      statementHtml = statementHtml.replace(/\bvalue\b/gi, yWord);
    }
    if (a) {
      statementHtml = statementHtml.replace(new RegExp(`\\b${a}\\b`, 'g'), `<b>${a}</b>`);
    }
    if (b) {
      statementHtml = statementHtml.replace(new RegExp(`\\b${b}\\b`, 'g'), `<b>${b}</b>`);
    }
    const responseHintHtml = trial?.type === 'barchart'
      ? 'Respond with the left or right arrow key.'
      : '(False) ← &nbsp;&nbsp;&nbsp;&nbsp; → (True)';
    instructionEl.innerHTML = `
      <span class="linechart-statement-text">${statementHtml}</span><br>
      <span class="linechart-response-hints">${responseHintHtml}</span>
    `;
  } else if (instructionEl) {
    instructionEl.innerHTML = getTaskPrompt('colormap');
  }

  rowEl.className = (trial?.type === 'linechart' || trial?.type === 'barchart')
    ? 'colormap-row linechart-row colormap-loading'
    : 'colormap-row colormap-loading';
  rowEl.style.opacity = '0';
  // Line-chart stimuli are pre-composed PNGs (chart + legend in one image).
  if (trial?.type === 'linechart' || trial?.type === 'barchart') {
    // Linechart images include axes + legend, so we give them a larger box
    // and avoid the fixed-height clipping used by heatmaps.
    // Show linechart stimuli smaller than before (~40% reduction).
    const linechartMaxWidthVw = 43.2 * scaleValue;
    const linechartMaxHeightVh = 49.2 * scaleValue;
    rowEl.innerHTML = `
      <div class="linechart-stimulus-column">
        <div class="linechart-wrapper" style="
          display: flex;
          align-items: center;
          justify-content: center;
        ">
          <img
            id="heatmap-image"
            alt="linechart stimulus"
            style="max-width: ${linechartMaxWidthVw}vw; max-height: ${linechartMaxHeightVh}vh; object-fit: contain; display: block;"
          />
        </div>
      </div>
    `;
  } else {
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
  }

  const heatmapEl = rowEl.querySelector('#heatmap-image');
  const legendEl = rowEl.querySelector('#legend-image');

  let heatmapReady = false;
  let legendReady = false;
  let shown = false;

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
    if (heatmapReady && legendReady && rowEl && !shown) {
      shown = true;
      if (trial?.type !== 'linechart') {
        applyLegendSizing();
      }
      rowEl.style.opacity = '1';
      startTimer();
      if (typeof onDisplayed === 'function') onDisplayed();
    }
  }

  heatmapEl.onload = () => {
    heatmapReady = true;
    maybeShow();
  };
  if (legendEl) {
    legendEl.onload = () => {
      legendReady = true;
      maybeShow();
    };
  } else {
    legendReady = true;
  }

  heatmapEl.src = trial.heatmapSrc;
  if (legendEl && trial.legendSrc) {
    legendEl.src = trial.legendSrc;
  }
}
