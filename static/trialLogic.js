// Handles logic handling of each trial, within-block
import { displayCharts, displayCrosshair, highlightBars } from './display.js';
import { stopTimer, isDualPhaseTask, splitDualPhaseTask } from './utils.js';
import { saveResponseToServer } from './trialManager.js';
import { hideInstructionsOverlay } from './instructions.js';
import { addKeyHandlers } from './events.js';
import { compareBars } from './trialUtils.js';

let config = null;
let trialData = null;
let correctAnswer = null;
let answerBrightness = null;
let answerLength = null;
let onNext = null;
let isChartDisplayed = false;

const BRIGHTNESS_RULES = {
  darkest: { index: 3},
  lightest: { index: 5},
  tallest: { index: 2},
  shortest: { index: 4}
};

const LENGTH_RULES = {
  darkest: { index: 2},
  lightest: { index: 4},
  tallest: { index: 3},
  shortest: { index: 5}
};


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

  if (isDualPhaseTask(config.current.task)) {
    const [firstTask, secondTask] = splitDualPhaseTask(config.current.task);
    correctAnswer = {
      darkest: {taller: trialData[2], shorter: 3-trialData[2]},
      lightest: {taller: trialData[4], shorter: 3-trialData[4]},
      tallest: {darker: trialData[2], lighter: 3-trialData[2]},
      shortest: {darker: trialData[4], lighter: 3-trialData[4]}
    }[firstTask][secondTask];

    const brightnessRule = BRIGHTNESS_RULES[firstTask];
    answerBrightness = brightnessRule && correctAnswer === trialData[brightnessRule.index] ? "darker" : "lighter";

    const lengthRule = LENGTH_RULES[firstTask];
    answerLength = lengthRule && correctAnswer === trialData[lengthRule.index] ? "taller" : "shorter";

  } else { // answerLength and answerBrightness for single-phase tasks
    correctAnswer = {
      tallest: trialData[2],
      shortest: trialData[3],
      darkest: trialData[4],
      lightest: trialData[5]
    }[config.current.task];
    [answerLength, answerBrightness] = compareBars(trialData[0], trialData[1], config.current.task);
  }
  // console.log("correct answer: ", correctAnswer);
  console.log(trialData);
  console.log("answer is ", answerLength, " and ", answerBrightness);

  displayCrosshair(500, () => {
    displayCharts({
      data: trialData,
      task: config.current.task,
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
    highlightBars();

    const explanationContainer = document.getElementById('controls-instruction');

    const direction1 = config.current.layout === "horizontal" ? "left" : "top";
    const direction2 = config.current.layout === "horizontal" ? "right" : "bottom";
    const correctDirection = correctAnswer === 1 ? direction1 : direction2;
    const incorrectDirection = correctAnswer === 1 ? direction2 : direction1;

    let explanation = `The answer is the <b>${correctDirection}</b> chart `;
    if (isDualPhaseTask(config.current.task)) {
      const [firstTask, secondTask] = splitDualPhaseTask(config.current.task);
      explanation += `because its ${firstTask} bar is ${secondTask}. `;
    } else {
      explanation += `because it has the ${config.current.task} bar. `;
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
          task: config.current.task,
          answerBrightness: answerBrightness,
          answerLength: answerLength,
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
