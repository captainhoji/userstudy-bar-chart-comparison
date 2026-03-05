import { displayBlankScreen, displayHeatmapTrial } from './display.js';
import { stopTimer } from './utils.js';
import { saveResponseToServer } from './trialManager.js';
import { hideInstructionsOverlay } from './instructions.js';
import { addKeyHandlers } from './events.js';

let config = null;
let trialData = null;
let onNext = null;
let isStimulusDisplayed = false;
let constantExposureTimerId = null;
let trialStartTs = null;
const FEEDBACK_DURATION = 500;

export function configureTrialState(state, nextCallback) {
  config = state;
  onNext = nextCallback;
}

export function loadTrial() {
  hideInstructionsOverlay();

  trialData = config.trials[config.trialCounter];
  if (!trialData) return;
  if (typeof config.resolveAttention === 'function') {
    config.currentAttention = config.resolveAttention(config.currentBlock, config.trialCounter);
  } else {
    config.currentAttention = config.attention;
  }
  const itiMs = config.exposureMode === 'constant-time'
    ? randomInterTrialMs(config.interTrialMinMs || 500, config.interTrialMaxMs || 2000)
    : 500;

  displayBlankScreen({
    duration: itiMs,
    attention: config.currentAttention || config.attention,
    onDone: () => {
      if (typeof config.onPhoneScreenReady === 'function') config.onPhoneScreenReady();
      displayHeatmapTrial({
        trial: trialData,
        scale: localStorage.getItem("scale") || 1,
        attention: config.currentAttention || config.attention,
        onDisplayed: () => {
          addKeyHandlers(null, handleArrowKeyPress);
          isStimulusDisplayed = true;

          if (config.exposureMode === 'constant-time') {
            trialStartTs = performance.now();
            if (constantExposureTimerId) window.clearTimeout(constantExposureTimerId);
            constantExposureTimerId = window.setTimeout(() => {
              constantExposureTimerId = null;
              if (!isStimulusDisplayed) return;
              isStimulusDisplayed = false;
              handleTimeoutNoResponse();
            }, config.constantExposureMs || 1750);
          }
        }
      });
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

async function handleResponse(response) {
  if (config.exposureMode === 'constant-time') {
    if (!isStimulusDisplayed) return;
    isStimulusDisplayed = false;
    if (constantExposureTimerId) {
      window.clearTimeout(constantExposureTimerId);
      constantExposureTimerId = null;
    }
    const duration = Math.max(0, Math.round((performance.now() - (trialStartTs || performance.now()))));
    const darkerSide = trialData.heatmapCondition === 'left-dark' ? 'left' : 'right';
    const correctSide = trialData.greaterIsDark ? darkerSide : (darkerSide === 'left' ? 'right' : 'left');
    const isCorrect = response === correctSide;
    console.log(`trial ${config.trialCounter + 1} correctness: ${isCorrect ? 'correct' : 'incorrect'} (constant-time)`);
    const feedbackEl = document.getElementById('colormap-feedback');
    if (feedbackEl) {
      feedbackEl.innerHTML = isCorrect
        ? '<span class="colormap-feedback-mark colormap-feedback-correct">&#10003;</span>'
        : '<span class="colormap-feedback-mark colormap-feedback-incorrect">&#10005;</span>';
    }
    window.setTimeout(() => {
      completeTrial({
        response,
        duration,
        isCorrect
      });
    }, FEEDBACK_DURATION);
    return;
  }

  const duration = stopTimer();
  isStimulusDisplayed = false;

  const darkerSide = trialData.heatmapCondition === 'left-dark' ? 'left' : 'right';
  const correctSide = trialData.greaterIsDark ? darkerSide : (darkerSide === 'left' ? 'right' : 'left');
  const isCorrect = response === correctSide;
  console.log(`trial ${config.trialCounter + 1} correctness: ${isCorrect ? 'correct' : 'incorrect'}`);

  completeTrial({
    response,
    duration,
    isCorrect
  });
}

function handleTimeoutNoResponse() {
  completeTrial({
    response: 'none',
    duration: null,
    isCorrect: null,
    showTooSlowFeedback: true
  });
}

function completeTrial({ response, duration, isCorrect, showTooSlowFeedback = false }) {
  const didAnswer = response !== 'none';
  const feedbackEl = document.getElementById('colormap-feedback');

  if (config.currentBlock === 'practice-single') {
    config.practiceSingleTotal = (config.practiceSingleTotal || 0) + 1;
    if (!didAnswer) config.practiceSingleMisses = (config.practiceSingleMisses || 0) + 1;
    if (isCorrect) config.practiceSingleCorrects = (config.practiceSingleCorrects || 0) + 1;
  } else if (config.currentBlock === 'practice-dual') {
    config.practiceDualTotal = (config.practiceDualTotal || 0) + 1;
    if (!didAnswer) config.practiceDualMisses = (config.practiceDualMisses || 0) + 1;
    if (isCorrect) config.practiceDualCorrects = (config.practiceDualCorrects || 0) + 1;
  } else if (config.currentBlock === 'practice') {
    config.practiceTotal = (config.practiceTotal || 0) + 1;
    if (!didAnswer) config.practiceMisses = (config.practiceMisses || 0) + 1;
    if (isCorrect) config.practiceCorrects = (config.practiceCorrects || 0) + 1;
  } else {
    config.realTotal = (config.realTotal || 0) + 1;
    if (!didAnswer) config.realMisses = (config.realMisses || 0) + 1;
    if (isCorrect) config.realCorrects = (config.realCorrects || 0) + 1;
    const participantId = config.participantId || localStorage.getItem("participantId");
    if (participantId) {
      const now = new Date();
      saveResponseToServer({
        participantId,
        response,
        correct: didAnswer ? (isCorrect ? 1 : 0) : 0,
        trialNumber: config.trialCounter,
        timeWhen: now,
        stimuliNumber: trialData.heatmapId,
        responseTime: duration,
        heatmapCondition: trialData.heatmapCondition,
        legendCondition: trialData.legendCondition,
        labelCondition: trialData.labelCondition,
        attention: config.currentAttention || config.attention
      });
    }
  }

  if (config.exposureMode === 'constant-time') {
    const rowEl = document.querySelector('.colormap-row');
    if (rowEl) {
      rowEl.className = 'colormap-row colormap-placeholder';
      rowEl.style.opacity = '1';
      rowEl.innerHTML = '';
    }
    if (showTooSlowFeedback && feedbackEl) {
      feedbackEl.innerHTML = '<span class="colormap-feedback-too-slow">Timeout</span>';
      window.setTimeout(() => {
        feedbackEl.textContent = '';
        if (typeof onNext === 'function') onNext();
      }, FEEDBACK_DURATION);
    } else {
      if (feedbackEl) feedbackEl.textContent = '';
      if (typeof onNext === 'function') onNext();
    }
    return;
  }

  if (!isCorrect && didAnswer && feedbackEl) {
    feedbackEl.textContent = 'Incorrect';
    setTimeout(() => {
      const rowEl = document.querySelector('.colormap-row');
      if (rowEl) {
        rowEl.className = 'colormap-row colormap-placeholder';
        rowEl.style.opacity = '1';
        rowEl.innerHTML = '';
      }
      feedbackEl.textContent = '';
      if (typeof onNext === 'function') {
        onNext();
      }
    }, 1000);
  } else {
    if (typeof onNext === 'function') {
      onNext();
    }
  }
}

function randomInterTrialMs(minMs, maxMs) {
  const min = Number(minMs || 500);
  const max = Number(maxMs || 2000);
  return Math.round(min + Math.random() * Math.max(0, max - min));
}
