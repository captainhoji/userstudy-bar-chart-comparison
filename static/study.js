import { showInstructionsOverlay, hideInstructionsOverlay } from './instructions.js';
import { buildHeatmapTrials, buildPracticeTrialsRandom } from './heatmapTrials.js';
import { configureTrialState, loadTrial, handleArrowKeyPress } from './trialLogic.js';
import { addKeyHandlers } from './events.js';
import { createPhoneTask, PHONE_LIKE_SENDERS } from './phoneTask.js';
import { savePracticeSummary } from './trialManager.js';
import { getPhoneScreen } from './display.js';

let config = {
  participantId: null,
  attention: 'dual',
  trials: [],
  practiceTrials: [],
  realTrials: [],
  trialCounter: 0
};

const phoneTask = createPhoneTask();

export async function initializeStudy(participantId, attention) {
  config.participantId = participantId || localStorage.getItem("participantId");
  config.attention = attention || localStorage.getItem("attention") || "dual";
  config.trials = buildHeatmapTrials();
  config.practiceTrials = buildPracticeTrialsRandom(20);
  config.realTrials = config.trials;
  config.trialCounter = 0;

  const exampleImages = [
    "/static/stimuli/ex_darkUp_greaterUp.png",
    "/static/stimuli/ex_darkUp_fewerUp.png",
    "/static/stimuli/ex_lightUp_greaterUp.png",
    "/static/stimuli/ex_lightUp_fewerUp.png"
  ];

  const exampleGrid = exampleImages
    .map((src) => `<img src="${src}" alt="example heatmap" class="instruction-example-image">`)
    .join("");


  const attentionLine = config.attention === 'dual'
    ? `You will also see a phone screen on the left. Press the spacebar to "like" messages from ${PHONE_LIKE_SENDERS.join(' and ')}.
       Please keep your attention split between the heatmap task and the phone task, and try to be as accurate as possible on both.<br>`
    : '';

  const instructionsHTML = `
    <p>
      You will see many heatmaps. Each map shows data measured at different locations on the planet,
      where different animals are visible different amounts at different times of day.
      Below are two examples of such heatmaps.
    </p>
    <div class="instruction-example-grid">
      ${exampleGrid}
    </div>
    <p>
      This experiment begins with 20 practice trials, followed by ${config.realTrials.length} real trials.<br>
      In each trial, a heatmap and its legend will appear on the right side.<br>
      Your task is to indicate which side shows greater values. Respond with the left or right arrow key.<br><br>
      ${attentionLine}
      Press the spacebar to start the practice trials.
    </p>
  `;

  document.getElementById("instruction-text").innerHTML = instructionsHTML;
  showInstructionsOverlay();
  addKeyHandlers(startTrials);
}

function startTrials() {
  hideInstructionsOverlay();
  configureTrialState(config, handleNext);
  addKeyHandlers(null, handleArrowKeyPress);
  config.trialCounter = 0;
  config.currentBlock = 'practice';
  config.trials = config.practiceTrials;
  config.practiceCorrects = 0;
  config.practiceTotal = 0;
  phoneTask.resetStats();
  config.onPhoneScreenReady = () => {
    if (config.attention !== 'dual') return;
    const phoneScreen = getPhoneScreen();
    if (phoneScreen) phoneTask.attach(phoneScreen);
  };
  if (config.attention === 'dual') phoneTask.start();
  loadTrial();
}

function handleNext() {
  config.trialCounter++;
  const isLastTrial = config.trialCounter >= config.trials.length;
  const needsBreak = !isLastTrial && config.trialCounter % 20 === 0;

  if (isLastTrial) {
    if (config.currentBlock === 'practice') {
      if (config.attention === 'dual') phoneTask.pause();
      const practiceAccuracy = config.practiceTotal === 0 ? null : config.practiceCorrects / config.practiceTotal;
      const phoneStats = phoneTask.getStats();
      const practiceAccuracyPhone = config.attention === 'dual' ? phoneStats.accuracy : 1;
      const participantId = config.participantId || localStorage.getItem("participantId");
      if (participantId) {
        savePracticeSummary({
          participantId,
          practiceAccuracy,
          practiceAccuracyPhone
        });
      }
      const transitionHTML = `
        <p>
          This is the end of the practice trials.<br><br>
          Press the spacebar to start the real trials.
        </p>
      `;
      document.getElementById("instruction-text").innerHTML = transitionHTML;
      showInstructionsOverlay();
      addKeyHandlers(() => {
        hideInstructionsOverlay();
        config.currentBlock = 'real';
        config.trials = config.realTrials;
        config.trialCounter = 0;
        phoneTask.resetStats();
        if (config.attention === 'dual') phoneTask.start();
        loadTrial();
      });
    } else {
      if (config.attention === 'dual') phoneTask.pause();
      window.location.href = `/thank_you`;
    }
  } else if (needsBreak) {
    if (config.attention === 'dual') phoneTask.pause();
    const breakHTML = `
      <p>
        Break time. Please take a short break.<br><br>
        Press the spacebar to continue.
      </p>
    `;
    document.getElementById("instruction-text").innerHTML = breakHTML;
    showInstructionsOverlay();
    addKeyHandlers(() => {
      hideInstructionsOverlay();
      if (config.attention === 'dual') phoneTask.start();
      loadTrial();
    });
  } else {
    loadTrial();
  }
}
