// Handles logic handling of each trial, within-block
import { displayCharts, displayCrosshair, highlightDarkestBars } from './display.js';
import { stopTimer } from './utils.js';
import { saveResponseToServer } from './trialManager.js';
import { hideInstructionsOverlay } from './instructions.js';
import { addKeyHandlers } from './events.js';

let config = null;
let trialData = null;
let correctAnswer = null;
let onNext = null;
let isChartDisplayed = false;

export function configureTrialState(state, nextCallback) {
  config = state;
  onNext = nextCallback;
}

export function loadTrial() {
  hideInstructionsOverlay();

  if (config.isEasyPractice) {
    trialData = config.practiceEasy[config.trialCounter];
    console.log(`loading easy practice trial ${config.trialCounter + 1}`);
  } else {
    trialData = config.stimuli[config.blockCounter][config.trialCounter];
    console.log(`loading ${config.isPractice ? 'practice' : 'real'} trial ${config.trialCounter + 1} of block ${config.blockCounter + 1}`);
    console.log(`number: ` + config.numbers[config.blockCounter][config.trialCounter]);
  }

  correctAnswer = {
    compare_height: trialData[4],
    compare_index: trialData[3],
    compare_length: trialData[2]
  }[config.task];

  displayCrosshair(500, () => {
    displayCharts({
      data: trialData,
      task: config.task,
      correctAnswer,
      layout: config.current.layout,
      orientation: config.current.orientation,
      label: config.current.label,
      scale: localStorage.getItem("scale") || 1
    });
    addKeyHandlers(null, handleArrowKeyPress); // Re-add arrow key handler
    isChartDisplayed = true;
  });
}

export function handleArrowKeyPress(event) {
  if (!isChartDisplayed) return;

  const layout = config.current.layout;
  const key = event.key;
  let response = null;

  if (layout === 'horizontal') {
    if (key === 'ArrowLeft') response = "1";
    if (key === 'ArrowRight') response = "2";
  } else {
    if (key === 'ArrowUp') response = "1";
    if (key === 'ArrowDown') response = "2";
  }

  if (response) handleResponse(response);
}

function handleResponse(response) {
  const duration = stopTimer();
  const isCorrect = response == correctAnswer;
  isChartDisplayed = false;

  if (config.isEasyPractice) {
    highlightDarkestBars();

    const explanationContainer = document.getElementById('controls-instruction');
    const answer = {
      compare_height: trialData[4],
      compare_index: trialData[3],
      compare_length: trialData[2]
    }[config.task];

    const direction1 = config.current.layout === "horizontal" ? "left" : "top";
    const direction2 = config.current.layout === "horizontal" ? "right" : "bottom";
    const correctDirection = answer === 1 ? direction1 : direction2;
    const incorrectDirection = answer === 1 ? direction2 : direction1;

    let explanation = `The answer is the <b>${correctDirection}</b> chart because its darkest bar `;
    if (config.task === "compare_height") {
      if (config.current.orientation == "vertical") {
        explanation += `reaches higher. `;
      } else {
        explanation += `reaches farther to the right. `;
      }
    } else if (config.task === "compare_index") {
      if (config.current.orientation == "vertical") {
        explanation += `is positioned farther to the right side in its chart. `;
      } else {
        explanation += `is positioned higher in its chart. `;
      }
    } else if (config.task === "compare_length") {
      explanation += `is longer. `;
    }
    explanation += '<br>Please press the <b>spacebar</b> for the next trial.';

    const fontColor = isCorrect ? "green" : "red";
    explanation = `<b><font color="${fontColor}">${isCorrect ? "Correct" : "Incorrect"}!</font></b><br>` + explanation;

    explanationContainer.innerHTML = explanation;

    const spaceHandler = (event) => {
      if (event.code !== 'Space') return;
      onNext(isCorrect);
      document.removeEventListener("keydown", spaceHandler);
    };
    document.addEventListener("keydown", spaceHandler);
  } else {
    const feedbackOverlay = document.getElementById('feedback-overlay');
    feedbackOverlay.textContent = isCorrect ? "Correct" : "Incorrect";
    feedbackOverlay.style.color = isCorrect ? "green" : "red";
    feedbackOverlay.style.display = "flex";

    setTimeout(() => {
      feedbackOverlay.style.display = "none";

      if (!config.isPractice && config.participantId) {
        const now = new Date();
        saveResponseToServer({
          participantId: config.participantId,
          task: config.task,
          response,
          correct: isCorrect ? 1 : 0,
          trialNumber: config.trialCounter,
          timeWhen: now,
          layout: config.current.layout,
          orientation: config.current.orientation,
          label: config.current.label,
          stimuliNumber: config.numbers[config.blockCounter][config.trialCounter],
          duration
        });
      }

      if (typeof onNext === 'function') {
        onNext(isCorrect);
      }
    }, 300);
  }
}
