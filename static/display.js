import { startTimer } from './utils.js';

let layoutCache = {
  attention: null,
  phoneScreen: null,
  experimentPanel: null
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
  wrapper.style.gap = '40px';

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
  wrapper.appendChild(experimentPanel);

  container.appendChild(wrapper);

  layoutCache = { attention, phoneScreen, experimentPanel };
  return layoutCache;
}

export function getPhoneScreen() {
  return layoutCache.phoneScreen;
}

export function displayBlankScreen({ duration, attention = 'dual', onDone }) {
  const { experimentPanel } = ensureLayout(attention);
  experimentPanel.innerHTML = '<div class="blank-panel"></div>';

  setTimeout(() => {
    if (typeof onDone === 'function') onDone();
  }, duration);
}

export function displayHeatmapTrial({ trial, scale = 1, attention = 'dual' }) {
  const { experimentPanel } = ensureLayout(attention);

  experimentPanel.innerHTML = `
    <p id="controls-instruction" style="font-size: 18px; text-align: center; width: 100%; margin-bottom: 10px;">
      Which side shows greater values? Respond with the left or right arrow key.
    </p>
    <div style="
      display: flex;
      flex-direction: row;
      gap: 0px;
      align-items: center;
      justify-content: center;
      max-width: 90%;
      max-height: 90%;
      width: 100%;
    ">
      <div style="
        display: flex;
        align-items: center;
        justify-content: center;
      ">
        <img
          src="${trial.heatmapSrc}"
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
          src="${trial.legendSrc}"
          alt="legend"
          class="legend-image"
        />
        <div class="legend-label legend-label-bottom">${trial.legendLabelBottom}</div>
      </div>
    </div>
  `;

  startTimer();
}
