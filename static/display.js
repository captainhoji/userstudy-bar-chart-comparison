import { drawBarChart } from './chart.js';
import { startTimer, isDualPhaseTask, splitDualPhaseTask } from './utils.js';
import { getTaskInstructionHTML } from './instructions.js';

let currentChartViews = [];
let currentChartConfig = null;

const secondArrowAngleMap = {
  horizontal: { horizontal: 270, vertical: 90 },
  vertical: { horizontal: 180, vertical: 0 }
};

export function displayCrosshair(duration, callback) {
  const container = document.getElementById('chart-container');
  container.style.display = 'flex';
  container.innerHTML = `
    <div id="crosshair" style="
      display: flex;
      justify-content: center;
      align-items: center;
      width: 100vw;
      height: 100vh;
      font-size: 50px;
      font-weight: bold;
      color: black;
      background-color: white;
    ">+</div>
  `;

  setTimeout(() => {
    container.innerHTML = "";
    if (callback) callback();
  }, duration);
}

export function displayCharts({ data, task, correctAnswer, layout, orientation, label = false, scale = 1 }) {
  currentChartConfig = { data, task, correctAnswer, layout, orientation, label, scale };
  const container = document.getElementById('chart-container');
  const layoutStyle = layout === 'horizontal' ? 'row' : 'column';

  container.innerHTML = `
    <div style="
      display: flex;
      flex-direction: column;
      justify-content: center;
      align-items: center;
      height: 100vh;
      width: 100vw;
    ">
      <p id="controls-instruction" style="font-size: 18px; text-align: center; width: 100%; margin-bottom: 20px;">
        ${getTaskInstructionHTML(currentChartConfig)}
        <br> Respond using the ${layout === "horizontal" ? "left/right" : "up/down"} arrow key
      </p>
      <div style="
        display: flex;
        flex-direction: ${layoutStyle};
        gap: ${layout === "horizontal" ? 100 : 50}px;
        align-items: center;
        justify-content: center;
        max-width: 90%;
        max-height: 90%;
        width: 100%;
      ">
        <div id="chart1" style="width: fit-content; height: fit-content; overflow: visible;"></div>
        <div id="chart2" style="width: fit-content; height: fit-content; overflow: visible;"></div>
      </div>
      <div id="explanation" style="position: absolute; top: 90%; font-size: 20px; text-align: center; max-width: 80%;"></div>
    </div>
  `;

  const isCorrectAnswerFirst = correctAnswer == 1 ? true : false;
  let redIndexes = null;
  if (isDualPhaseTask(currentChartConfig.task)) {
    const [firstTask, secondTask] = splitDualPhaseTask(currentChartConfig.task);
    redIndexes = (firstTask === "darkest" || firstTask === "tallest") ? data[6] : data[7];
  } else {
    switch (currentChartConfig.task) {
      case "tallest":
        redIndexes = [data[6]];
        break;
      case "shortest":
        redIndexes = [data[7]];
        break;
      case "darkest":
        redIndexes = [data[8]];
        break;
      case "lightest":
        redIndexes = [data[9]];
        break;
      default:
        throw new Error(`Unknown task: ${currentChartConfig.task}`);
    }
    if (currentChartConfig.correctAnswer == 1) {
      redIndexes.push(-1);
    } else {
      redIndexes.unshift(-1);
    }
  }

  currentChartConfig.redIndexes = redIndexes;

  const chartSpec1 = drawBarChart({ values: data[0], redIndex: redIndexes[0], isAnswer: isCorrectAnswerFirst, label, orientation, scale, colorScheme: "blues" });
  const chartSpec2 = drawBarChart({ values: data[1], redIndex: redIndexes[1], isAnswer: !isCorrectAnswerFirst, label, orientation, scale, colorScheme: "blues"});


  Promise.all([
    vegaEmbed('#chart1', chartSpec1, { actions: false }),
    vegaEmbed('#chart2', chartSpec2, { actions: false })
  ]).then(results => {
    startTimer();
    currentChartViews = results.map(r => r.view);
  });
}

export function highlightBars() {
  // console.log(currentChartConfig);
  // const [arr1, arr2, darkestLongerSide, darkestDarkerSide, lightestLongerSide, lightestDarkerSide, [darkestIndexArr1, darkestIndexArr2], [lightestIndexArr1, lightestIndexArr2]] = currentChartConfig.data;
  let redIndex1 = null;
  let redIndex2 = null;
  // if (isDualPhaseTask(currentChartConfig.correctAnswer == 1)) {
  //   if (currentChartConfig.isCorrectAnswerFirst) {
  //     redIndex1 = currentChartConfig.redIndexes[0];
  //     redIndex2 = currentChartConfig.redIndexes[1];
  //   } else {
  //     redIndex1 = currentChartConfig.redIndexes[1];
  //     redIndex2 = currentChartConfig.redIndexes[0];
  //   }
  // } else {
  //   if (currentChartConfig.isCorrectAnswerFirst) {
  //     redIndex1 = currentChartConfig.redIndexes[0];
  //     redIndex2 = currentChartConfig.redIndexes[1];
  //   } else {
  //     redIndex1 = currentChartConfig.redIndexes[1];
  //     redIndex2 = currentChartConfig.redIndexes[0];
  //   }
  // }
  redIndex1 = currentChartConfig.redIndexes[0];
  redIndex2 = currentChartConfig.redIndexes[1];

  const arrowLineLayerData = [[], []];
  const arrowLayerData = [[], []];
  const textLayerData = [[], []];
  const drawOn = { 
    0: !isDualPhaseTask(currentChartConfig.task) && currentChartConfig.correctAnswer == 2 ? false : true,
    1: !isDualPhaseTask(currentChartConfig.task) && currentChartConfig.correctAnswer == 1 ? false : true
  };

  let textExplanation = null;
  if (isDualPhaseTask(currentChartConfig.task)) {
    const [firstTask, secondTask] = splitDualPhaseTask(currentChartConfig.task);
    textExplanation = [firstTask, [firstTask, secondTask]];
  } else {
    textExplanation = ["", currentChartConfig.task];
  }

  if (currentChartConfig.correctAnswer == 1) {
    textExplanation.reverse();
  }

  if (drawOn[0]) {
    pushArrowLine(arrowLineLayerData, 0, redIndex1, 0, -10);
    pushArrow(arrowLayerData, 0, redIndex1, 0, 0);
    pushText(textLayerData, 0, redIndex1, -15, textExplanation[0]);
  }

  if (drawOn[1]) {
    pushArrowLine(arrowLineLayerData, 1, redIndex2, 0, -10);
    pushArrow(arrowLayerData, 1, redIndex2, 0, 0);
    pushText(textLayerData, 1, redIndex2, -15, textExplanation[1]);
  }

  currentChartViews.forEach((view, i) => {
    view.change(
      'arrowLineLayer',
      vega
        .changeset()
        .remove(() => true)
        .insert(arrowLineLayerData[i])
    ).change(
      'arrowLayer', // this must match the name in "data.name"
      vega
        .changeset()
        .remove(() => true)  // wipe old labels
        .insert(arrowLayerData[i])
    ).change(
      'textLayer',
      vega
        .changeset()
        .remove(() => true)
        .insert(textLayerData[i])
    ).runAsync();
    view.resize().runAsync();
    // view.signal("highlight", true).run();
  });
}

function pushArrowLine(arrowLineLayerData, chartIndex, barIndex, arrowLineStart, arrowLineEnd) {
  arrowLineLayerData[chartIndex].push({ category: `${barIndex + 1}`, arrowLineStart, arrowLineEnd });
}

function pushArrow(arrowLayerData, chartIndex, barIndex, arrowValue, angle) {
  arrowLayerData[chartIndex].push({ category: `${barIndex + 1}`, arrowValue, angle });
}

function pushText(textLayerData, chartIndex, barIndex, value, explanation) {
  textLayerData[chartIndex].push({ category: `${barIndex + 1}`, value, explanation});
}