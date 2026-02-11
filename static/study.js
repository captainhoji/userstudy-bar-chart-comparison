import { showInstructionsOverlay, hideInstructionsOverlay } from './instructions.js';
import { buildHeatmapTrials, buildPracticeTrialsRandom } from './heatmapTrials.js';
import { configureTrialState, loadTrial, handleArrowKeyPress } from './trialLogic.js';
import { addKeyHandlers } from './events.js';
import { createPhoneTask } from './phoneTask.js';
import { savePracticeSummary } from './trialManager.js';
import { getPhoneScreen } from './display.js';
import { shuffle } from './utils.js';

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
  config.trials = shuffle(buildHeatmapTrials());
  config.practiceTrials = shuffle(buildPracticeTrialsRandom(20));
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
    ? `On the left side of the screen, you will see a phone showing a group chat.
      Imagine you are in a group chat with four friends. 
      Each friend has a pet: a <strong>dog</strong>, <strong>cat</strong>, <strong>parrot</strong>, or <strong>goldfish</strong>.
      Every few seconds, a new message will appear in the chat. Each message will stay on the screen briefly and then disappear.
      Your friends really love their pets. When they send a message about their pet, they expect you to “like” it, otherwise they might get mad at you!
      <strong>Your task:</strong>
      <ul>
        <li>If a message is about a pet, press the spacebar to like the message.</li>
        <li>If a message is not about a pet, do not press the spacebar.</li>
      </ul>
      <br>`
    : '';

  const onBothTasksLine = config.attention === 'dual'
    ? 'on both tasks'
    : '';

  const instructionsHTML = `
    <p>
      You will see colormaps representing the amount of animal sightings on a distant planet.
      The x-axis represents time of day (early on the left, late on the right), and the y-axis represents type of animal.
      Each map has a legend that uses the labels “greater” and “fewer”.<br>
      Your task is to indicate whether there are more animals early (left) or late (right) in the day.
      Respond with the <b>left or right arrow key</b>.<br>
    </p>
    <div class="instruction-example-grid">
      ${exampleGrid}
    </div>
    <p>
      The four examples above (left to right) have answers: <b>Right, Left, Right, Left</b>.<br>
      Note that the legend and labels change, so please check the legend on <b>every trial</b>
      to know whether darker colors mean greater or fewer values.<br><br>
      This experiment begins with 20 practice trials, followed by ${config.realTrials.length} real trials.<br>
      A tone will play when you make an error, and you will be notified of your accuracy periodically.<br><br>
      ${attentionLine}
      Please respond as quickly as possible ${onBothTasksLine} while maintaining accuracy. 
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
  config.realCorrects = 0;
  config.realTotal = 0;
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
      const accuracyLine = `
        <p>
          Practice accuracy (colormap): <b>${practiceAccuracy !== null ? Math.round(practiceAccuracy * 100) : 0}%</b><br>
          ${config.attention === 'dual'
          ? `Practice accuracy (phone): <b>${practiceAccuracyPhone !== null ? Math.round(practiceAccuracyPhone * 100) : 0}%</b><br>`
          : ''}
        </p>
      `;
      const transitionHTML = `
        <p>
          This is the end of the practice trials.<br><br>
          Press the spacebar to start the real trials.
        </p>
        ${accuracyLine}
      `;
      document.getElementById("instruction-text").innerHTML = transitionHTML;
      showInstructionsOverlay();
      addKeyHandlers(() => {
        hideInstructionsOverlay();
        config.currentBlock = 'real';
        config.trials = config.realTrials;
        config.trialCounter = 0;
        phoneTask.resetStats();
        config.realCorrects = 0;
        config.realTotal = 0;
        if (config.attention === 'dual') phoneTask.start();
        loadTrial();
      });
    } else {
      if (config.attention === 'dual') phoneTask.pause();
      window.location.href = `/thank_you`;
    }
  } else if (needsBreak) {
    if (config.attention === 'dual') phoneTask.pause();
    const heatmapAccuracy = config.currentBlock === 'practice'
      ? (config.practiceTotal === 0 ? null : config.practiceCorrects / config.practiceTotal)
      : (config.realTotal === 0 ? null : config.realCorrects / config.realTotal);
    const phoneStats = phoneTask.getStats();
    const phoneAccuracy = config.attention === 'dual' ? phoneStats.accuracy : null;
    const accuracyHTML = `
      <p>
        Accuracy (colormap): <b>${heatmapAccuracy !== null ? Math.round(heatmapAccuracy * 100) : 0}%</b><br>
        ${config.attention === 'dual'
        ? `Accuracy (phone): <b>${phoneAccuracy !== null ? Math.round(phoneAccuracy * 100) : 0}%</b><br>`
        : ''}
      </p>
    `;
    const breakHTML = `
      <p>
        Break time. Please take a short break.<br><br>
        Press the spacebar to continue.
      </p>
      ${accuracyHTML}
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
