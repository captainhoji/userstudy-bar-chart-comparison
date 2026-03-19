const HEATMAP_STYLE = 'ColorBrewerBlue_white';
const HEATMAP_COUNT_PER_SIDE = 10;
const LINECHART_QUESTION_CSV = '/static/stimuli/linecharts/linechart_questions.csv';

const LEGEND_IMAGES = {
  darkUp: '/static/stimuli/legend_ColorBrewerBlue_darkhigh.bmp',
  lightUp: '/static/stimuli/legend_ColorBrewerBlue_darklow.bmp'
};

const LABEL_CONDITIONS = [
  { id: 'greater-up', top: 'Greater', bottom: 'Fewer' },
  { id: 'fewer-up', top: 'Fewer', bottom: 'Greater' }
];

function buildHeatmapList(startIndex = 0, countPerSide = HEATMAP_COUNT_PER_SIDE) {
  const heatmaps = [];
  for (let i = startIndex; i < startIndex + countPerSide; i += 1) {
    heatmaps.push({
      id: `left-${i}`,
      condition: 'left-dark',
      src: `/static/stimuli/${HEATMAP_STYLE}_left_${i}_cropped.png`
    });
    heatmaps.push({
      id: `right-${i}`,
      condition: 'right-dark',
      src: `/static/stimuli/${HEATMAP_STYLE}_right_${i}_cropped.png`
    });
  }
  return heatmaps;
}

function shuffleArray(arr) {
  const copy = arr.slice();
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function parseCsv(text) {
  const lines = text.trim().split('\n');
  if (!lines.length) return [];
  const headers = lines[0].split(',').map((h) => h.trim());
  const rows = [];
  for (let i = 1; i < lines.length; i += 1) {
    const line = lines[i].trim();
    if (!line) continue;
    // Statements in generated CSV do not include commas, so simple split is enough.
    const parts = line.split(',');
    const row = {};
    headers.forEach((h, idx) => {
      row[h] = (parts[idx] || '').trim();
    });
    rows.push(row);
  }
  return rows;
}

function buildTrialsFromHeatmaps(heatmaps) {
  const legendConditions = [
    { id: 'dark-up', src: LEGEND_IMAGES.darkUp },
    { id: 'light-up', src: LEGEND_IMAGES.lightUp }
  ];

  const trials = [];
  for (const heatmap of heatmaps) {
    for (const legend of legendConditions) {
      for (const labels of LABEL_CONDITIONS) {
        const darkIsUp = legend.id === 'dark-up';
        const greaterIsUp = labels.id === 'greater-up';
        const greaterIsDark = (darkIsUp && greaterIsUp) || (!darkIsUp && !greaterIsUp);
        trials.push({
          type: 'heatmap',
          heatmapId: heatmap.id,
          heatmapCondition: heatmap.condition,
          heatmapSrc: heatmap.src,
          legendCondition: legend.id,
          legendSrc: legend.src,
          labelCondition: labels.id,
          greaterIsDark,
          legendLabelTop: labels.top,
          legendLabelBottom: labels.bottom
        });
      }
    }
  }

  return trials;
}

function buildSelectedLinechartStimuli(pool = 'real') {
  // Real pool uses charts 0-9, practice pool uses charts 10-19.
  const startIdx = pool === 'practice' ? 10 : 0;
  const selectedIndices = Array.from({ length: 10 }, (_, i) => startIdx + i);
  const stimuli = [];
  for (const chartIdx of selectedIndices) {
    for (const legendVariant of ['a', 'b']) {
      stimuli.push({
        chartIndex: chartIdx,
        legendVariant,
        heatmapId: `linechart-${chartIdx}-${legendVariant}`,
        // slope is the trial condition used in DB for line-chart mode.
        heatmapCondition: 'increasing',
        heatmapSrc: `/static/stimuli/linecharts/linechart_${String(chartIdx).padStart(2, '0')}_legend_${legendVariant}.png`,
        // legend-a => ordered, legend-b => shuffled.
        legendCondition: legendVariant === 'a' ? 'ordered' : 'shuffled',
      });
    }
  }
  return stimuli;
}

async function loadLinechartQuestionRows() {
  const response = await fetch(LINECHART_QUESTION_CSV);
  const text = await response.text();
  return parseCsv(text);
}

function buildQuestionMap(rows) {
  const byChart = new Map();
  rows.forEach((row) => {
    const chartIndex = Number(row.chart_index);
    if (!byChart.has(chartIndex)) byChart.set(chartIndex, []);
    byChart.get(chartIndex).push({
      pool: row.pool || 'real',
      themeName: row.theme_name || '',
      xLeft: row.x_left || '',
      xRight: row.x_right || '',
      yLabel: row.y_label || '',
      statementType: row.statement_type,
      truthValue: Number(row.truth_value) === 1 ? 1 : 0,
      comparisonFrame: row.comparison_frame || 'more',
      statementText: row.statement_text,
      categoryA: row.category_a || '',
      categoryB: row.category_b || ''
    });
  });
  return byChart;
}

function uniqueChartIndices(rows, pool = 'real') {
  const ids = new Set();
  rows.forEach((row) => {
    if ((row.pool || 'real') !== pool) return;
    ids.add(Number(row.chart_index));
  });
  return Array.from(ids).filter((v) => Number.isFinite(v)).sort((a, b) => a - b);
}

function buildLinechartOnePerChartTrials(rows, pool = 'real', maxCount = null) {
  const byChart = buildQuestionMap(rows);
  let chartIds = uniqueChartIndices(rows, pool);
  if (!chartIds.length) return [];

  chartIds = shuffleArray(chartIds);
  if (maxCount !== null) {
    chartIds = chartIds.slice(0, Math.min(maxCount, chartIds.length));
  }

  // Balance legend x statement_type exactly.
  // For n=32 this yields 8 trials per cell:
  // ordered-main, ordered-interaction, shuffled-main, shuffled-interaction.
  const n = chartIds.length;
  const perCell = Math.floor(n / 4);
  const comboByChart = new Map();
  const shuffledForCombos = shuffleArray(chartIds);
  const combos = [
    { legendCondition: 'ordered', statementType: 'main_effect' },
    { legendCondition: 'ordered', statementType: 'interaction' },
    { legendCondition: 'shuffled', statementType: 'main_effect' },
    { legendCondition: 'shuffled', statementType: 'interaction' },
  ];
  let cursor = 0;
  combos.forEach((combo) => {
    for (let i = 0; i < perCell && cursor < shuffledForCombos.length; i += 1) {
      comboByChart.set(shuffledForCombos[cursor], combo);
      cursor += 1;
    }
  });
  // Any remainder (if n not divisible by 4) is assigned randomly.
  while (cursor < shuffledForCombos.length) {
    comboByChart.set(shuffledForCombos[cursor], combos[Math.floor(Math.random() * combos.length)]);
    cursor += 1;
  }

  // Truth values: random half true, rest false (global balance only).
  const trueSet = new Set(shuffleArray(chartIds).slice(0, Math.floor(chartIds.length / 2)));
  const moreFrameSet = new Set(shuffleArray(chartIds).slice(0, Math.floor(chartIds.length / 2)));

  const trials = [];
  chartIds.forEach((chartIdx, idx) => {
    const questions = (byChart.get(chartIdx) || []).filter((q) => (q.pool || 'real') === pool);
    if (!questions.length) return;

    const combo = comboByChart.get(chartIdx) || { legendCondition: 'ordered', statementType: 'main_effect' };
    const statementTypeWanted = combo.statementType;
    const statementTruthWanted = trueSet.has(chartIdx) ? 1 : 0;
    const comparisonFrameWanted = moreFrameSet.has(chartIdx) ? 'more' : 'less';
    const legendCondition = combo.legendCondition;

    // Pick question by desired type/truth; fallback keeps task running even if CSV is imperfect.
    const selectedQuestion = questions.find((q) =>
      q.statementType === statementTypeWanted &&
      q.truthValue === statementTruthWanted &&
      q.comparisonFrame === comparisonFrameWanted
    ) || questions.find((q) => q.statementType === statementTypeWanted)
      || questions.find((q) => q.truthValue === statementTruthWanted)
      || questions[0];

    const heatmapSrc = legendCondition === 'ordered'
      ? `/static/stimuli/linecharts/${(rows.find((r) => Number(r.chart_index) === chartIdx && (r.pool || 'real') === pool) || {}).legend_a_file || `linechart_${String(chartIdx).padStart(2, '0')}_legend_a.png`}`
      : `/static/stimuli/linecharts/${(rows.find((r) => Number(r.chart_index) === chartIdx && (r.pool || 'real') === pool) || {}).legend_b_file || `linechart_${String(chartIdx).padStart(2, '0')}_legend_b.png`}`;

    trials.push({
      type: 'linechart',
      heatmapId: `linechart-${pool}-${chartIdx}-${legendCondition}-${selectedQuestion.statementType}-${selectedQuestion.truthValue}-${idx}`,
      heatmapCondition: 'increasing',
      heatmapSrc,
      legendCondition,
      legendSrc: null,
      labelCondition: null,
      greaterIsDark: null,
      legendLabelTop: null,
      legendLabelBottom: null,
      correctSide: selectedQuestion.truthValue === 1 ? 'right' : 'left',
      statementType: selectedQuestion.statementType,
      statementTruth: selectedQuestion.truthValue,
      comparisonFrame: selectedQuestion.comparisonFrame || 'more',
      themeName: selectedQuestion.themeName,
      xLeft: selectedQuestion.xLeft,
      xRight: selectedQuestion.xRight,
      yLabel: selectedQuestion.yLabel,
      statementText: selectedQuestion.statementText,
      categoryA: selectedQuestion.categoryA,
      categoryB: selectedQuestion.categoryB
    });
  });

  return trials;
}

function expandLinechartTrials(stimuli, questionMap, pool = 'real') {
  const trials = [];
  stimuli.forEach((stim) => {
    const questions = (questionMap.get(stim.chartIndex) || []).filter((q) => (q.pool || 'real') === pool);
    questions.forEach((q, idx) => {
      trials.push({
        type: 'linechart',
        heatmapId: `${stim.heatmapId}-q${idx}`,
        heatmapCondition: stim.heatmapCondition,
        heatmapSrc: stim.heatmapSrc,
        legendCondition: stim.legendCondition,
        legendSrc: null,
        labelCondition: null,
        greaterIsDark: null,
        legendLabelTop: null,
        legendLabelBottom: null,
        // In line-chart mode, left arrow = false and right arrow = true.
        correctSide: q.truthValue === 1 ? 'right' : 'left',
        statementType: q.statementType,
        statementTruth: q.truthValue,
        comparisonFrame: q.comparisonFrame || 'more',
        themeName: q.themeName,
        xLeft: q.xLeft,
        xRight: q.xRight,
        yLabel: q.yLabel,
        // We intentionally do not store statement text in DB anymore.
        statementText: q.statementText,
      });
    });
  });
  return trials;
}

export function buildHeatmapTrials() {
  const heatmaps = buildHeatmapList(0, 10);
  return buildTrialsFromHeatmaps(heatmaps);
}

export async function buildLinechartTrials() {
  // One trial per real chart (e.g., 32 charts => 32 trials).
  const rows = await loadLinechartQuestionRows();
  return buildLinechartOnePerChartTrials(rows, 'real');
}

export function buildBalancedHeatmapTrials(startIndex = 0, countPerSide = 5) {
  const heatmaps = buildHeatmapList(startIndex, countPerSide);
  return buildTrialsFromHeatmaps(heatmaps);
}

export function buildPracticeTrialsRandom(count = 20) {
  const heatmaps = shuffleArray(buildHeatmapList(10, 10));
  const legendConditions = [
    { id: 'dark-up', src: LEGEND_IMAGES.darkUp },
    { id: 'light-up', src: LEGEND_IMAGES.lightUp }
  ];

  const trials = [];
  const sampleCount = Math.min(count, heatmaps.length);
  for (let i = 0; i < sampleCount; i += 1) {
    const heatmap = heatmaps[i];
    const legend = legendConditions[Math.floor(Math.random() * legendConditions.length)];
    const labels = LABEL_CONDITIONS[Math.floor(Math.random() * LABEL_CONDITIONS.length)];
    const darkIsUp = legend.id === 'dark-up';
    const greaterIsUp = labels.id === 'greater-up';
    const greaterIsDark = (darkIsUp && greaterIsUp) || (!darkIsUp && !greaterIsUp);

    trials.push({
      type: 'heatmap',
      heatmapId: heatmap.id,
      heatmapCondition: heatmap.condition,
      heatmapSrc: heatmap.src,
      legendCondition: legend.id,
      legendSrc: legend.src,
      labelCondition: labels.id,
      greaterIsDark,
      legendLabelTop: labels.top,
      legendLabelBottom: labels.bottom
    });
  }

  return trials;
}

export async function buildLinechartPracticeTrialsRandom(count = 20) {
  // Practice uses separate pool and one trial per chart, then samples requested count.
  const rows = await loadLinechartQuestionRows();
  const trials = buildLinechartOnePerChartTrials(rows, 'practice');
  return shuffleArray(trials).slice(0, Math.min(count, trials.length));
}

export function isHeatmapTrial(trial) {
  return trial && trial.type === 'heatmap' && trial.heatmapSrc && trial.legendSrc;
}
