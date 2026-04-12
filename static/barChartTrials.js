const BARCHART_TRIALS_CSV = '/static/stimuli/barcharts/barchart_trials.csv';

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
    const parts = line.split(',');
    const row = {};
    headers.forEach((h, idx) => {
      row[h] = (parts[idx] || '').trim();
    });
    rows.push(row);
  }
  return rows;
}

async function loadBarChartRows() {
  const response = await fetch(BARCHART_TRIALS_CSV);
  const text = await response.text();
  return parseCsv(text);
}

function taskFromLetter(letter) {
  return letter === 's' ? 'shortest' : 'tallest';
}

function taskStatement(taskType) {
  return taskType === 'shortest'
    ? 'Which chart has the <b>shortest</b> bar?'
    : 'Which chart has the <b>tallest</b> bar?';
}

function normalizeTaskSequence(raw) {
  const code = (raw || 'ts').toString().trim().toLowerCase();
  if (['ts', 'st', 'tt', 'ss'].includes(code)) return code;
  return 'ts';
}

function toBarChartTrial(row, rowIndex, taskType, groupTag = 'a') {
  const datasetIndex = Number(row.dataset_index);
  const idSuffix = Number.isFinite(datasetIndex) ? `${String(datasetIndex).padStart(2, '0')}` : String(rowIndex);
  const colorCondition = row.color_condition || 'dark-more';
  const tallestSide = row.tallest_side || 'left';
  const shortestSide = row.shortest_side || 'left';
  const correctSide = taskType === 'tallest' ? tallestSide : shortestSide;

  return {
    type: 'barchart',
    heatmapId: `barchart-${groupTag}-${idSuffix}-${colorCondition}-${taskType}-${rowIndex}`,
    // Keep backend payload compatible with the current save endpoint.
    heatmapCondition: `${tallestSide}-${shortestSide}`,
    legendCondition: colorCondition,
    labelCondition: null,
    legendSrc: null,
    greaterIsDark: null,
    legendLabelTop: null,
    legendLabelBottom: null,
    heatmapSrc: `/static/stimuli/barcharts/${row.image_file}`,
    correctSide: correctSide === 'right' ? 'right' : 'left',
    statementType: taskType,
    statementTruth: correctSide === 'right' ? 1 : 0,
    statementText: taskStatement(taskType),
    taskLabel: taskType
  };
}

function groupRowsByDataset(rows) {
  const byDataset = new Map();
  rows.forEach((row) => {
    const datasetIndex = Number(row.dataset_index);
    if (!byDataset.has(datasetIndex)) {
      byDataset.set(datasetIndex, []);
    }
    byDataset.get(datasetIndex).push(row);
  });
  return byDataset;
}

function chooseColorRowsForHalf(datasetRows, colorsInOrder) {
  // Pick exactly one color-rendered image for each underlying dataset.
  return datasetRows.map((variants, idx) => {
    const wantedColor = colorsInOrder[idx];
    return variants.find((row) => row.color_condition === wantedColor) || variants[0];
  });
}

function buildHalfTrials(rows, taskLetter, groupTag) {
  const taskType = taskFromLetter(taskLetter);
  // Keep order deterministic after the half-split so each half remains exactly 48.
  return rows.map((row, idx) => toBarChartTrial(row, idx, taskType, groupTag));
}

function buildLegacyRepeatedTrials(realRows, code) {
  // Fallback for older CSVs where each dataset already appears once per color.
  // This keeps the task runnable if an older asset pool is still on disk.
  const byCondition = new Map();
  realRows.forEach((row) => {
    const key = `${row.tallest_side}|${row.shortest_side}|${row.color_condition}`;
    if (!byCondition.has(key)) byCondition.set(key, []);
    byCondition.get(key).push(row);
  });

  const firstHalfRows = [];
  const secondHalfRows = [];
  byCondition.forEach((cellRows) => {
    const shuffledCell = shuffleArray(cellRows);
    firstHalfRows.push(...shuffledCell.slice(0, 4));
    secondHalfRows.push(...shuffledCell.slice(4, 8));
  });

  return buildHalfTrials(shuffleArray(firstHalfRows), code[0], 'first')
    .concat(buildHalfTrials(shuffleArray(secondHalfRows), code[1], 'second'));
}

export async function buildBarChartTrials(taskSequence = 'ts') {
  const rows = await loadBarChartRows();
  const code = normalizeTaskSequence(taskSequence);

  // Real pool has 96 underlying datasets. Each dataset has 3 image variants
  // (dark-more/light-more/random). We split the 96 datasets into two 48-dataset halves,
  // then assign colors within each half so each task gets:
  // - 16 dark-more
  // - 16 light-more
  // - 16 random
  // and, within each color, 4 of each tallest_side x shortest_side combo.
  const realRows = rows.filter((row) => (row.pool || 'real') === 'real');
  const byDataset = groupRowsByDataset(realRows);
  if (byDataset.size < 96) {
    return buildLegacyRepeatedTrials(realRows, code);
  }
  const datasetsBySideCombo = new Map();
  byDataset.forEach((variants, datasetIndex) => {
    const exemplar = variants[0];
    const key = `${exemplar.tallest_side}|${exemplar.shortest_side}`;
    if (!datasetsBySideCombo.has(key)) {
      datasetsBySideCombo.set(key, []);
    }
    datasetsBySideCombo.get(key).push({ datasetIndex, variants });
  });

  const firstHalfDatasets = [];
  const secondHalfDatasets = [];
  datasetsBySideCombo.forEach((datasetEntries) => {
    const shuffledEntries = shuffleArray(datasetEntries);
    // 24 datasets per side combo -> 12 per task half.
    firstHalfDatasets.push(...shuffledEntries.slice(0, 12));
    secondHalfDatasets.push(...shuffledEntries.slice(12, 24));
  });

  function assignBalancedColors(halfDatasets) {
    const selectedRows = [];
    const sideComboBuckets = new Map();
    halfDatasets.forEach((entry) => {
      const exemplar = entry.variants[0];
      const key = `${exemplar.tallest_side}|${exemplar.shortest_side}`;
      if (!sideComboBuckets.has(key)) {
        sideComboBuckets.set(key, []);
      }
      sideComboBuckets.get(key).push(entry.variants);
    });

    sideComboBuckets.forEach((variantsList) => {
      const shuffledVariants = shuffleArray(variantsList);
      // 12 datasets per side combo -> 4 dark-more, 4 light-more, 4 random.
      const colorAssignments = [
        ...Array(4).fill('dark-more'),
        ...Array(4).fill('light-more'),
        ...Array(4).fill('random'),
      ];
      const shuffledColors = shuffleArray(colorAssignments);
      selectedRows.push(...chooseColorRowsForHalf(shuffledVariants, shuffledColors));
    });

    return shuffleArray(selectedRows);
  }

  const firstHalfRows = assignBalancedColors(firstHalfDatasets);
  const secondHalfRows = assignBalancedColors(secondHalfDatasets);

  const firstHalf = buildHalfTrials(firstHalfRows, code[0], 'first');
  const secondHalf = buildHalfTrials(secondHalfRows, code[1], 'second');
  return firstHalf.concat(secondHalf);
}

export async function buildBarChartPracticeTrialsRandom(count = 20, taskLetter = 't') {
  const rows = await loadBarChartRows();
  const practiceRows = rows.filter((row) => (row.pool || 'real') === 'practice');
  const practiceDatasets = Array.from(groupRowsByDataset(practiceRows).values());
  const sampledDatasets = shuffleArray(practiceDatasets).slice(0, Math.min(count, practiceDatasets.length));
  // Practice uses one randomly chosen color version per underlying dataset.
  const sampledRows = sampledDatasets.map((variants) => {
    const shuffledVariants = shuffleArray(variants);
    return shuffledVariants[0];
  });
  const taskType = taskFromLetter(taskLetter);
  return sampledRows.map((row, idx) => toBarChartTrial(row, idx, taskType));
}
