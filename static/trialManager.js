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
    const response = await fetch('/save_response', {
      method: 'POST',
      keepalive: true,
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
    if (!response.ok) {
      console.error('save_response returned non-OK status:', response.status);
      return false;
    }
    return true;
  } catch (error) {
    console.error('Failed to save response:', error);
    return false;
  }
}

export async function savePracticeSummary({
  participantId,
  practiceAccuracy,
  practiceAccuracyPhone,
  practicePhoneHit,
  practicePhoneMiss,
  practicePhoneFalseAlarm,
  practicePhoneCorrectRejection
}) {
  try {
    await fetch('/save_practice_summary', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        practice_accuracy: practiceAccuracy,
        practice_accuracy_phone: practiceAccuracyPhone,
        hit: practicePhoneHit,
        miss: practicePhoneMiss,
        false_alarm: practicePhoneFalseAlarm,
        correct_rejection: practicePhoneCorrectRejection
      })
    });
  } catch (error) {
    console.error('Failed to save practice summary:', error);
  }
}

export async function savePhoneSummary({
  participantId,
  phoneHit,
  phoneMiss,
  phoneFalseAlarm,
  phoneCorrectRejection
}) {
  try {
    const response = await fetch('/save_phone_summary', {
      method: 'POST',
      keepalive: true,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        hit: phoneHit,
        miss: phoneMiss,
        false_alarm: phoneFalseAlarm,
        correct_rejection: phoneCorrectRejection
      })
    });
    return response.ok;
  } catch (error) {
    console.error('Failed to save phone summary:', error);
    return false;
  }
}
