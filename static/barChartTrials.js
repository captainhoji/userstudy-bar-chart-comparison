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
  const colorCondition = row.color_condition || 'same';
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

function buildHalfTrials(rows, taskLetter, groupTag) {
  const taskType = taskFromLetter(taskLetter);
  // Keep order deterministic after the half-split so each half remains exactly 48.
  return rows.map((row, idx) => toBarChartTrial(row, idx, taskType, groupTag));
}

export async function buildBarChartTrials(taskSequence = 'ts') {
  const rows = await loadBarChartRows();
  const code = normalizeTaskSequence(taskSequence);

  // Real pool has exactly 96 image rows (32 datasets x 3 colors).
  // We split into two homogeneous-task halves (48/48), *stratified* by
  // (tallest_side x shortest_side x color_condition) so each half has the
  // same condition composition (4 items per cell).
  const realRows = rows.filter((row) => (row.pool || 'real') === 'real');
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

  // Shuffle within each half only, to preserve the 48/48 task partition.
  const firstHalfShuffled = shuffleArray(firstHalfRows);
  const secondHalfShuffled = shuffleArray(secondHalfRows);

  const firstHalf = buildHalfTrials(firstHalfShuffled, code[0], 'first');
  const secondHalf = buildHalfTrials(secondHalfShuffled, code[1], 'second');
  return firstHalf.concat(secondHalf);
}

export async function buildBarChartPracticeTrialsRandom(count = 20, taskLetter = 't') {
  const rows = await loadBarChartRows();
  const practiceRows = rows.filter((row) => (row.pool || 'real') === 'practice');
  const sampledRows = shuffleArray(practiceRows).slice(0, Math.min(count, practiceRows.length));
  const taskType = taskFromLetter(taskLetter);
  return sampledRows.map((row, idx) => toBarChartTrial(row, idx, taskType));
}
