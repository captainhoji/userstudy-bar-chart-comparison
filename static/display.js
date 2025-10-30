import { drawBarChart } from './chart.js';
import { startTimer } from './utils.js';
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

export function displayCharts({ data, firstTask, secondTask, correctAnswer, layout, orientation, label = false, scale = 1 }) {
  currentChartConfig = { data, firstTask, secondTask, correctAnswer, layout, orientation, label, scale };
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
  const redIndexes = (currentChartConfig.firstTask === 'darkest') ? data[6] : data[7];
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

export function highlightDarkestBars() {
  const [arr1, arr2, darkestLongerSide, darkestDarkerSide, lightestLongerSide, lightestDarkerSide, [darkestIndexArr1, darkestIndexArr2], [lightestIndexArr1, lightestIndexArr2]] = currentChartConfig.data;
  const redIndex1 = (currentChartConfig.firstTask === "darkest") ? darkestIndexArr1 : lightestIndexArr1;
  const redIndex2 = (currentChartConfig.firstTask === "darkest") ? darkestIndexArr2 : lightestIndexArr2;

  let arrowLineLayerData = [];
  let arrowLayerData = [];
  let textLayerData = [];

  // Left or Top chart
  pushArrowLine(arrowLineLayerData, redIndex1, 100, 110);
  pushArrow(arrowLayerData, redIndex1, 100, 180);

  // Right or Bottom chart
  const secondArrowLineStart = 100;
  const secondArrowLineEnd = 110;

  const secondArrowAngle = secondArrowAngleMap[currentChartConfig.orientation][currentChartConfig.layout];
  const secondArrowValue = secondArrowLineStart;

  pushArrowLine(arrowLineLayerData, redIndex2, secondArrowLineStart, secondArrowLineEnd);
  pushArrow(arrowLayerData, redIndex2, secondArrowValue, secondArrowAngle);

  const firstTextValue = (currentChartConfig.orientation === "horizontal") ? -20 : 120;
  const secondTextValue = (currentChartConfig.layout === "horizontal") ? 120 : -20;

  const textExplanation = [currentChartConfig.firstTask, currentChartConfig.secondTask]

  if (currentChartConfig.correctAnswer == 1) {
    pushText(
      textLayerData, 
      redIndex1, 
      firstTextValue,
      textExplanation
    );
    pushText(
      textLayerData,
      redIndex2,
      secondTextValue,
      currentChartConfig.firstTask
    );
  } else {
    pushText(
      textLayerData,
      redIndex1,
      firstTextValue,
      currentChartConfig.firstTask
    );
    pushText(
      textLayerData, 
      redIndex2, 
      secondTextValue,
      textExplanation
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