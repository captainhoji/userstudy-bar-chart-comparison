// handles between-block logic 
import { getStudyInstructionsHTML, getTrialBlockInstructionsHTML, showInstructionsOverlay } from './instructions.js';
import { shuffle, startTimer, stopTimer } from './utils.js';
import { getPracticeData } from './trialManager.js';
import { configureTrialState, loadTrial, handleArrowKeyPress } from './trialLogic.js';
import { addKeyHandlers, removeKeyHandlers } from './events.js';

let config = {
  participantId: null,
  layout: [],
  label: [],
  task: [],
  orientation: [],
  stimuli: [],
  practiceEasy: [],
  numbers: [],
  blockCounter: 0,
  trialCounter: 0,
  current: {
    layout: 'horizontal',
    label: false,
    orientation: 'vertical',
    task: null
  },
  isPractice: true,
  isEasyPractice: true,
  consecutiveCorrects: 0,
  practiceCorrects: 0,
  stimuliBlock: [],
  blockLength: 0,
  answer: null,
  startTime: null
};

export async function initializeStudy(participantId, task) {
  config.participantId = participantId;
  config.task = task;

  const response = await fetch('/initialize_task', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ participant_id: participantId, task: task, message: "initialize" })
  });

  const data = await response.json();
  Object.assign(config, {
    task: data.task,
    label: data.label,
    layout: data.layout,
    orientation: data.orientation,
    stimuli: data.stimuli,
    numbers: data.numbers,
    blockLength: data.stimuli[0].length,
    blockCounter: 0
  });

  console.log(`task: ${config.task}`);

  const instructionsHTML = getStudyInstructionsHTML(config);
  document.getElementById("instruction-text").innerHTML = instructionsHTML;

  showInstructionsOverlay();
  addKeyHandlers(() => initializeTrialBlock(true, true));
}


function initializeTrialBlock(practice = true, easyPractice = false) {
  config.isPractice = practice;
  config.isEasyPractice = easyPractice;
  config.trialCounter = 0;
  config.current.layout = config.layout[config.blockCounter];
  config.current.label = config.label[config.blockCounter];
  config.current.orientation = config.orientation[config.blockCounter];
  config.current.task = config.task[config.blockCounter];

  const titleContainer = document.getElementById('section-title');
  titleContainer.innerHTML = `Instructions: Section ${config.blockCounter + 1}`;
  const instructionText = getTrialBlockInstructionsHTML(config);
  document.getElementById('instruction-text').innerHTML = instructionText;
  showInstructionsOverlay();

  if (easyPractice) {
    getPracticeData(config.current.task, 'easy').then(practiceTrials => {
      config.practiceEasy = practiceTrials;
      config.consecutiveCorrects = 0;
      config.blockLength = 30;
    });
  } else if (practice) {
    getPracticeData(config.current.task, 'hard').then(practiceTrials => {
      config.stimuliBlock = practiceTrials;
      config.blockLength = 8;
      config.practiceCorrects = 0;
    });
  } else {
    config.stimuliBlock = config.stimuli[config.blockCounter];
    config.blockLength = config.stimuliBlock.length;
  }

  const spaceHandler = (event) => {
    if (event.code !== 'Space') return;
    document.removeEventListener("keydown", spaceHandler);
    configureTrialState(config, handleNext);
    addKeyHandlers(loadTrial, handleArrowKeyPress);
    loadTrial();
  };
  document.addEventListener("keydown", spaceHandler);
}

function handleNext(isCorrect) {
  config.trialCounter++;

  const isEasy = config.isEasyPractice;
  const isPractice = config.isPractice;
  const isLastTrial = config.trialCounter >= config.blockLength;

  if (isEasy) {
    config.consecutiveCorrects = isCorrect ? config.consecutiveCorrects + 1 : 0;
    if (isLastTrial) {
      const participantId = config.participantId || localStorage.getItem("participantId");
      fetch('/save_practiceFail', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          participant_id: participantId,
          task: config.current.task
        })
      });
    }
    if (config.consecutiveCorrects >= 5 || isLastTrial) {
      config.isEasyPractice = false;
      initializeTrialBlock(true, false);
    } else {
      loadTrial();
    }
  } else if (isPractice) {
    if (isCorrect) config.practiceCorrects++;
    if (isLastTrial) {
      initializeTrialBlock(false, false);
    } else {
      loadTrial();
    }
  } else {
    if (isLastTrial) {
      config.blockCounter++;
      if (config.blockCounter === config.stimuli.length) {
        // window.location.href = `/follow_up?participant_id=${config.participantId}`;
        window.location.href = `/thank_you`;
      } else {
        initializeTrialBlock(true, true);
      }
    } else {
      loadTrial();
    }
  }
}