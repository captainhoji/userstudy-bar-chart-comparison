import { displayBlankScreen, displayHeatmapTrial } from './display.js';
import { stopTimer } from './utils.js';
import { saveResponseToServer } from './trialManager.js';
import { hideInstructionsOverlay } from './instructions.js';
import { addKeyHandlers } from './events.js';

let config = null;
let trialData = null;
let onNext = null;
let isStimulusDisplayed = false;

export function configureTrialState(state, nextCallback) {
  config = state;
  onNext = nextCallback;
}

export function loadTrial() {
  hideInstructionsOverlay();

  trialData = config.trials[config.trialCounter];
  if (!trialData) return;

  displayBlankScreen({
    duration: 500,
    attention: config.attention,
    onDone: () => {
      if (typeof config.onPhoneScreenReady === 'function') {
        config.onPhoneScreenReady();
      }
    displayHeatmapTrial({
      trial: trialData,
      scale: localStorage.getItem("scale") || 1,
      attention: config.attention
    });
    if (typeof config.onPhoneScreenReady === 'function') {
      config.onPhoneScreenReady();
    }
    addKeyHandlers(null, handleArrowKeyPress);
    isStimulusDisplayed = true;
    }
  });
}

export function handleArrowKeyPress(event) {
  if (!isStimulusDisplayed) return;

  const key = event.key;
  let response = null;

  if (key === 'ArrowLeft') response = "left";
  if (key === 'ArrowRight') response = "right";

  if (response) handleResponse(response);
}

function handleResponse(response) {
  const duration = stopTimer();
  isStimulusDisplayed = false;

  const darkerSide = trialData.heatmapCondition === 'left-dark' ? 'left' : 'right';
  const correctSide = trialData.greaterIsDark ? darkerSide : (darkerSide === 'left' ? 'right' : 'left');
  const isCorrect = response === correctSide;
  console.log(`trial ${config.trialCounter + 1} correctness: ${isCorrect ? 'correct' : 'incorrect'}`);

  if (!isCorrect) {
    const audio = new Audio('/static/stimuli/t1000Hz.wav');
    audio.play().catch(() => {});
  }

  if (config.currentBlock === 'practice') {
    config.practiceTotal = (config.practiceTotal || 0) + 1;
    if (isCorrect) config.practiceCorrects = (config.practiceCorrects || 0) + 1;
  } else {
    const participantId = config.participantId || localStorage.getItem("participantId");
    if (participantId) {
      const now = new Date();
      saveResponseToServer({
        participantId,
        response,
        correct: isCorrect ? 1 : 0,
        trialNumber: config.trialCounter,
        timeWhen: now,
        stimuliNumber: trialData.heatmapId,
        duration,
        responseTime: duration,
        heatmapCondition: trialData.heatmapCondition,
        legendCondition: trialData.legendCondition,
        labelCondition: trialData.labelCondition,
        attention: config.attention
      });
    }
  }

  if (typeof onNext === 'function') {
    onNext();
  }
}
