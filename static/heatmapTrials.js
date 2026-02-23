const HEATMAP_STYLE = 'ColorBrewerBlue_white';
const HEATMAP_COUNT_PER_SIDE = 10;

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

export function buildHeatmapTrials() {
  const heatmaps = buildHeatmapList(0, 10);
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

export function isHeatmapTrial(trial) {
  return trial && trial.type === 'heatmap' && trial.heatmapSrc && trial.legendSrc;
}
