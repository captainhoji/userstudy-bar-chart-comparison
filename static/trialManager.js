export async function saveResponseToServer({
  participantId,
  response,
  correct,
  trialNumber,
  timeWhen,
  stimuliNumber,
  duration,
  responseTime,
  heatmapCondition,
  legendCondition,
  labelCondition,
  attention
}) {
  try {
    await fetch('/save_response', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        response,
        correct,
        trial_number: trialNumber,
        time_when: timeWhen,
        stimuli_number: stimuliNumber,
        duration,
        response_time: responseTime,
        heatmap_condition: heatmapCondition,
        legend_condition: legendCondition,
        label_condition: labelCondition,
        attention
      })
    });
  } catch (error) {
    console.error('Failed to save response:', error);
  }
}

export async function savePracticeSummary({ participantId, practiceAccuracy, practiceAccuracyPhone }) {
  try {
    await fetch('/save_practice_summary', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        practice_accuracy: practiceAccuracy,
        practice_accuracy_phone: practiceAccuracyPhone
      })
    });
  } catch (error) {
    console.error('Failed to save practice summary:', error);
  }
}
