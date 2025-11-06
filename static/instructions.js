export function getStudyInstructionsHTML(config) {
  const { blockLength } = config;

  let instructionText = `<p>This experiment consists of 4 sections.<br>
    Each section will include a few practice trials followed by ${blockLength} real trials.<br><br>
    On each trial, you will be presented with two bar charts and your task will be to choose one of them.`

  instructionText += `</strong> <br><br>Please press the spacebar to see the instructions for the first section.</p>`;

  return instructionText;
}

export function getTaskInstructionHTML(config) {
  const { firstTask, secondTask } = config;

  let instructionText = `Find the ${firstTask} bar in each chart and `;
  if (secondTask === 'taller' || secondTask === 'shorter') {
    instructionText += ` identify which one is ${secondTask}.`;
  } else {
    instructionText += ` identify which one reaches ${secondTask}.`;
  }
  return instructionText;
}

export function getTrialBlockInstructionsHTML(config) {
  const {
    current: { layout, label, orientation, firstTask, secondTask },
    isPractice,
    isEasyPractice,
    blockCounter,
    blockLength,
    practiceCorrects
  } = config;

  let instructionText = "<p>";
  const layoutText = layout === 'horizontal' ? 'side by side' : 'one above the other';
  const directionText = layout === 'horizontal' ? 'left or right' : 'up or down';
  const answerDirection = (secondTask === 'taller' || (firstTask === 'lightest' && secondTask === 'higher') || (firstTask === 'darkest' && secondTask === 'lower')) ? 'RIGHT' : 'LEFT';

  if (isEasyPractice) {
    instructionText += `You will be presented with two charts ${layoutText}. `;
    instructionText += `Each chart contains colored bars. Your task is to answer the question: <strong>`;
    instructionText += `Look at the ${firstTask} bars in each chart. `;
    instructionText += `Which one is ${secondTask}?`;


    instructionText += `</strong> <br> To respond, please press the ${directionText} arrow key. <br><br>`;
    if (secondTask === 'taller' || secondTask === 'shorter') {
      instructionText += `In the example below, the ${firstTask} bar on the ${answerDirection} chart is ${secondTask}. `;
    } else {
      instructionText += `In the example below, the ${firstTask} bar on the ${answerDirection} chart reaches ${secondTask}. `;
    }
    instructionText += `So, you would press the ${answerDirection} ARROW KEY. `
    instructionText += `<img src="static/img/bar-${firstTask}-${secondTask}.png" ${layout == "horizontal" ? "width" : "height"}="400px">`;

    instructionText += 'Please indicate your answer as ACCURATELY and as QUICKLY as possible. <br/>';
    instructionText += 'You will be asked to complete practice trials. You must get <b>5 correct in a row</b> to proceed.';
    instructionText += '<br>Please make sure you understand the instructions. Please press the spacebar to start the practice trials.</p>';

  } else if (isPractice) {
    instructionText += `Practice Trials<br><br>`;
    instructionText += `Now you will complete 8 harder practice trials that are more like the real trials. `;
    instructionText += `You do not need to press the spacebar in this section. The trials will advance automatically. `;

    instructionText += '<br/><br/> Please indicate your answer as ACCURATELY and as QUICKLY as possible.<br/><br/>';
    instructionText += '<h3>Press the spacebar to start the 8 practice trials.</h3>';

  } else {
    instructionText += `You got ${practiceCorrects} out of ${blockLength} correct.<br><br>`;
    instructionText += `Remember that <b>Accuracy</b> is just as important as speed!<br><br>`;
    instructionText += `Now you will complete ${blockLength} real trials. <br>`;
    instructionText += 'You do not need to press the spacebar in this section. The trials will advance automatically.';
    instructionText += '<h3>Press the spacebar to start the real trials.</h3>';
  }

  return instructionText;
}

export function showInstructionsOverlay() {
  const overlay = document.getElementById("instruction-overlay");
  if (overlay) overlay.style.display = "flex";
}

export function hideInstructionsOverlay() {
  const overlay = document.getElementById("instruction-overlay");
  if (overlay) overlay.style.display = "none";
}
