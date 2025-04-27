import { drawBarChart } from './chart.js';
import { startTimer } from './utils.js';
import { getTaskInstructionHTML } from './instructions.js';

let currentChartViews = [];
let currentChartConfig = null;

const secondArrowAngleMap = {
  horizontal: { horizontal: 270, vertical: 90 },
  vertical: { horizontal: 180, vertical: 0 }
};

const textExplanationMap = {
  vertical: {
    compare_height: ["darkest", "reaches higher"],
    compare_index: ["darkest", "more rightward"],
    compare_length: ["darkest", "longer"]
  },
  horizontal: {
    compare_height: ["darkest", "reaches more rightward"],
    compare_index: ["darkest", "higher"],
    compare_length: ["darkest", "longer"]
  }
}

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
  const chartSpec1 = drawBarChart({ values: data[0], redIndex: data[6][0], isAnswer: isCorrectAnswerFirst, label, orientation, scale, colorScheme: "blues" });
  const chartSpec2 = drawBarChart({ values: data[1], redIndex: data[6][1], isAnswer: !isCorrectAnswerFirst, label, orientation, scale, colorScheme: "blues"});

  Promise.all([
    vegaEmbed('#chart1', chartSpec1, { actions: false }),
    vegaEmbed('#chart2', chartSpec2, { actions: false })
  ]).then(results => {
    startTimer();
    currentChartViews = results.map(r => r.view);
  });
}

export function highlightDarkestBars() {
  const [arr1, arr2, , , , , [redIndex1, redIndex2]] = currentChartConfig.data;

  let arrowLineLayerData = [];
  let arrowLayerData = [];
  let textLayerData = [];

  // Left or Top chart
  if (currentChartConfig.orientation === "horizontal") {
    // pushArrowLine(arrowLineLayerData, redIndex1, arr1[redIndex1][0], -5);
    // pushArrow(arrowLayerData, redIndex1, arr1[redIndex1][0], 90);
    pushArrowLine(arrowLineLayerData, redIndex1, 0, -10);
    pushArrow(arrowLayerData, redIndex1, 0, 90);
  } else {
    // pushArrowLine(arrowLineLayerData, redIndex1, arr1[redIndex1][0] + arr1[redIndex1][1], 105);
    // pushArrow(arrowLayerData, redIndex1, arr1[redIndex1][0] + arr1[redIndex1][1], 180);
    pushArrowLine(arrowLineLayerData, redIndex1, 100, 110);
    pushArrow(arrowLayerData, redIndex1, 100, 180);
  }

  // Right or Bottom chart
  const secondArrowLineStart = (currentChartConfig.layout === "horizontal")
    // ? arr2[redIndex2][0] + arr2[redIndex2][1]
    // : arr2[redIndex2][0];
    ? 100 : 0;

  const secondArrowLineEnd = (currentChartConfig.layout === "horizontal") ? 110 : -10;

  const secondArrowAngle = secondArrowAngleMap[currentChartConfig.orientation][currentChartConfig.layout];
  const secondArrowValue = secondArrowLineStart;

  pushArrowLine(arrowLineLayerData, redIndex2, secondArrowLineStart, secondArrowLineEnd);
  pushArrow(arrowLayerData, redIndex2, secondArrowValue, secondArrowAngle);

  const firstTextValue = (currentChartConfig.orientation === "horizontal") ? -20 : 120;
  const secondTextValue = (currentChartConfig.layout === "horizontal") ? 120 : -20;

  if (currentChartConfig.correctAnswer == 1) {
    pushText(
      textLayerData, 
      redIndex1, 
      firstTextValue,
      textExplanationMap[currentChartConfig.orientation][currentChartConfig.task]
    );
    pushText(
      textLayerData,
      redIndex2,
      secondTextValue,
      "darkest"
    );
  } else {
    pushText(
      textLayerData,
      redIndex1,
      firstTextValue,
      "darkest"
    );
    pushText(
      textLayerData, 
      redIndex2, 
      secondTextValue,
      textExplanationMap[currentChartConfig.orientation][currentChartConfig.task]
    );
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

function pushArrowLine(arrowLineLayerData, index, arrowLineStart, arrowLineEnd) {
  arrowLineLayerData.push([{ category: `${index + 1}`, arrowLineStart, arrowLineEnd }]);
}

function pushArrow(arrowLayerData, index, arrowValue, angle) {
  arrowLayerData.push([{ category: `${index + 1}`, arrowValue, angle }]);
}

function pushText(textLayerData, index, value, explanation) {
  textLayerData.push([{ category: `${index + 1}`, value, explanation}]);
}