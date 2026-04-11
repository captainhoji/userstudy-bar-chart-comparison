import { showInstructionsOverlay, hideInstructionsOverlay } from './instructions.js';
import {
  buildHeatmapTrials,
  buildPracticeTrialsRandom,
  buildBalancedHeatmapTrials,
  buildLinechartTrials,
  buildLinechartPracticeTrialsRandom
} from './heatmapTrials.js';
import { buildBarChartTrials, buildBarChartPracticeTrialsRandom } from './barChartTrials.js';
import { configureTrialState, loadTrial, handleArrowKeyPress } from './trialLogic.js';
import { addKeyHandlers, addSingleKeyHandler } from './events.js';
import { createPhoneTask } from './phoneTask.js';
import { savePracticeSummary, savePhoneSummary, flushResponseQueue } from './trialManager.js';
import { getPhoneScreen } from './display.js';
import { shuffle } from './utils.js';

let config = {
  participantId: null,
  attention: 'dual',
  attentionMode: 'dual',
  attentionSequence: [],
  currentAttention: 'dual',
  trials: [],
  practiceSingleTrials: [],
  practiceDualTrials: [],
  practiceTrials: [],
  practiceSwitchTrials: [],
  realTrials: [],
  trialCounter: 0,
  pendingRealTrialCounter: null,
  realPhoneTotals: { hit: 0, miss: 0, falseAlarm: 0, correctRejection: 0 },
  exposureMode: 'self-paced',
  constantExposureMs: 1750,
  interTrialMinMs: 500,
  interTrialMaxMs: 1000,
  blockSize: 20,
  practiceTrialCount: 20,
  skipPractice: false,
  stimuliMode: 'colormap',
  taskSequence: 'ts'
};

const phoneTask = createPhoneTask();

const MIXED_SEQUENCES = {
  sdsd: ['single', 'dual', 'single', 'dual'],
  dsds: ['dual', 'single', 'dual', 'single']
};

function taskModeLabel(attention) {
  return attention === 'dual' ? 'dual-task' : 'single-task';
}

function taskModeInstruction(attention) {
  const stimuliNoun = config.stimuliMode === 'linechart' ? 'line-chart task' : 'colormap task';
  if (config.stimuliMode === 'barchart') {
    return attention === 'dual'
      ? 'both the bar-chart task and the phone message task'
      : 'only the bar-chart task';
  }
  return attention === 'dual'
    ? `both the ${stimuliNoun} and the phone message task`
    : `only the ${stimuliNoun}`;
}

function normalizeTaskSequence(value) {
  const code = (value || '').toString().trim().toLowerCase();
  if (['ts', 'st', 'tt', 'ss'].includes(code)) return code;
  return 'ts';
}

function taskNameFromLetter(letter) {
  return letter === 's' ? 'shortest' : 'tallest';
}

function addPhoneStats(acc, delta) {
  const a = acc || {};
  const d = delta || {};
  return {
    hit: Number(a.hit || 0) + Number(d.hit || 0),
    miss: Number(a.miss || 0) + Number(d.miss || 0),
    falseAlarm: Number(a.falseAlarm || 0) + Number(d.falseAlarm || 0),
    correctRejection: Number(a.correctRejection || 0) + Number(d.correctRejection || 0)
  };
}

function getBlockPhoneStats() {
  const s = phoneTask.getStats() || {};
  return {
    total: Number(s.total || 0),
    correct: Number(s.correct || 0),
    hit: Number(s.hit || 0),
    miss: Number(s.miss || 0),
    falseAlarm: Number(s.falseAlarm || 0),
    correctRejection: Number(s.correctRejection || 0),
    accuracy: Number(s.total || 0) > 0 ? Number(s.correct || 0) / Number(s.total || 1) : null
  };
}

function cloneTrials(trials) {
  return trials.map((trial) => ({ ...trial }));
}

function resetRealBlockFeedbackCounters() {
  // Break feedback should reflect only the block that just finished, not the
  // cumulative totals across the whole experiment.
  config.realCorrects = 0;
  config.realTotal = 0;
  config.realMisses = 0;
}

function buildLowTaskAccuracyWarning(accuracy) {
  if (accuracy === null || accuracy >= 0.75) return '';

  if (config.stimuliMode === 'linechart') {
    return `
      <p style="color:#b00020;">
        Your accuracy on the line-chart task is low. Please focus on whether values are higher at early or late.
      </p>
    `;
  }

  if (config.stimuliMode === 'barchart') {
    return `
      <p style="color:#b00020;">
        Your accuracy on the bar-chart task is low. Please compare both charts carefully and choose the side with the <b>${taskNameFromLetter(config.currentBarPracticeTask || config.taskSequence[0])}</b> bar.
      </p>
    `;
  }

  return `
    <p style="color:#b00020;">
      Your accuracy on the colormap task is low. Please <b>read the legend</b> and select the <b>side of the colormap that shows greater values</b>.
    </p>
  `;
}

function buildMixedRealTrials(sequence, stimuliMode = 'colormap') {
  // Mixed mode needs 80 real trials split into 4 blocks of 20.
  // We reuse the same 40 base stimuli once for single-task blocks and once for dual-task blocks.
  const base40 = shuffle(buildBalancedHeatmapTrials(0, 5));
  const single40 = cloneTrials(base40);
  const dual40 = cloneTrials(base40);
  let singleIndex = 0;
  let dualIndex = 0;
  const trials = [];

  sequence.forEach((attentionInBlock) => {
    if (attentionInBlock === 'single') {
      trials.push(...cloneTrials(single40.slice(singleIndex, singleIndex + 20)));
      singleIndex += 20;
    } else {
      trials.push(...cloneTrials(dual40.slice(dualIndex, dualIndex + 20)));
      dualIndex += 20;
    }
  });

  return trials;
}

async function buildMixedRealTrialsAsync(sequence, stimuliMode = 'colormap') {
  if (stimuliMode === 'linechart' || stimuliMode === 'barchart') {
    const base80 = shuffle(stimuliMode === 'linechart' ? await buildLinechartTrials() : await buildBarChartTrials());
    // Reuse the same 40 logical stimuli twice in mixed mode by splitting the 80
    // linechart statement-trials into two 40-trial banks.
    const single40 = cloneTrials(base80.slice(0, 40));
    const dual40 = cloneTrials(base80.slice(40, 80));
    let singleIndex = 0;
    let dualIndex = 0;
    const trials = [];

    sequence.forEach((attentionInBlock) => {
      if (attentionInBlock === 'single') {
        trials.push(...cloneTrials(single40.slice(singleIndex, singleIndex + 20)));
        singleIndex += 20;
      } else {
        trials.push(...cloneTrials(dual40.slice(dualIndex, dualIndex + 20)));
        dualIndex += 20;
      }
    });
    return trials;
  }
  return buildMixedRealTrials(sequence, stimuliMode);
}

function normalizeAttentionInput(value) {
  const raw = (value || '').toString().trim().toLowerCase();
  if (raw === 'single' || raw === 'dual') return raw;
  if (raw === 'sdsd' || raw === 'mixed-sdsd' || raw === 'single-dual-single-dual' || raw === 'single_dual_single_dual') return 'sdsd';
  if (raw === 'dsds' || raw === 'mixed-dsds' || raw === 'dual-single-dual-single' || raw === 'dual_single_dual_single') return 'dsds';
  return 'dual';
}

export async function initializeStudy(participantId, attention, exposureMode, skipPractice, stimuli, taskSequenceArg) {
  config.participantId = participantId || localStorage.getItem("participantId");
  const attentionNormalized = normalizeAttentionInput(attention || localStorage.getItem("attention") || "dual");
  if (attentionNormalized === 'sdsd' || attentionNormalized === 'dsds') {
    config.attentionMode = 'mixed';
    config.attentionSequence = MIXED_SEQUENCES[attentionNormalized].slice();
    config.attention = config.attentionSequence[0];
  } else {
    config.attentionMode = attentionNormalized;
    config.attentionSequence = [];
    config.attention = attentionNormalized;
  }
  config.currentAttention = config.attentionMode === 'single' ? 'single' : 'dual';
  config.exposureMode = (exposureMode === 'constant-time') ? 'constant-time' : 'self-paced';
  config.skipPractice = !!skipPractice;
  config.stimuliMode = (stimuli === 'linechart' || stimuli === 'barchart') ? stimuli : 'colormap';
  config.taskSequence = normalizeTaskSequence(taskSequenceArg || localStorage.getItem("taskSequence") || "ts");
  config.currentBarPracticeTask = config.taskSequence[0];
  config.blockSize = config.stimuliMode === 'barchart'
    ? 24
    : (config.stimuliMode === 'linechart' && config.attentionMode !== 'mixed' ? 8 : 20);
  config.practiceTrialCount = config.stimuliMode === 'linechart'
    ? 8
    : (config.stimuliMode === 'barchart' ? 12 : 20);
  // In bar-chart mode, show each phone message 500ms shorter.
  // Default phone message visibility is 3000ms, so barchart uses 2500ms.
  phoneTask.setMessageVisibleMs(
    config.stimuliMode === 'barchart' ? 2700 : 3000
  );
  config.trials = [];
  if (config.attentionMode === 'mixed') {
    config.practiceSingleTrials = config.stimuliMode === 'linechart'
      ? shuffle(await buildLinechartPracticeTrialsRandom(10))
      : config.stimuliMode === 'barchart'
        ? shuffle(await buildBarChartPracticeTrialsRandom(10, config.taskSequence[0]))
        : shuffle(buildPracticeTrialsRandom(10));
    config.practiceDualTrials = config.stimuliMode === 'linechart'
      ? shuffle(await buildLinechartPracticeTrialsRandom(10))
      : config.stimuliMode === 'barchart'
        ? shuffle(await buildBarChartPracticeTrialsRandom(10, config.taskSequence[0]))
        : shuffle(buildPracticeTrialsRandom(10));
    config.practiceTrials = [];
    config.practiceSwitchTrials = [];
    config.realTrials = await buildMixedRealTrialsAsync(config.attentionSequence, config.stimuliMode);
  } else {
    config.trials = config.stimuliMode === 'linechart'
      ? shuffle(await buildLinechartTrials())
      : config.stimuliMode === 'barchart'
        // Bar-chart mode relies on ordered 48/48 halves by task sequence.
        ? await buildBarChartTrials(config.taskSequence)
        : shuffle(buildHeatmapTrials());
    config.practiceTrials = config.stimuliMode === 'linechart'
      ? shuffle(await buildLinechartPracticeTrialsRandom(config.practiceTrialCount))
      : config.stimuliMode === 'barchart'
        ? shuffle(await buildBarChartPracticeTrialsRandom(config.practiceTrialCount, config.taskSequence[0]))
        : shuffle(buildPracticeTrialsRandom(20));
    config.practiceSwitchTrials = config.stimuliMode === 'barchart' && config.taskSequence[0] !== config.taskSequence[1]
      ? shuffle(await buildBarChartPracticeTrialsRandom(config.practiceTrialCount, config.taskSequence[1]))
      : [];
    config.practiceSingleTrials = [];
    config.practiceDualTrials = [];
    config.realTrials = config.trials;
  }
  config.trialCounter = 0;
  config.pendingRealTrialCounter = null;

  const taskName = config.stimuliMode === 'linechart' ? 'line chart' : config.stimuliMode === 'barchart' ? 'bar chart' : 'colormap';
  const firstBarTask = taskNameFromLetter(config.taskSequence[0]);
  const secondBarTask = taskNameFromLetter(config.taskSequence[1]);
  const exampleImages = (config.stimuliMode === 'linechart' || config.stimuliMode === 'barchart')
    ? [
      {
        // Use practice-pool stimuli for instruction examples.
        src: config.stimuliMode === 'barchart'
          ? "/static/stimuli/barcharts/barchart_20_same.png"
          : "/static/stimuli/linecharts/example1.jpg",
        title: "Example 1",
        details: config.stimuliMode === 'barchart'
          // Match the generated example image metadata exactly.
          ? "The tallest bar is on the <b>right</b><br>The shortest bar is on the <b>left</b>."
          : "The statement is <b>true</b>, so press the <b>Right</b> arrow key."
      },
      {
        src: config.stimuliMode === 'barchart'
          ? "/static/stimuli/barcharts/barchart_21_double.png"
          : "/static/stimuli/linecharts/example2.jpg",
        title: "Example 2",
        details: config.stimuliMode === 'barchart'
          ? "The tallest bar is on the <b>right</b><br>The shortest bar is on the <b>right</b>."
          : "The statement is <b>false</b>, so press the <b>Left</b> arrow key."
      },
      {
        src: config.stimuliMode === 'barchart'
          ? "/static/stimuli/barcharts/barchart_32_random.png"
          : "/static/stimuli/linecharts/example3.jpg",
        title: "Example 3",
        details: config.stimuliMode === 'barchart'
          ? "The tallest bar is on the <b>right</b><br>The shortest bar is on the <b>right</b>."
          : "The statement is <b>true</b>, so press the <b>Right</b> arrow key."
      },
      {
        src: config.stimuliMode === 'barchart'
          ? "/static/stimuli/barcharts/barchart_34_same.png"
          : "/static/stimuli/linecharts/example4.jpg",
        title: "Example 4",
        details: config.stimuliMode === 'barchart'
          ? "The tallest bar is on the <b>left</b><br>The shortest bar is on the <b>left</b>."
          : "The statement is <b>false</b>, so press the <b>Left</b> arrow key."
      }
    ]
    : [
      {
        src: "/static/stimuli/ex_darkUp_greaterUp.png",
        title: "Example 1",
        details: "There are more animals late in the day, so the answer is <b>RIGHT</b>."
      },
      {
        src: "/static/stimuli/ex_darkUp_fewerUp.png",
        title: "Example 2",
        details: "There are more animals early in the day, so the answer is <b>LEFT</b>."
      },
      {
        src: "/static/stimuli/ex_lightUp_greaterUp.png",
        title: "Example 3",
        details: "There are more animals late in the day, so the answer is <b>RIGHT</b>."
      },
      {
        src: "/static/stimuli/ex_lightUp_fewerUp.png",
        title: "Example 4",
        details: "There are more animals early in the day, so the answer is <b>LEFT</b>."
      }
    ];

  const exampleGrid = exampleImages
    .map((item) => `
      <div class="instruction-example-card">
        <img src="${item.src}" alt="example stimulus" class="instruction-example-image">
        <div class="instruction-example-caption">
          <div class="instruction-example-title">${item.title}</div>
          <div class="instruction-example-details">${item.details}</div>
        </div>
      </div>
    `)
    .join("");

  const hasPhoneTask = config.attentionMode === 'dual' || config.attentionMode === 'mixed';

  const colormapInstructions = `
    ${config.attentionMode === 'mixed'
      ? `<p>This experiment includes 4 blocks of trials. In all blocks, you will be asked to perform the ${taskName} task described here.<br><\p>`
      : hasPhoneTask
        ? `<p>You will be asked to perform <b>two tasks at the same time</b>: a <i>${taskName}</i> task and a <i>phone message</i> task.<br>
      On this screen, we will give instructions for the <i>${taskName}</i> task, and on the next screen we will explain the <i>phone message</i> task.</p><br>`
        : ``}
    <p>
      ${config.stimuliMode === 'linechart' || config.stimuliMode === 'barchart'
      ? config.stimuliMode === 'barchart'
        ? `You will see two bar charts side by side on each trial.<br>
      In the first half of the experiment, you will be asked to find which chart has the <b>${firstBarTask}</b> bar.<br>
      In the second half of the experiment, you will be asked to find which chart has the <b>${secondBarTask}</b> bar.<br>
      <b>Your task</b> is to choose the correct side.<br>
      Please respond with the <b>left or right arrow key</b>.`
        : `In each trial, you will see a line chart. The x-axis has two time points, and the y-axis represents a value.<br>
      Each chart includes a legend that maps shapes to categories.<br>
      A statement will appear above each chart.<br> <b>Your task</b> is to judge whether the statement is true or false for that chart.<br>
      Press the <b>right arrow key</b> if the statement is <b>True</b> and the <b>left arrow key</b> if the statement is <b>False</b>.`
      : `You will see colormaps representing the amount of animal sightings on a distant planet called Sparl.
      The x-axis represents time of day, and the y-axis represents type of animal.<br>
      Each colormap has a <b>legend</b> that uses the labels “greater” and “fewer”.<br>
      <b>Your task</b> is to indicate whether there are more animals early (left) or late (right) in the day.<br>
      Please respond with the <b>left or right arrow key</b>.`}
    </p>
    <div class="instruction-example-grid">
      ${exampleGrid}
    </div>
    ${config.exposureMode === 'constant-time'
      ? `<p>
          Each ${taskName} stimulus is shown for <b>a brief time and then disappears</b>.
          Please respond while the stimulus is visible.
        </p>`
      : ``}
    <p>
      ${config.stimuliMode === 'linechart' || config.stimuliMode === 'barchart'
      ? config.stimuliMode === 'barchart'
        ? 'Please read the question and compare both bar charts carefully on every trial before responding.<br>'
        : 'Please read both the statement and the line chart carefully on every trial before responding.<br>'
      : 'Please <b>check the legend on every trial</b> to know which color means greater.<br>'}
    </p>
    <p>
      ${config.exposureMode !== 'constant-time'
      ? `If your response is incorrect, the text <b style="color: #ff001f">“INCORRECT”</b> will be displayed for 1 second.<br>`
      : `If your response is correct, a bright green checkmark (<b style="color: #B3FFCA">✓</b>) will be displayed.<br>
      If your response is incorrect, a dark red X (<b style="color: #ff001f">✕</b>) will be displayed.<br>
      If the stimulus disappears before you respond, "<b style="color: #ff001f">Too slow</b>" will be displayed.<br>`}
      You will be notified of your accuracy periodically.<br><br>
      ${config.attentionMode === 'mixed'
      ? 'Please press the spacebar to begin practice for single-task blocks.'
      : hasPhoneTask
        ? 'Please press the spacebar to continue to the next instructions.'
        : 'Please press the spacebar when you are ready to begin.'}
    </p>
  `;

  const phoneInstructions = `
    ${config.attentionMode === 'mixed'
      ? `<p>In some of the blocks, you will also be asked to perform the phone message task, <i>while</i> doing the ${taskName} task.<br>`
      : hasPhoneTask
        ? `<p>You will be asked to perform the <i>phone message</i> task, <b>while</b> doing the <i>${taskName}</i> task.<br></p>`
        : ``}
    <p>
      On the left side of the screen, you will see a phone showing a group chat.
      Imagine you are in a group chat with four friends.<br>
      Each friend has a pet: a <strong>dog</strong>, <strong>cat</strong>,
      <strong>parrot</strong>, or <strong>goldfish</strong>.<br>
      Every few seconds, a new message will appear in the chat.<br>
      Each message will stay on the screen briefly and then disappear.
    </p>
    <p>
      Your friends really love their pets. When they send a message about their pet, they expect you to “like” it. <br>
      Otherwise, they will get mad at you and send you an angry face (😡).<br>
      <strong>Your task:</strong>
    </p>
      <ul>
        <li>If a message is about a pet, <b>press the spacebar to like</b> the message.</li>
        <li>If a message is <span class="phone-demo-not">NOT</span> about a pet, do not press the spacebar.</li>
      </ul>
    <div class="instruction-phone-row">
      <div class="phone-demo">
        <div class="phone-demo-header">Example: <span class="phone-demo-not">NOT</span> about a pet</div>
        <div class="phone-demo-message phone-demo-message-pet">
          <div class="phone-demo-sender">Jordan</div>
          <div class="phone-demo-text">Are we still meeting at seven tonight?</div>
        </div>
      </div>
      <div class="phone-demo">
        <div class="phone-demo-header">Example: about a pet</div>
        <div class="phone-demo-message phone-demo-message-pet">
          <div class="phone-demo-sender">Alex</div>
          <div class="phone-demo-text">My dog kept barking at the door again.</div>
        </div>
      </div>
    </div>
    <p>
      Please respond as quickly and accurately as possible.
    </p>
    <p>
      If you like a pet-related message in time, the message turns <b>light green</b> <span style="display: inline-block; width: 12px; height: 12px; background-color: #B3FFCA; border: 1px solid black; vertical-align: middle;"></span>.<br>
      If you like a message that is not about pets, the message turns <b>dark red</b> <span style="display: inline-block; width: 12px; height: 12px; background-color: #B91F2D; border: 1px solid black; vertical-align: middle;"></span>.<br><br>
      ${config.attentionMode === 'mixed'
      ? 'Press the spacebar to begin practice for dual-task blocks.'
      : 'Please press the spacebar when you are ready to begin.'}
    </p>
  `;
  config.phoneInstructionsHtml = phoneInstructions;

  const practiceStartInstructions = `
    <p>
      Next, you will complete <b>${config.practiceTrialCount} practice trials</b> before the real trials begin.<br>
      This is to help you get familiar with the tasks and response keys.
    </p>
    <p>
      Please press the spacebar to begin the practice trials.
    </p>
  `;

  const instructionPages = config.attentionMode === 'mixed'
    ? [colormapInstructions]
    : hasPhoneTask
      ? [colormapInstructions, phoneInstructions, practiceStartInstructions]
      : [colormapInstructions, practiceStartInstructions];

  let pageIndex = 0;
  const advanceInstruction = () => {
    pageIndex += 1;
    if (pageIndex >= instructionPages.length) {
      startTrials();
    } else {
      showPage();
    }
  };

  const showPage = () => {
    const sectionTitleEl = document.getElementById("section-title");
    if (sectionTitleEl) {
      const isPracticeStartPage = config.attentionMode !== 'mixed' && pageIndex === instructionPages.length - 1;
      const isPhonePage = hasPhoneTask && pageIndex === 1;
      if (isPracticeStartPage) {
        sectionTitleEl.textContent = "Practice Trials";
      } else {
        const mainTaskTitle = config.stimuliMode === 'linechart'
          ? "Instructions: line chart task"
          : config.stimuliMode === 'barchart'
            ? "Instructions: bar chart task"
            : "Instructions: colormap task";
        sectionTitleEl.textContent = isPhonePage
          ? "Instructions: phone message task"
          : mainTaskTitle;
      }
    }
    document.getElementById("instruction-text").innerHTML = instructionPages[pageIndex];
    showInstructionsOverlay();
    addKeyHandlers(advanceInstruction);
  };

  showPage();
}

function startTrials() {
  hideInstructionsOverlay();
  configureTrialState(config, handleNext);
  addKeyHandlers(null, handleArrowKeyPress);
  config.trialCounter = 0;
  config.practiceCorrects = 0;
  config.practiceTotal = 0;
  config.practiceMisses = 0;
  config.practiceSingleCorrects = 0;
  config.practiceSingleTotal = 0;
  config.practiceSingleMisses = 0;
  config.practiceDualCorrects = 0;
  config.practiceDualTotal = 0;
  config.practiceDualMisses = 0;
  config.practiceSwitchCorrects = 0;
  config.practiceSwitchTotal = 0;
  config.practiceSwitchMisses = 0;
  config.realCorrects = 0;
  config.realTotal = 0;
  config.realMisses = 0;
  config.resolveAttention = (blockName, trialIndex) => {
    if (blockName === 'practice-single') return 'single';
    if (blockName === 'practice-dual') return 'dual';
    if (blockName === 'practice-switch') {
      return config.attentionMode === 'single' ? 'single' : 'dual';
    }
    if (blockName === 'practice') {
      return config.attentionMode === 'single' ? 'single' : 'dual';
    }
    if (config.attentionMode === 'mixed') {
      const blockIndex = Math.floor(Number(trialIndex) / Number(config.blockSize || 20));
      const seqIndex = Math.max(0, Math.min(config.attentionSequence.length - 1, blockIndex));
      return config.attentionSequence[seqIndex];
    }
    return config.attention;
  };
  phoneTask.resetStats();
  config.pendingRealTrialCounter = null;
  config.onPhoneScreenReady = () => {
    if (config.currentAttention !== 'dual') return;
    const phoneScreen = getPhoneScreen();
    if (phoneScreen) phoneTask.attach(phoneScreen);
  };

  if (config.attentionMode === 'mixed') {
    config.currentBlock = 'practice-single';
    config.trials = config.practiceSingleTrials;
    config.currentAttention = 'single';
    phoneTask.pause();
  } else {
    config.currentBlock = 'practice';
    config.trials = config.practiceTrials;
    if (config.resolveAttention(config.currentBlock, config.trialCounter) === 'dual') {
      phoneTask.setForcePetOnNextMessage(true);
      phoneTask.start();
    }
  }

  if (config.skipPractice) {
    config.currentBlock = 'real';
    config.trials = config.realTrials;
    config.trialCounter = 0;
    config.realCorrects = 0;
    config.realTotal = 0;
    config.realPhoneTotals = { hit: 0, miss: 0, falseAlarm: 0, correctRejection: 0 };
    phoneTask.resetStats();
    const firstRealAttention = config.resolveAttention(config.currentBlock, config.trialCounter);
    config.currentAttention = firstRealAttention;
    if (firstRealAttention === 'dual') {
      phoneTask.setForcePetOnNextMessage(false);
      phoneTask.start();
    } else {
      phoneTask.pause();
    }
  }

  loadTrial();
}

async function handleNext() {
  config.trialCounter++;
  const runningPhoneStats = getBlockPhoneStats();
  const runningCumulativePhoneStats = addPhoneStats(config.realPhoneTotals, runningPhoneStats);
  console.log(
    `Phone stats after trial ${config.trialCounter} (${config.currentBlock}):`,
    runningCumulativePhoneStats
  );
  const isLastTrial = config.trialCounter >= config.trials.length;
  const blockSize = Number(config.blockSize || 20);
  const needsBreak = config.currentBlock === 'real' && !isLastTrial && config.trialCounter % blockSize === 0;

  if (isLastTrial) {
    if (config.currentBlock === 'practice-single') {
      await flushResponseQueue({ timeoutMs: 12000 });
      phoneTask.pause();
      const practiceAccuracy = config.practiceSingleTotal === 0 ? null : config.practiceSingleCorrects / config.practiceSingleTotal;
      const lowColormapWarning = buildLowTaskAccuracyWarning(practiceAccuracy);
      const betweenPracticeHTML = `
        <p>
          This is the end of single-task practice.<br>
          Practice accuracy (${config.stimuliMode === 'linechart' ? 'line chart' : 'colormap'}): <b>${practiceAccuracy !== null ? Math.round(practiceAccuracy * 100) : 0}%</b>
        </p>
        ${lowColormapWarning}
        <p>
          Press Enter to read the next instruction.
        </p>
      `;
      const sectionTitleEl = document.getElementById("section-title");
      if (sectionTitleEl) sectionTitleEl.textContent = "Single-task practice";
      document.getElementById("instruction-text").innerHTML = betweenPracticeHTML;
      showInstructionsOverlay();
      addSingleKeyHandler('Enter', () => {
        const phoneTitleEl = document.getElementById("section-title");
        if (phoneTitleEl) phoneTitleEl.textContent = "Instructions: phone message task";
        document.getElementById("instruction-text").innerHTML = config.phoneInstructionsHtml;
        showInstructionsOverlay();
        addKeyHandlers(() => {
          hideInstructionsOverlay();
          config.currentBlock = 'practice-dual';
          config.trials = config.practiceDualTrials;
          config.trialCounter = 0;
          config.practiceDualCorrects = 0;
          config.practiceDualTotal = 0;
          config.practiceDualMisses = 0;
          phoneTask.resetStats();
          config.currentAttention = 'dual';
          phoneTask.setForcePetOnNextMessage(true);
          phoneTask.start();
          loadTrial();
        });
      });
    } else if (config.currentBlock === 'practice-dual') {
      await flushResponseQueue({ timeoutMs: 12000 });
      phoneTask.pause();
      const practiceAccuracy = config.practiceDualTotal === 0 ? null : config.practiceDualCorrects / config.practiceDualTotal;
      const phoneStats = phoneTask.getStats();
      const practiceAccuracyPhone = phoneStats.accuracy;
      const practicePhoneHit = phoneStats.hit;
      const practicePhoneMiss = phoneStats.miss;
      const practicePhoneFalseAlarm = phoneStats.falseAlarm;
      const practicePhoneCorrectRejection = phoneStats.correctRejection;
      const participantId = config.participantId || localStorage.getItem("participantId");
      if (participantId) {
        savePracticeSummary({
          participantId,
          practiceAccuracy,
          practiceAccuracyPhone,
          practicePhoneHit,
          practicePhoneMiss,
          practicePhoneFalseAlarm,
          practicePhoneCorrectRejection
        });
      }

      const accuracyLine = `
        <p>
          Practice accuracy (${config.stimuliMode === 'linechart' ? 'line chart' : 'colormap'}): <b>${practiceAccuracy !== null ? Math.round(practiceAccuracy * 100) : 0}%</b><br>
          ${config.attentionMode !== 'single'
          ? `Practice accuracy (phone): <b>${practiceAccuracyPhone !== null ? Math.round(practiceAccuracyPhone * 100) : 0}%</b><br>`
          : ''}
        </p>
      `;
      const noHitWarning = (
        config.attentionMode !== 'single' &&
        (phoneStats.hit || 0) === 0 &&
        (phoneStats.miss || 0) > 0
      )
        ? `
          <p style="color:#b00020;">
            You did not like any pet-related messages. If you ignore pet-related messages again, your friends will be angry.<br>
            Please <strong>like pet-related messages by pressing the spacebar</strong>.
          </p>
        `
        : '';
      const lowColormapWarning = buildLowTaskAccuracyWarning(practiceAccuracy);
      const transitionHTML = `
        <p>
          This is the end of practice.
        </p>
        ${accuracyLine}
        ${lowColormapWarning}
        ${noHitWarning}
        <p>
          The next block will start the real trials.<br>
          The next block is ${taskModeLabel(config.resolveAttention('real', 0))}.<br>
          Be ready to do ${taskModeInstruction(config.resolveAttention('real', 0))}.<br><br>
          Press Enter to start the next block.
        </p>
      `;
      const sectionTitleEl2 = document.getElementById("section-title");
      if (sectionTitleEl2) sectionTitleEl2.textContent = "Dual-task practice";
      document.getElementById("instruction-text").innerHTML = transitionHTML;
      showInstructionsOverlay();
      addSingleKeyHandler('Enter', () => {
        hideInstructionsOverlay();
        config.currentBlock = 'real';
        config.trials = config.realTrials;
        config.trialCounter = 0;
        phoneTask.resetStats();
        config.realCorrects = 0;
        config.realTotal = 0;
        config.realMisses = 0;
        config.realPhoneTotals = { hit: 0, miss: 0, falseAlarm: 0, correctRejection: 0 };
        const firstRealAttention = config.resolveAttention(config.currentBlock, config.trialCounter);
        config.currentAttention = firstRealAttention;
        if (firstRealAttention === 'dual') {
          phoneTask.setForcePetOnNextMessage(false);
          phoneTask.start();
        } else {
          phoneTask.pause();
        }
        loadTrial();
      });
    } else if (config.currentBlock === 'practice') {
      await flushResponseQueue({ timeoutMs: 12000 });
      if (config.currentAttention === 'dual') phoneTask.pause();
      const practiceAccuracy = config.practiceTotal === 0 ? null : config.practiceCorrects / config.practiceTotal;
      const phoneStats = phoneTask.getStats();
      const practiceAccuracyPhone = config.attentionMode === 'single' ? 1 : phoneStats.accuracy;
      const practicePhoneHit = config.attentionMode === 'single' ? null : phoneStats.hit;
      const practicePhoneMiss = config.attentionMode === 'single' ? null : phoneStats.miss;
      const practicePhoneFalseAlarm = config.attentionMode === 'single' ? null : phoneStats.falseAlarm;
      const practicePhoneCorrectRejection = config.attentionMode === 'single' ? null : phoneStats.correctRejection;
      const participantId = config.participantId || localStorage.getItem("participantId");
      if (participantId) {
        savePracticeSummary({
          participantId,
          practiceAccuracy,
          practiceAccuracyPhone,
          practicePhoneHit,
          practicePhoneMiss,
          practicePhoneFalseAlarm,
          practicePhoneCorrectRejection
        });
      }
      const accuracyLine = `
        <p>
          Practice accuracy (${config.stimuliMode === 'linechart' ? 'line chart' : 'colormap'}): <b>${practiceAccuracy !== null ? Math.round(practiceAccuracy * 100) : 0}%</b><br>
          ${config.attentionMode !== 'single'
          ? `Practice accuracy (phone): <b>${practiceAccuracyPhone !== null ? Math.round(practiceAccuracyPhone * 100) : 0}%</b><br>`
          : ''}
        </p>
      `;
      const noHitWarning = (
        config.attentionMode !== 'single' &&
        (phoneStats.hit || 0) === 0 &&
        (phoneStats.miss || 0) > 0
      )
        ? `
          <p style="color:#b00020;">
            You did not like any pet-related messages. If you ignore pet-related messages again, your friends will be angry.<br>
            Please <strong>like pet-related messages by pressing the spacebar</strong>.
          </p>
        `
        : '';
      const lowColormapWarning = buildLowTaskAccuracyWarning(practiceAccuracy);
      const transitionHTML = `
        <p>
          ${config.attentionMode !== 'mixed'
          ? 'This is the end of practice.'
          : `This is the end of ${taskModeLabel(config.currentAttention)} practice.`}
        </p>
        ${accuracyLine}
        ${lowColormapWarning}
        ${noHitWarning}
        <p>
          ${config.attentionMode === 'mixed'
          ? `The next block is ${taskModeLabel(config.resolveAttention('real', 0))}.<br>
          Be ready to do ${taskModeInstruction(config.resolveAttention('real', 0))}.<br><br>
          Press Enter to start the next block.`
          : 'Press Enter to start the real trials.'}
        </p>
      `;
      document.getElementById("instruction-text").innerHTML = transitionHTML;
      showInstructionsOverlay();
      addSingleKeyHandler('Enter', () => {
        hideInstructionsOverlay();
        config.currentBlock = 'real';
        config.trials = config.realTrials;
        config.trialCounter = 0;
        phoneTask.resetStats();
        config.realCorrects = 0;
        config.realTotal = 0;
        config.realMisses = 0;
        config.realPhoneTotals = { hit: 0, miss: 0, falseAlarm: 0, correctRejection: 0 };
        const firstRealAttention = config.resolveAttention(config.currentBlock, config.trialCounter);
        config.currentAttention = firstRealAttention;
        if (firstRealAttention === 'dual') {
          phoneTask.setForcePetOnNextMessage(false);
          phoneTask.start();
        } else {
          phoneTask.pause();
        }
        loadTrial();
      });
    } else if (config.currentBlock === 'practice-switch') {
      await flushResponseQueue({ timeoutMs: 12000 });
      if (config.currentAttention === 'dual') phoneTask.pause();
      const practiceAccuracy = config.practiceSwitchTotal === 0 ? null : config.practiceSwitchCorrects / config.practiceSwitchTotal;
      const phoneStats = phoneTask.getStats();
      const practiceAccuracyPhone = config.attentionMode === 'single' ? 1 : phoneStats.accuracy;
      const noHitWarning = (
        config.attentionMode !== 'single' &&
        (phoneStats.hit || 0) === 0 &&
        (phoneStats.miss || 0) > 0
      )
        ? `
          <p style="color:#b00020;">
            You did not like any pet-related messages. If you ignore pet-related messages again, your friends will be angry.<br>
            Please <strong>like pet-related messages by pressing the spacebar</strong>.
          </p>
        `
        : '';
      const lowColormapWarning = buildLowTaskAccuracyWarning(practiceAccuracy);
      const practiceLabel = config.stimuliMode === 'barchart' ? 'bar chart' : 'task';
      const taskLabel = taskNameFromLetter(config.taskSequence[1]);
      const transitionHTML = `
        <p>
          This is the end of practice for the <b>${taskLabel}</b> task.
        </p>
        <p>
          Practice accuracy (${practiceLabel}): <b>${practiceAccuracy !== null ? Math.round(practiceAccuracy * 100) : 0}%</b><br>
          ${config.attentionMode !== 'single'
          ? `Practice accuracy (phone): <b>${practiceAccuracyPhone !== null ? Math.round(practiceAccuracyPhone * 100) : 0}%</b><br>`
          : ''}
        </p>
        ${lowColormapWarning}
        ${noHitWarning}
        <p>
          Press Enter to start block 3.
        </p>
      `;
      const sectionTitleEl = document.getElementById("section-title");
      if (sectionTitleEl) sectionTitleEl.textContent = "Practice Trials";
      document.getElementById("instruction-text").innerHTML = transitionHTML;
      showInstructionsOverlay();
      addSingleKeyHandler('Enter', () => {
        hideInstructionsOverlay();
        config.currentBlock = 'real';
        config.trials = config.realTrials;
        config.trialCounter = Number(config.pendingRealTrialCounter || 0);
        config.pendingRealTrialCounter = null;
        phoneTask.resetStats();
        resetRealBlockFeedbackCounters();
        const resumedAttention = config.resolveAttention(config.currentBlock, config.trialCounter);
        config.currentAttention = resumedAttention;
        if (resumedAttention === 'dual') {
          phoneTask.setForcePetOnNextMessage(false);
          phoneTask.start();
        } else {
          phoneTask.pause();
        }
        loadTrial();
      });
    } else {
      await flushResponseQueue({ timeoutMs: 12000 });
      if (config.currentAttention === 'dual') phoneTask.pause();
      if (config.attentionMode !== 'single') {
        const finalBlockStats = getBlockPhoneStats();
        config.realPhoneTotals = addPhoneStats(config.realPhoneTotals, finalBlockStats);
        console.log('Final cumulative phone stats before save:', finalBlockStats, 'aggregated:', config.realPhoneTotals);
        const participantId = config.participantId || localStorage.getItem("participantId");
        if (participantId) {
          await savePhoneSummary({
            participantId,
            phoneHit: config.realPhoneTotals.hit,
            phoneMiss: config.realPhoneTotals.miss,
            phoneFalseAlarm: config.realPhoneTotals.falseAlarm,
            phoneCorrectRejection: config.realPhoneTotals.correctRejection
          });
        }
      }
      const pid = config.participantId || localStorage.getItem("participantId") || "";
      // if (config.attentionMode === 'mixed') {
      window.location.href = `/thank_you`;
      // } else {
      //   window.location.href = `/ishihara?participant_id=${encodeURIComponent(pid)}`;
      // }
    }
  } else if (needsBreak) {
    await flushResponseQueue({ timeoutMs: 12000 });
    if (config.currentAttention === 'dual') phoneTask.pause();
    const heatmapAccuracy = config.currentBlock === 'practice'
      ? (config.practiceTotal === 0 ? null : config.practiceCorrects / config.practiceTotal)
      : (config.realTotal === 0 ? null : config.realCorrects / config.realTotal);
    const blockPhoneStats = getBlockPhoneStats();
    const endedBlockNumber = Math.floor(config.trialCounter / blockSize);
    const endedAttention = config.currentBlock === 'real'
      ? config.resolveAttention('real', Math.max(0, (endedBlockNumber - 1) * blockSize))
      : config.currentAttention;
    const showPhoneAccuracy = config.attentionMode !== 'single' && endedAttention === 'dual';
    const phoneAccuracy = showPhoneAccuracy ? blockPhoneStats.accuracy : null;
    config.realPhoneTotals = addPhoneStats(config.realPhoneTotals, blockPhoneStats);
    phoneTask.resetStats();
    const nextAttention = config.resolveAttention(config.currentBlock, config.trialCounter);
    const nextBlockNumber = endedBlockNumber + 1;
    const barchartTaskShift = (
      config.stimuliMode === 'barchart' &&
      config.currentBlock === 'real' &&
      endedBlockNumber === 2 &&
      config.taskSequence[0] !== config.taskSequence[1] &&
      config.practiceSwitchTrials.length > 0 &&
      !config.skipPractice
    );
    const nextTaskLabel = taskNameFromLetter(config.taskSequence[1]);
    // Match the break-screen wording to the active stimulus type.
    const breakTaskLabel = config.stimuliMode === 'linechart'
      ? 'line chart'
      : config.stimuliMode === 'barchart'
        ? 'bar chart'
        : 'colormap';
    const missedLabel = config.stimuliMode === 'linechart'
      ? 'Missed line charts'
      : config.stimuliMode === 'barchart'
        ? 'Missed bar charts'
        : 'Missed colormaps';
    const accuracyHTML = `
      <p>
        Accuracy (${breakTaskLabel}): <b>${heatmapAccuracy !== null ? Math.round(heatmapAccuracy * 100) : 0}%</b><br>
        ${config.exposureMode === 'constant-time'
          ? `${missedLabel}: <b>${config.realMisses || 0}</b><br>`
          : ''}
        ${showPhoneAccuracy
        ? `Accuracy (phone): <b>${phoneAccuracy !== null ? Math.round(phoneAccuracy * 100) : 0}%</b><br>`
        : ''}
      </p>
    `;
    if (config.attentionMode === 'mixed' && config.currentBlock === 'real') {
      const sectionTitleEl = document.getElementById("section-title");
      if (sectionTitleEl) sectionTitleEl.textContent = `End of Block ${endedBlockNumber}`;
      const breakPageOneHTML = `
        <p>
          This is the end of block ${endedBlockNumber}.
        </p>
        ${accuracyHTML}
        <p>
          Press Enter to continue.
        </p>
      `;
      document.getElementById("instruction-text").innerHTML = breakPageOneHTML;
      showInstructionsOverlay();
      addSingleKeyHandler('Enter', () => {
        const sectionTitleEl2 = document.getElementById("section-title");
        if (sectionTitleEl2) sectionTitleEl2.textContent = `Start of Block ${nextBlockNumber}`;
        const breakPageTwoHTML = `
          <p>
            Now you will start block ${nextBlockNumber}.<br>
            Block ${nextBlockNumber} is ${taskModeLabel(nextAttention)}.<br>
            Please be ready to do ${taskModeInstruction(nextAttention)}.
          </p>
          <p>
            Press Enter to start block ${nextBlockNumber}.
          </p>
        `;
        document.getElementById("instruction-text").innerHTML = breakPageTwoHTML;
        showInstructionsOverlay();
        addSingleKeyHandler('Enter', () => {
          hideInstructionsOverlay();
          resetRealBlockFeedbackCounters();
          config.currentAttention = nextAttention;
          if (nextAttention === 'dual') {
            phoneTask.start();
          } else {
            phoneTask.pause();
          }
          loadTrial();
        });
      });
    } else {
      const sectionTitleEl = document.getElementById("section-title");
      if (sectionTitleEl) sectionTitleEl.textContent = `Break Time`;
      const breakHTML = `
        <p>Please take a short break.</p>
        ${accuracyHTML}
        <p>
          Press Enter to start the next block.
        </p>
      `;
      document.getElementById("instruction-text").innerHTML = breakHTML;
      showInstructionsOverlay();
      addSingleKeyHandler('Enter', () => {
        // In bar-chart mode, optionally insert a task-switch instruction between
        // block 2 and block 3 when the URL sequence requests a switch (ts/st).
        if (barchartTaskShift) {
          const sectionTitleEl2 = document.getElementById("section-title");
          if (sectionTitleEl2) sectionTitleEl2.textContent = "Task Update";
          document.getElementById("instruction-text").innerHTML = `
            <p>
              Now please find the <b>${nextTaskLabel}</b> bar instead of the previous task.
            </p>
            <p>
              You will complete <b>${config.practiceTrialCount} practice trials</b> for the new task before block 3 begins.
            </p>
            <p>
              Press Enter to start practice.
            </p>
          `;
          showInstructionsOverlay();
          addSingleKeyHandler('Enter', () => {
            hideInstructionsOverlay();
            // Pause the real timeline, insert practice for the new task, and
            // resume block 3 from this saved real-trial index afterward.
            config.pendingRealTrialCounter = config.trialCounter;
            config.currentBlock = 'practice-switch';
            config.currentBarPracticeTask = config.taskSequence[1];
            config.trials = config.practiceSwitchTrials;
            config.trialCounter = 0;
            config.practiceSwitchCorrects = 0;
            config.practiceSwitchTotal = 0;
            config.practiceSwitchMisses = 0;
            config.currentAttention = nextAttention;
            phoneTask.resetStats();
            if (nextAttention === 'dual') {
              phoneTask.setForcePetOnNextMessage(true);
              phoneTask.start();
            } else {
              phoneTask.pause();
            }
            loadTrial();
          });
          return;
        }
        hideInstructionsOverlay();
        resetRealBlockFeedbackCounters();
        config.currentAttention = nextAttention;
        if (nextAttention === 'dual') {
          phoneTask.start();
        } else {
          phoneTask.pause();
        }
        loadTrial();
      });
    }
  } else {
    loadTrial();
  }
}
