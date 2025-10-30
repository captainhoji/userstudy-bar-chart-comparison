// Handles logic handling of each trial, within-block
import { displayCharts, displayCrosshair, highlightDarkestBars } from './display.js';
import { stopTimer } from './utils.js';
import { saveResponseToServer } from './trialManager.js';
import { hideInstructionsOverlay } from './instructions.js';
import { addKeyHandlers } from './events.js';

let config = null;
let trialData = null;
let correctAnswer = null;
let answerBrightness = null;
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
  } else if (config.isPractice) { // LOOK HERE!!
    trialData = config.stimuliBlock[config.trialCounter]
    console.log(`loading practice trial ${config.trialCounter + 1} of block ${config.blockCounter + 1}`);
  } else {
    trialData = config.stimuliBlock[config.trialCounter];
    console.log(`loading real trial ${config.trialCounter + 1} of block ${config.blockCounter + 1}`);
  }

  correctAnswer = {
    darkest: {longer: trialData[2], shorter: 3-trialData[2]},
    lightest: {longer: trialData[4], shorter: 3-trialData[4]}
  }[config.current.firstTask][config.current.secondTask];

  if ((config.firstTask == 'darkest' && correctAnswer == trialData[3]) || 
    (config.firstTask == 'lightest' && correctAnswer == trialData[5])) {
    answerBrightness = 'darker';
  } else {
    answerBrightness = 'lighter';
  }

  displayCrosshair(500, () => {
    displayCharts({
      data: trialData,
      firstTask: config.current.firstTask,
      secondTask: config.current.secondTask,
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

    const direction1 = config.current.layout === "horizontal" ? "left" : "top";
    const direction2 = config.current.layout === "horizontal" ? "right" : "bottom";
    const correctDirection = correctAnswer === 1 ? direction1 : direction2;
    const incorrectDirection = correctAnswer === 1 ? direction2 : direction1;

    let explanation = `The answer is the <b>${correctDirection}</b> chart `;
    if (config.current.firstTask === "darkest") {
      explanation += `because its darkest bar `;
    } else {
      explanation += `because its lightest bar `;
    }
    if (config.current.secondTask === "longer") {
      explanation += `is longer. `;
    } else {
      explanation += `is shorter. `
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
          firstTask: config.current.firstTask,
          secondTask: config.current.secondTask,
          answerBrightness: answerBrightness,
          response,
          correct: isCorrect ? 1 : 0,
          trialNumber: config.trialCounter,
          timeWhen: now,
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
