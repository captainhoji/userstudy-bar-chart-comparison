export function getStudyInstructionsHTML(config) {
  const { task, label, layout, orientation, blockLength } = config;

  let instructionText = `<p>This experiment consists of 4 sections.<br>
    Each section will include a few practice trials followed by ${blockLength} real trials.<br><br>
    On each trial, you will be presented with two bar charts and your task will be to choose one of them.`

  instructionText += `</strong> <br><br>Please press the spacebar to see the instructions for the first section.</p>`;

  return instructionText;
}

export function getTaskInstructionHTML(config) {
  const { task, orientation } = config;

  let instructionText = `Find the darkest bar in each chart and `;

  if (orientation === "vertical") {
    if (task === "compare_height") {
      instructionText += `identify which one reaches higher in its chart.`;
    } else if (task === "compare_index") {
      instructionText += `identify which one is positioned farther right in its chart.`;
    } else if (task === "compare_length") {
      instructionText += `identify which one is longer.`;
    }
  } else {
    if (task === "compare_height") {
      instructionText += `identify which one reaches farther right in its chart.`;
    } else if (task === "compare_index") {
      instructionText += `identify which one is positioned higher in its chart.`;
    } else if (task === "compare_length") {
      instructionText += `identify which one is longer.`;
    }
  }

  return instructionText;
}

export function getTrialBlockInstructionsHTML(config) {
  const {
    task,
    chartType,
    current: { layout, label, orientation },
    isPractice,
    isEasyPractice,
    blockCounter,
    blockLength,
    practiceCorrects
  } = config;

  let instructionText = "<p>";
  const layoutText = layout === 'horizontal' ? 'side by side' : 'one above the other';
  const directionText = layout === 'horizontal' ? 'left or right' : 'up or down';

  if (isEasyPractice) {
    instructionText += `You will be presented with two charts ${layoutText}. `;
    instructionText += `Each chart contains colored bars. Your task is to answer the question: <strong>`
    instructionText += `Look at the darkest bars in each chart. `

    if (orientation === "vertical") {
      if (task === "compare_height") {
        instructionText += `Which one reaches higher in its chart?`;
      } else if (task === "compare_index") {
        instructionText += `Which one is positioned farther right in its chart?`;
      } else if (task === "compare_length") {
        instructionText += `Which one is longer?`;
      }
    } else {
      if (task === "compare_height") {
        instructionText += `Which one reaches farther right in its chart?`;
      } else if (task === "compare_index") {
        instructionText += `Which one is positioned higher in its chart?`;
      } else if (task === "compare_length") {
        instructionText += `Which one is longer?`;
      }
    }

    instructionText += `</strong> <br> To respond, please press the ${directionText} arrow key. <br><br>`;

    if (task === "compare_height") {
      if (layout === "horizontal") {
        if (orientation === "horizontal") {
          instructionText += `In the example below, the darkest bar of the LEFT chart reaches farther right. So, you would press the LEFT ARROW KEY. `;
        } else {
          instructionText += `In the example below, the darkest bar of the LEFT chart reaches higher. So, you would press the LEFT ARROW KEY. `;
        }
      } else {
        if (orientation === "horizontal") {
          instructionText += `In the example below, the darkest bar of the TOP chart reaches farther right. So, you would press the UP ARROW KEY. `;
        } else {
          instructionText += `In the example below, the darkest bar of the TOP chart reaches higher, so you would press the UP ARROW KEY. `;
        }
      }
    } else if (task === "compare_index") {
      if (layout === "horizontal") {
        if (orientation === "horizontal") {
          instructionText += `In the example below, the darkest bar on the RIGHT chart is positioned higher in its chart. So, you would press the RIGHT ARROW KEY. `;
        } else {
          instructionText += `In the example below, the darkest bar on the LEFT chart is positioned farther right in its chart. So, you would press the LEFT ARROW KEY. `;
        }
      } else {
        if (orientation === "horizontal") {
          instructionText += `In the example below, the darkest bar on the BOTTOM chart is positioned higher in its chart. So, you would press the DOWN ARROW KEY. `;
        } else {
          instructionText += `In the example below, the darkest bar on the TOP chart is positioned farther right in its chart. So, you would press the UP ARROW KEY. `;
        }
      }
    } else if (task === "compare_length") {
      if (layout === "horizontal") {
        instructionText += `In the example below, the darkest bar on the RIGHT chart is longer. So, you would press the RIGHT ARROW KEY. `;
      } else {
        instructionText += `In the example below, the darkest bar on the BOTTOM chart is longer. So, you would press the DOWN ARROW KEY. `;
      }
    }

    instructionText += `<img src="static/img/${chartType}/${orientation}-${layout}-${task.replace(/^compare_/, "")}-blue.png" ${layout == "horizontal" ? "width" : "height"}="400px">`;

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
    instructionText += `Real Trials<br><br>`;
    instructionText += `You got ${practiceCorrects} out of ${blockLength} correct.<br><br>`;
    instructionText += `<b>Accuracy</b> is just as important as speed!<br><br>`;
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
