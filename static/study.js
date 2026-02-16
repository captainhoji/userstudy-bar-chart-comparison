import { showInstructionsOverlay, hideInstructionsOverlay } from './instructions.js';
import { buildHeatmapTrials, buildPracticeTrialsRandom } from './heatmapTrials.js';
import { configureTrialState, loadTrial, handleArrowKeyPress } from './trialLogic.js';
import { addKeyHandlers, addSingleKeyHandler } from './events.js';
import { createPhoneTask } from './phoneTask.js';
import { savePracticeSummary, savePhoneSummary, flushResponseQueue } from './trialManager.js';
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


  const colormapInstructions = `
    ${config.attention === 'dual'
      ? `<p><b>This experiment has two tasks for you to do at the same time, a “colormaps” task and a “phone messages” task.</b><br>
      On this screen, we will explain instructions for the colormaps task, and on the next screen we will explain the phone messages task.</p>`
      : ``}
    <p>
      You will see colormaps representing the amount of animal sightings on a distant planet.
      The x-axis represents time of day (early on the left, late on the right), and the y-axis represents type of animal.
      Each map has a legend that uses the labels “greater” and “fewer”.<br>
      <b>Your task</b> is to indicate whether there are more animals early (left) or late (right) in the day.
      Respond with the <b>left or right arrow key</b>.
    </p>
    <div class="instruction-example-grid">
      ${exampleGrid}
    </div>
    <p>
      The four examples above (left to right) have answers: <b>Right, Left, Right, Left</b>.<br>
      Note that the legend and labels change, so please check the legend on <b>every trial</b>
      to know whether darker colors mean greater or fewer values.<br><br>
      If your response is incorrect, <b>“Incorrect”</b> will briefly appear in red above the colormap.<br>
      You will also be notified of your accuracy periodically.<br><br>
      ${config.attention === 'dual' ? 'Press the spacebar to continue to phone message instructions.' : 'Please press the spacebar when you are ready to begin.'}
    </p>
  `;

  const phoneInstructions = `
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
      If you like a pet-related message in time, the message turns <b>light green</b>.<br>
      If you like a message that is not about pets, the message turns <b>dark red</b>.<br><br>
      Please press the spacebar when you are ready to begin.
    </p>
  `;

  const practiceStartInstructions = `
    <p>
      Next, you will complete <b>20 practice trials</b> before the real trials begin.<br>
      This is to help you get familiar with the tasks and response keys.
    </p>
    <p>
      Please press the spacebar to begin the practice trials.
    </p>
  `;

  const instructionPages = config.attention === 'dual'
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
  if (config.attention === 'dual') {
    phoneTask.setForcePetOnNextMessage(true);
    phoneTask.start();
  }
  loadTrial();
}

async function handleNext() {
  config.trialCounter++;
  const isLastTrial = config.trialCounter >= config.trials.length;
  const needsBreak = !isLastTrial && config.trialCounter % 20 === 0;

  if (isLastTrial) {
    if (config.currentBlock === 'practice') {
      await flushResponseQueue({ timeoutMs: 12000 });
      if (config.attention === 'dual') phoneTask.pause();
      const practiceAccuracy = config.practiceTotal === 0 ? null : config.practiceCorrects / config.practiceTotal;
      const phoneStats = phoneTask.getStats();
      const practiceAccuracyPhone = config.attention === 'dual' ? phoneStats.accuracy : 1;
      const practicePhoneHit = config.attention === 'dual' ? phoneStats.hit : null;
      const practicePhoneMiss = config.attention === 'dual' ? phoneStats.miss : null;
      const practicePhoneFalseAlarm = config.attention === 'dual' ? phoneStats.falseAlarm : null;
      const practicePhoneCorrectRejection = config.attention === 'dual' ? phoneStats.correctRejection : null;
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
          Practice accuracy (colormap): <b>${practiceAccuracy !== null ? Math.round(practiceAccuracy * 100) : 0}%</b><br>
          ${config.attention === 'dual'
          ? `Practice accuracy (phone): <b>${practiceAccuracyPhone !== null ? Math.round(practiceAccuracyPhone * 100) : 0}%</b><br>`
          : ''}
        </p>
      `;
      const noHitWarning = (
        config.attention === 'dual' &&
        (phoneStats.hit || 0) === 0 &&
        (phoneStats.miss || 0) > 0
      )
        ? `
          <p style="color:#b00020;">
            You did not like any pet-related messages. If you ignore pet-related messages again, your friends will be angry.
            In the real trials, <strong>like pet-related messages by pressing the spacebar</strong>.
          </p>
        `
        : '';
      const transitionHTML = `
        <p>
          This is the end of the practice trials.<br><br>
          Press Enter when you are ready to start the real trials.
        </p>
        ${accuracyLine}
        ${noHitWarning}
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
        if (config.attention === 'dual') {
          phoneTask.setForcePetOnNextMessage(false);
          phoneTask.start();
        }
        loadTrial();
      });
    } else {
      await flushResponseQueue({ timeoutMs: 12000 });
      if (config.attention === 'dual') phoneTask.pause();
      if (config.attention === 'dual') {
        const phoneStats = phoneTask.getStats();
        const participantId = config.participantId || localStorage.getItem("participantId");
        if (participantId) {
          await savePhoneSummary({
            participantId,
            phoneHit: phoneStats.hit,
            phoneMiss: phoneStats.miss,
            phoneFalseAlarm: phoneStats.falseAlarm,
            phoneCorrectRejection: phoneStats.correctRejection
          });
        }
      }
      const pid = config.participantId || localStorage.getItem("participantId") || "";
      window.location.href = `/ishihara?participant_id=${encodeURIComponent(pid)}`;
    }
  } else if (needsBreak) {
    await flushResponseQueue({ timeoutMs: 12000 });
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
        Press Enter when you are ready to continue.
      </p>
      ${accuracyHTML}
    `;
    document.getElementById("instruction-text").innerHTML = breakHTML;
    showInstructionsOverlay();
    addSingleKeyHandler('Enter', () => {
      hideInstructionsOverlay();
      if (config.attention === 'dual') phoneTask.start();
      loadTrial();
    });
  } else {
    loadTrial();
  }
}
